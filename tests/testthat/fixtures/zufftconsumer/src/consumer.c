/* A consumer of zufft's C table (design §7, §10): FIt-SNE's three FFT
 * shapes, the table's contract, and concurrent callers. */
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <stdint.h>
#include <string.h>
#include <zufft.h>
#ifndef _WIN32
#include <pthread.h>
#endif

static const zufft_api *fft = NULL;

static void need_api(void) {
  if (fft == NULL) Rf_error("zufft table not available");
}

/* FIt-SNE's 2-D convolution on an n x m grid: r2c of the data and the
 * kernel, a Hadamard product, and c2r scaled by 1 / (n m). Circular. */
static SEXP zc_conv2d(SEXP x, SEXP k) {
  need_api();
  const int n = Rf_nrows(x), m = Rf_ncols(x);
  size_t shp[2] = {(size_t) n, (size_t) m};
  size_t hshp[2] = {(size_t) n, (size_t) (m / 2 + 1)};
  const int axes[2] = {0, 1};
  zufft_layout lr = {2, shp, NULL}, lh = {2, hshp, NULL};
  const size_t nh = hshp[0] * hshp[1];
  double *X = (double *) R_alloc(2 * nh, sizeof(double));
  double *K = (double *) R_alloc(2 * nh, sizeof(double));
  int st = fft->r2c(&lr, REAL(x), &lh, X, 2, axes, 1, 1.0, 0);
  if (st == ZUFFT_OK) st = fft->r2c(&lr, REAL(k), &lh, K, 2, axes, 1, 1.0, 0);
  if (st != ZUFFT_OK) Rf_error("r2c failed (%d): %s", st, fft->message());
  for (size_t i = 0; i < nh; ++i) {
    double ar = X[2 * i], ai = X[2 * i + 1], br = K[2 * i], bi = K[2 * i + 1];
    X[2 * i] = ar * br - ai * bi;
    X[2 * i + 1] = ar * bi + ai * br;
  }
  double fct;
  if (zufft_scale(ZUFFT_NORM_BY_N, 2, shp, 1, 0, &fct) != ZUFFT_OK) Rf_error("zufft_scale failed");
  SEXP out = PROTECT(Rf_allocMatrix(REALSXP, n, m));
  st = fft->c2r(&lh, X, &lr, REAL(out), 2, axes, 0, fct, 0);
  if (st != ZUFFT_OK) Rf_error("c2r failed (%d): %s", st, fft->message());
  UNPROTECT(1);
  return out;
}

/* FIt-SNE's 1-D pair, in place: forward then backward scaled by 1 / n. */
static SEXP zc_inplace_pair(SEXP z) {
  need_api();
  const R_xlen_t n = XLENGTH(z);
  SEXP out = PROTECT(Rf_allocVector(CPLXSXP, 2 * n));
  double *buf = (double *) R_alloc(2 * (size_t) n, sizeof(double));
  memcpy(buf, COMPLEX(z), 2 * (size_t) n * sizeof(double));
  size_t shp = (size_t) n;
  zufft_layout l = {1, &shp, NULL};
  const int axis = 0;
  int st = fft->c2c(&l, buf, &l, buf, 1, &axis, 1, 1.0, 0);
  if (st != ZUFFT_OK) Rf_error("c2c failed (%d): %s", st, fft->message());
  memcpy(COMPLEX(out), buf, 2 * (size_t) n * sizeof(double));
  double fct;
  zufft_scale(ZUFFT_NORM_BY_N, 1, &shp, 1, 0, &fct);
  st = fft->c2c(&l, buf, &l, buf, 1, &axis, 0, fct, 0);
  if (st != ZUFFT_OK) Rf_error("c2c failed (%d): %s", st, fft->message());
  memcpy(COMPLEX(out) + n, buf, 2 * (size_t) n * sizeof(double));
  UNPROTECT(1);
  return out;
}

#ifndef _WIN32
static void *other_thread_message(void *arg) {
  const char **res = (const char **) arg;
  *res = fft->message();
  return NULL;
}
#endif

/* The contract of design §7, as named statuses and flags. */
static SEXP zc_contract(void) {
  need_api();
  const char *names[] = {"struct_size", "abi_version", "null_data", "null_layout",
                         "zero_extent", "bad_axis", "dup_axis", "neg_stride",
                         "bad_type", "dct1_short", "overlap_r2c", "partial_overlap_c2c",
                         "self_overlap", "overflow", "shape_mismatch", "message_set",
                         "message_cleared", "message_thread_local", "good_size",
                         "good_size_zero", ""};
  SEXP out = PROTECT(Rf_mkNamed(INTSXP, names));
  int *r = INTEGER(out);
  r[0] = fft->struct_size >= sizeof(zufft_api);
  r[1] = (int) fft->abi_version;

  double buf[64] = {0}, buf2[64] = {0};
  size_t s4[1] = {4}, s0[1] = {0}, s22[2] = {2, 2}, s3[1] = {3};
  const int ax0 = 0, ax1 = 1, axdup[2] = {0, 0};
  zufft_layout l4 = {1, s4, NULL}, l0 = {1, s0, NULL}, l22 = {2, s22, NULL};
  zufft_layout l3 = {1, s3, NULL};
  r[2] = fft->c2c(&l4, NULL, &l4, buf, 1, &ax0, 1, 1.0, 1);
  r[3] = fft->c2c(NULL, buf, &l4, buf2, 1, &ax0, 1, 1.0, 1);
  r[4] = fft->c2c(&l0, buf, &l0, buf2, 1, &ax0, 1, 1.0, 1);
  r[5] = fft->c2c(&l4, buf, &l4, buf2, 1, &ax1, 1, 1.0, 1);
  r[6] = fft->c2c(&l22, buf, &l22, buf2, 2, axdup, 1, 1.0, 1);
  ptrdiff_t neg[1] = {-1};
  zufft_layout lneg = {1, s4, neg};
  r[7] = fft->c2c(&lneg, buf + 8, &l4, buf2, 1, &ax0, 1, 1.0, 1);
  r[8] = fft->dct(&l4, buf, &l4, buf2, 1, &ax0, 5, 1.0, 0, 1);
  size_t s1[1] = {1};
  zufft_layout l1 = {1, s1, NULL};
  r[9] = fft->dct(&l1, buf, &l1, buf2, 1, &ax0, 1, 1.0, 0, 1);
  r[10] = fft->r2c(&l4, buf, &l3, buf + 2, 1, &ax0, 1, 1.0, 1);
  r[11] = fft->c2c(&l4, buf, &l4, buf + 2, 1, &ax0, 1, 1.0, 1);
  ptrdiff_t zero[2] = {1, 0};
  zufft_layout lself = {2, s22, zero};
  r[12] = fft->c2c(&l22, buf, &lself, buf2, 2, (const int[]) {0, 1}, 1, 1.0, 1);
  size_t big[1] = {2};
  ptrdiff_t huge[1] = {PTRDIFF_MAX / 4};
  zufft_layout lbig = {1, big, huge};
  r[13] = fft->c2c(&lbig, buf, &lbig, buf2, 1, &ax0, 1, 1.0, 1);
  r[14] = fft->c2c(&l4, buf, &l3, buf2, 1, &ax0, 1, 1.0, 1);

  r[15] = strlen(fft->message()) > 0;
  fft->c2c(&l4, buf, &l4, buf2, 1, &ax0, 1, 1.0, 1);
  r[16] = strlen(fft->message()) == 0;
  r[17] = NA_INTEGER;
#ifndef _WIN32
  fft->c2c(NULL, buf, &l4, buf2, 1, &ax0, 1, 1.0, 1); /* fail on this thread */
  const char *seen = NULL;
  pthread_t t;
  if (pthread_create(&t, NULL, other_thread_message, &seen) == 0) {
    pthread_join(t, NULL);
    r[17] = seen != NULL && strlen(seen) == 0 && strlen(fft->message()) > 0;
  }
#endif
  r[18] = (int) fft->good_size(1009, 0);
  r[19] = (int) fft->good_size(0, 0);
  UNPROTECT(1);
  return out;
}

#ifndef _WIN32
typedef struct {
  int reps, ok;
} worker_arg;

static void *worker(void *p) {
  worker_arg *a = (worker_arg *) p;
  enum { N = 64, M = 64 };
  static const int axes[2] = {0, 1};
  size_t shp[2] = {N, M};
  zufft_layout l = {2, shp, NULL};
  double in[2 * N * M], out[2 * N * M], back[2 * N * M];
  for (int i = 0; i < 2 * N * M; ++i) in[i] = (double) ((i * 7919) % 101) - 50.0;
  double fct;
  zufft_scale(ZUFFT_NORM_BY_N, 2, shp, 1, 0, &fct);
  a->ok = 1;
  for (int r = 0; r < a->reps; ++r) {
    if (fft->c2c(&l, in, &l, out, 2, axes, 1, 1.0, 2) != ZUFFT_OK ||
        fft->c2c(&l, out, &l, back, 2, axes, 0, fct, 2) != ZUFFT_OK) {
      a->ok = 0;
      return NULL;
    }
    for (int i = 0; i < 2 * N * M; ++i)
      if (back[i] - in[i] > 1e-9 || in[i] - back[i] > 1e-9) {
        a->ok = 0;
        return NULL;
      }
  }
  return NULL;
}
#endif

/* Several threads calling the table at once; TRUE when all round trips
 * succeed. NA on Windows, where this fixture does not use pthreads. */
static SEXP zc_concurrent(SEXP nthreads, SEXP reps) {
  need_api();
#ifdef _WIN32
  return Rf_ScalarLogical(NA_LOGICAL);
#else
  const int nt = Rf_asInteger(nthreads);
  pthread_t th[16];
  worker_arg args[16];
  int started = 0;
  for (int i = 0; i < nt && i < 16; ++i) {
    args[i].reps = Rf_asInteger(reps);
    args[i].ok = 0;
    if (pthread_create(&th[i], NULL, worker, &args[i]) == 0) started++;
    else break;
  }
  int ok = started == nt;
  for (int i = 0; i < started; ++i) {
    pthread_join(th[i], NULL);
    ok = ok && args[i].ok;
  }
  return Rf_ScalarLogical(ok);
#endif
}

static SEXP zc_api_size(void) {
  need_api();
  return Rf_ScalarInteger((int) fft->struct_size);
}

static const R_CallMethodDef methods[] = {
  {"zc_conv2d", (DL_FUNC) &zc_conv2d, 2},
  {"zc_inplace_pair", (DL_FUNC) &zc_inplace_pair, 1},
  {"zc_contract", (DL_FUNC) &zc_contract, 0},
  {"zc_concurrent", (DL_FUNC) &zc_concurrent, 2},
  {"zc_api_size", (DL_FUNC) &zc_api_size, 0},
  {NULL, NULL, 0}
};

void R_init_zufftconsumer(DllInfo *dll) {
  R_registerRoutines(dll, NULL, methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  fft = zufft_api_get();
}
