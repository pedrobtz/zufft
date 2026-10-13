/* R glue for the Fourier transforms (design §4, §6). R vectors in, shim
 * calls, R vectors out. Argument checks that need R semantics are done in
 * R (R/transform.R); this file trusts their results but still checks
 * every size computation for overflow before allocating. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <math.h>
#include <stdint.h>
#include <string.h>

#include "zff_r.h"
#include "zff_shim.h"

#define ZFF_MAXDIM 64

enum { ZFF_KIND_C2C = 0, ZFF_KIND_R2C = 1, ZFF_KIND_C2R = 2 };

/* Raises the zufft condition for a shim status: zufft:::zff_signal_status()
 * maps it to its class (design §9). Does not return. */
void zff_raise(int status, const char *msg) {
  SEXP ns = PROTECT(R_FindNamespace(Rf_mkString("zufft")));
  SEXP smsg = PROTECT(Rf_mkString(msg ? msg : ""));
  SEXP call = PROTECT(Rf_lang3(Rf_install("zff_signal_status"),
                               Rf_ScalarInteger(status), smsg));
  Rf_eval(call, ns);
  UNPROTECT(3);
  Rf_error("zufft: internal error %d", status); /* not reached */
}

/* Multiplies a by b into *res; returns 0 on size_t overflow. */
static int mul_ok(size_t a, size_t b, size_t *res) {
  if (a != 0 && b > SIZE_MAX / a) return 0;
  *res = a * b;
  return 1;
}

/* Element count of a shape, checked against R's vector limit and the
 * byte size of `elsize`-byte elements. */
static size_t checked_count(const size_t *shape, int nd, size_t elsize) {
  size_t n = 1;
  for (int i = 0; i < nd; ++i)
    if (!mul_ok(n, shape[i], &n)) zff_raise(ZFF_EOVERFLOW, "array size overflows");
  size_t bytes;
  if (!mul_ok(n, elsize, &bytes) || n > (size_t) R_XLEN_T_MAX)
    zff_raise(ZFF_EOVERFLOW, "result exceeds R's vector length limit");
  return n;
}

static void dense_strides(const size_t *shape, int nd, ptrdiff_t *stride) {
  ptrdiff_t s = 1;
  for (int i = 0; i < nd; ++i) {
    stride[i] = s;
    s *= (ptrdiff_t) shape[i];
  }
}

/* Copies the overlap of a dense array of shape `src` into a zeroed dense
 * array of shape `dst`: this is SciPy's crop-or-zero-pad (design §6.2).
 * Runs along the first axis are copied with memcpy, so no element is
 * accessed through a type other than raw bytes. */
static void copy_pad(const char *from, const size_t *src, char *to,
                     const size_t *dst, int nd, size_t elsize) {
  ptrdiff_t ss[ZFF_MAXDIM], ds[ZFF_MAXDIM];
  size_t ov[ZFF_MAXDIM], idx[ZFF_MAXDIM];
  dense_strides(src, nd, ss);
  dense_strides(dst, nd, ds);
  for (int i = 0; i < nd; ++i) {
    ov[i] = src[i] < dst[i] ? src[i] : dst[i];
    idx[i] = 0;
  }
  const size_t run = ov[0] * elsize;
  for (;;) {
    ptrdiff_t so = 0, dof = 0;
    for (int i = 1; i < nd; ++i) {
      so += (ptrdiff_t) idx[i] * ss[i];
      dof += (ptrdiff_t) idx[i] * ds[i];
    }
    memcpy(to + (size_t) dof * elsize, from + (size_t) so * elsize, run);
    int d = 1;
    for (; d < nd; ++d) {
      if (++idx[d] < ov[d]) break;
      idx[d] = 0;
    }
    if (d >= nd) return;
  }
}

/* SciPy's norm_fct: 1, 1/sqrt(N) or 1/N, computed in long double and
 * rounded once to double (design §6.3). inorm: 0 none, 1 ortho, 2 by N. */
double zff_norm_factor(int inorm, const size_t *len, int naxes, size_t mult,
                       int delta) {
  if (inorm == 0) return 1.0;
  long double n = 1.0L;
  for (int i = 0; i < naxes; ++i)
    n *= (long double) mult * (long double) ((long double) len[i] + delta);
  if (inorm == 2) return (double) (1.0L / n);
  return (double) (1.0L / sqrtl(n));
}

/* .Call(zff_fft_call, x, kind, dims, axes, n, forward, inorm, nthreads)
 *
 * x       double (real) or complex vector, never modified
 * kind    0 c2c, 1 r2c, 2 c2r
 * dims    extents of x, as doubles so long vectors survive
 * axes    0-based axes, the half-complex one last
 * n       per axis: the transform length (c2c, r2c) or the output length
 *         (c2r); the input is cropped or zero-padded to it
 * forward TRUE for the forward transform
 * inorm   0 none, 1 ortho, 2 scale by 1/N
 * nthreads resolved thread count, >= 1
 *
 * Returns the result vector, with no attributes. */
SEXP zff_fft(SEXP x, SEXP kind_, SEXP dims, SEXP axes_, SEXP n_, SEXP forward_,
             SEXP inorm_, SEXP nthreads_) {
  const int kind = Rf_asInteger(kind_);
  const int nd = LENGTH(dims), naxes = LENGTH(axes_);
  const int forward = Rf_asLogical(forward_), inorm = Rf_asInteger(inorm_);
  const int nthreads = Rf_asInteger(nthreads_);
  const int in_complex = TYPEOF(x) == CPLXSXP;
  if (nd < 1 || nd > ZFF_MAXDIM || naxes < 1 || naxes > nd || LENGTH(n_) != naxes)
    zff_raise(ZFF_EINTERNAL, "inconsistent shape arguments");

  size_t shape[ZFF_MAXDIM], tgt[ZFF_MAXDIM], oshape[ZFF_MAXDIM], len[ZFF_MAXDIM];
  int axes[ZFF_MAXDIM];
  for (int i = 0; i < nd; ++i) shape[i] = tgt[i] = (size_t) REAL(dims)[i];
  for (int k = 0; k < naxes; ++k) {
    axes[k] = INTEGER(axes_)[k];
    len[k] = (size_t) REAL(n_)[k];
    tgt[axes[k]] = len[k];
  }
  const int last = axes[naxes - 1];
  memcpy(oshape, tgt, sizeof(size_t) * nd);
  if (kind == ZFF_KIND_R2C) oshape[last] = tgt[last] / 2 + 1;
  if (kind == ZFF_KIND_C2R) tgt[last] = len[naxes - 1] / 2 + 1;

  const int out_complex = kind != ZFF_KIND_C2R;
  const size_t in_el = in_complex ? 2 * sizeof(double) : sizeof(double);
  const size_t nout = checked_count(oshape, nd, out_complex ? 16 : 8);
  const size_t ntgt = checked_count(tgt, nd, in_el);
  SEXP out = PROTECT(Rf_allocVector(out_complex ? CPLXSXP : REALSXP, (R_xlen_t) nout));
  if (nout == 0 || ntgt == 0) {
    UNPROTECT(1);
    return out;
  }

  /* Input: a view of x when every axis is cropped or kept, a zero-padded
   * copy when any axis grows. */
  int pad = 0;
  for (int i = 0; i < nd; ++i)
    if (tgt[i] > shape[i]) pad = 1;
  ptrdiff_t istride[ZFF_MAXDIM];
  const double *in = in_complex ? (const double *) COMPLEX(x) : REAL(x);
  SEXP tmp = R_NilValue;
  if (pad) {
    tmp = PROTECT(Rf_allocVector(in_complex ? CPLXSXP : REALSXP, (R_xlen_t) ntgt));
    char *t = in_complex ? (char *) COMPLEX(tmp) : (char *) REAL(tmp);
    memset(t, 0, ntgt * in_el);
    copy_pad((const char *) in, shape, t, tgt, nd, in_el);
    in = (const double *) t;
    dense_strides(tgt, nd, istride);
  } else {
    dense_strides(shape, nd, istride);
  }

  zff_layout lin = {nd, tgt, istride};
  zff_layout lout = {nd, oshape, NULL};
  double *o = out_complex ? (double *) COMPLEX(out) : REAL(out);
  int st;
  double fct;
  switch (kind) {
    case ZFF_KIND_C2C:
      fct = zff_norm_factor(inorm, len, naxes, 1, 0);
      st = in_complex ? zff_c2c(&lin, in, &lout, o, naxes, axes, forward, fct, nthreads)
                      : zff_c2c_real(&lin, in, &lout, o, naxes, axes, forward, fct, nthreads);
      break;
    case ZFF_KIND_R2C:
      fct = zff_norm_factor(inorm, len, naxes, 1, 0);
      st = zff_r2c(&lin, in, &lout, o, naxes, axes, forward, fct, nthreads);
      break;
    case ZFF_KIND_C2R:
      fct = zff_norm_factor(inorm, len, naxes, 1, 0);
      st = zff_c2r(&lin, in, &lout, o, naxes, axes, forward, fct, nthreads);
      break;
    default:
      st = ZFF_EINTERNAL;
  }
  if (st != ZFF_OK) zff_raise(st, zff_message());
  UNPROTECT(pad ? 2 : 1);
  return out;
}
