/* Transform entry points of zufft's shim (design §4, §7, §12.2).
 *
 * Every function is extern "C" and noexcept in effect: each body is a try
 * block whose handler turns any exception into a status code and a
 * thread-local message. R's API is never called here.
 *
 * Complex buffers arrive as pairs of doubles (re, im). How they reach ducc0
 * is the complex path of design §12.2:
 *
 *   zero-copy  The buffer is viewed in place as std::complex<double>. The
 *              standard makes std::complex<double> array-compatible with
 *              double[2]; R's Rcomplex is a union of {double r, i} and a
 *              C99 double _Complex, and libstdc++ stores std::complex<double>
 *              as a double _Complex, libc++ as two doubles, so the view
 *              matches a member of the union on both. The view is created
 *              only here, in C++, and C code never accesses the same memory
 *              through another type during a call. Exercised under ASan,
 *              UBSan and LTO in CI (native-checks).
 *   marshal    Each component is copied into genuine std::complex<double>
 *              storage and the result copied back. Compiled when
 *              ZFF_COMPLEX_MARSHAL is defined or the compiler is neither
 *              GCC nor clang; CI builds it once to keep it working. */
#include <algorithm>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <new>
#include <vector>

#include "ducc0/fft/fft.h"
#include "zff_shim.h"

void zff_set_message(const char *msg) noexcept;
void zff_clear_message() noexcept;
int zff_status_from_exception() noexcept;

#if !defined(ZFF_COMPLEX_MARSHAL) && !(defined(__GNUC__) || defined(__clang__))
#define ZFF_COMPLEX_MARSHAL 1
#endif

namespace {

using ducc0::cfmav;
using ducc0::vfmav;
using shape_t = ducc0::fmav_info::shape_t;
using stride_t = ducc0::fmav_info::stride_t;
using cplx = std::complex<double>;

struct zff_error {
  int status;
  const char *msg;
};

[[noreturn]] void fail(int status, const char *msg) { throw zff_error{status, msg}; }

shape_t get_shape(const zff_layout *l) {
  if (!l || l->ndim < 1 || !l->shape) fail(ZFF_EINVAL, "invalid layout");
  shape_t shape(l->shape, l->shape + l->ndim);
  for (auto s : shape)
    if (s == 0) fail(ZFF_ESHAPE, "zero extent in layout");
  return shape;
}

/* Strides in elements; NULL means dense column-major. Checks that every
 * address the view can reach fits in ptrdiff_t. */
stride_t get_stride(const zff_layout *l, const shape_t &shape) {
  const std::size_t nd = shape.size();
  stride_t stride(nd);
  const auto pmax = std::size_t(std::numeric_limits<std::ptrdiff_t>::max());
  if (!l->stride) {
    std::size_t s = 1;
    for (std::size_t i = 0; i < nd; ++i) {
      stride[i] = std::ptrdiff_t(s);
      if (shape[i] > pmax / s) fail(ZFF_EOVERFLOW, "array too large");
      s *= shape[i];
    }
    return stride;
  }
  std::size_t reach = 0;
  for (std::size_t i = 0; i < nd; ++i) {
    if (l->stride[i] < 0) fail(ZFF_EINVAL, "negative strides are not supported");
    stride[i] = l->stride[i];
    const std::size_t si = std::size_t(l->stride[i]);
    if (si != 0 && shape[i] - 1 > (pmax - reach) / si)
      fail(ZFF_EOVERFLOW, "strided layout overflows ptrdiff_t");
    reach += (shape[i] - 1) * si;
  }
  return stride;
}

shape_t get_axes(int naxes, const int *axes, std::size_t ndim) {
  if (naxes < 1 || !axes) fail(ZFF_EINVAL, "no axes given");
  shape_t res;
  for (int i = 0; i < naxes; ++i) {
    if (axes[i] < 0 || std::size_t(axes[i]) >= ndim)
      fail(ZFF_EINVAL, "axis out of range");
    if (std::find(res.begin(), res.end(), std::size_t(axes[i])) != res.end())
      fail(ZFF_EINVAL, "duplicate axis");
    res.push_back(std::size_t(axes[i]));
  }
  return res;
}

std::size_t nthreads_of(int nthreads) { return nthreads < 1 ? 1 : std::size_t(nthreads); }

#ifdef ZFF_COMPLEX_MARSHAL
/* Visits every element of a shape in column-major order with its element
 * offsets in two strided layouts. */
template <typename F>
void for_each_offset(const shape_t &shape, const stride_t &sa, const stride_t &sb, F f) {
  const std::size_t nd = shape.size();
  std::vector<std::size_t> idx(nd, 0);
  std::ptrdiff_t oa = 0, ob = 0;
  for (;;) {
    f(oa, ob);
    std::size_t d = 0;
    for (; d < nd; ++d) {
      oa += sa[d];
      ob += sb[d];
      if (++idx[d] < shape[d]) break;
      oa -= sa[d] * std::ptrdiff_t(shape[d]);
      ob -= sb[d] * std::ptrdiff_t(shape[d]);
      idx[d] = 0;
    }
    if (d == nd) return;
  }
}

stride_t dense_stride(const shape_t &shape) {
  stride_t s(shape.size());
  std::ptrdiff_t acc = 1;
  for (std::size_t i = 0; i < shape.size(); ++i) {
    s[i] = acc;
    acc *= std::ptrdiff_t(shape[i]);
  }
  return s;
}

std::size_t count(const shape_t &shape) {
  std::size_t n = 1;
  for (auto s : shape) n *= s;
  return n;
}
#endif

}  // namespace

extern "C" const char *zff_complex_path(void) {
#ifdef ZFF_COMPLEX_MARSHAL
  return "marshal";
#else
  return "zero-copy";
#endif
}

extern "C" int zff_c2c(const zff_layout *lin, const double *in,
                       const zff_layout *lout, double *out, int naxes,
                       const int *axes, int forward, double fct, int nthreads) {
  try {
    if (!in || !out) fail(ZFF_EINVAL, "NULL data pointer");
    const shape_t shape = get_shape(lin);
    if (get_shape(lout) != shape) fail(ZFF_ESHAPE, "input and output shapes differ");
    const stride_t sin = get_stride(lin, shape), sout = get_stride(lout, shape);
    const shape_t ax = get_axes(naxes, axes, shape.size());
    if (in == out && sin != sout)
      fail(ZFF_EINVAL, "in-place transform needs identical layouts");
#ifndef ZFF_COMPLEX_MARSHAL
    const cfmav<cplx> vin(reinterpret_cast<const cplx *>(in), shape, sin);
    const vfmav<cplx> vout(reinterpret_cast<cplx *>(out), shape, sout);
    ducc0::c2c(vin, vout, ax, forward != 0, fct, nthreads_of(nthreads));
#else
    const stride_t dense = dense_stride(shape);
    std::vector<cplx> buf(count(shape));
    for_each_offset(shape, sin, dense, [&](std::ptrdiff_t oi, std::ptrdiff_t ob) {
      buf[std::size_t(ob)] = cplx(in[2 * oi], in[2 * oi + 1]);
    });
    const vfmav<cplx> vbuf(buf.data(), shape, dense);
    ducc0::c2c(cfmav<cplx>(vbuf), vbuf, ax, forward != 0, fct, nthreads_of(nthreads));
    for_each_offset(shape, sout, dense, [&](std::ptrdiff_t oo, std::ptrdiff_t ob) {
      out[2 * oo] = buf[std::size_t(ob)].real();
      out[2 * oo + 1] = buf[std::size_t(ob)].imag();
    });
#endif
    zff_clear_message();
    return ZFF_OK;
  } catch (const zff_error &e) {
    zff_set_message(e.msg);
    return e.status;
  } catch (...) {
    return zff_status_from_exception();
  }
}
