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

/* Visits every element of a shape in column-major order with its element
 * offsets in two strided layouts (marshal path only). */
template <typename F>
[[maybe_unused]] void for_each_offset(const shape_t &shape, const stride_t &sa,
                                      const stride_t &sb, F f) {
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

[[maybe_unused]] stride_t dense_stride(const shape_t &shape) {
  stride_t s(shape.size());
  std::ptrdiff_t acc = 1;
  for (std::size_t i = 0; i < shape.size(); ++i) {
    s[i] = acc;
    acc *= std::ptrdiff_t(shape[i]);
  }
  return s;
}

[[maybe_unused]] std::size_t count(const shape_t &shape) {
  std::size_t n = 1;
  for (auto s : shape) n *= s;
  return n;
}

/* A complex input buffer as ducc0 sees it: viewed in place (zero-copy) or
 * copied into genuine std::complex<double> storage (marshal). */
class complex_in {
 public:
  complex_in(const double *p, const shape_t &shape, const stride_t &stride)
#ifdef ZFF_COMPLEX_MARSHAL
      : buf_(count(shape)),
        view_(buf_.data(), shape, dense_stride(shape)) {
    const stride_t dense = dense_stride(shape);
    for_each_offset(shape, stride, dense, [&](std::ptrdiff_t oi, std::ptrdiff_t ob) {
      buf_[std::size_t(ob)] = cplx(p[2 * oi], p[2 * oi + 1]);
    });
  }
#else
      : view_(reinterpret_cast<const cplx *>(p), shape, stride) {
  }
#endif
  const cfmav<cplx> &view() const { return view_; }

 private:
#ifdef ZFF_COMPLEX_MARSHAL
  std::vector<cplx> buf_;
#endif
  cfmav<cplx> view_;
};

/* A complex output buffer as ducc0 sees it; finish() copies a marshalled
 * result back. */
class complex_out {
 public:
  complex_out(double *p, const shape_t &shape, const stride_t &stride)
#ifdef ZFF_COMPLEX_MARSHAL
      : p_(p), shape_(shape), stride_(stride), buf_(count(shape)),
        view_(buf_.data(), shape, dense_stride(shape)) {
  }
#else
      : view_(reinterpret_cast<cplx *>(p), shape, stride) {
  }
#endif
  const vfmav<cplx> &view() const { return view_; }
  void finish() {
#ifdef ZFF_COMPLEX_MARSHAL
    const stride_t dense = dense_stride(shape_);
    for_each_offset(shape_, stride_, dense, [&](std::ptrdiff_t oo, std::ptrdiff_t ob) {
      p_[2 * oo] = buf_[std::size_t(ob)].real();
      p_[2 * oo + 1] = buf_[std::size_t(ob)].imag();
    });
#endif
  }

 private:
#ifdef ZFF_COMPLEX_MARSHAL
  double *p_;
  shape_t shape_;
  stride_t stride_;
  std::vector<cplx> buf_;
#endif
  vfmav<cplx> view_;
};

int finish_ok() {
  zff_clear_message();
  return ZFF_OK;
}

int finish_error(const zff_error &e) {
  zff_set_message(e.msg);
  return e.status;
}

/* Shape of the half-complex side of a real transform: the last axis holds
 * n / 2 + 1 values. */
shape_t half_shape(shape_t shape, const shape_t &axes) {
  shape[axes.back()] = shape[axes.back()] / 2 + 1;
  return shape;
}

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
    complex_in cin(in, shape, sin);
    complex_out cout(out, shape, sout);
    ducc0::c2c(cin.view(), cout.view(), ax, forward != 0, fct, nthreads_of(nthreads));
    cout.finish();
    return finish_ok();
  } catch (const zff_error &e) {
    return finish_error(e);
  } catch (...) {
    return zff_status_from_exception();
  }
}

extern "C" int zff_r2c(const zff_layout *lin, const double *in,
                       const zff_layout *lout, double *out, int naxes,
                       const int *axes, int forward, double fct, int nthreads) {
  try {
    if (!in || !out) fail(ZFF_EINVAL, "NULL data pointer");
    const shape_t shape = get_shape(lin);
    const shape_t ax = get_axes(naxes, axes, shape.size());
    const shape_t oshape = half_shape(shape, ax);
    if (get_shape(lout) != oshape) fail(ZFF_ESHAPE, "output shape must halve the last axis");
    const stride_t sin = get_stride(lin, shape), sout = get_stride(lout, oshape);
    const cfmav<double> vin(in, shape, sin);
    complex_out cout(out, oshape, sout);
    ducc0::r2c(vin, cout.view(), ax, forward != 0, fct, nthreads_of(nthreads));
    cout.finish();
    return finish_ok();
  } catch (const zff_error &e) {
    return finish_error(e);
  } catch (...) {
    return zff_status_from_exception();
  }
}

extern "C" int zff_c2r(const zff_layout *lin, const double *in,
                       const zff_layout *lout, double *out, int naxes,
                       const int *axes, int forward, double fct, int nthreads) {
  try {
    if (!in || !out) fail(ZFF_EINVAL, "NULL data pointer");
    const shape_t oshape = get_shape(lout);
    const shape_t ax = get_axes(naxes, axes, oshape.size());
    const shape_t shape = half_shape(oshape, ax);
    if (get_shape(lin) != shape) fail(ZFF_ESHAPE, "input shape must be the halved output shape");
    const stride_t sin = get_stride(lin, shape), sout = get_stride(lout, oshape);
    complex_in cin(in, shape, sin);
    const vfmav<double> vout(out, oshape, sout);
    ducc0::c2r(cin.view(), vout, ax, forward != 0, fct, nthreads_of(nthreads));
    return finish_ok();
  } catch (const zff_error &e) {
    return finish_error(e);
  } catch (...) {
    return zff_status_from_exception();
  }
}

/* Complex transform of real input, as SciPy's c2c_sym_internal does it: a
 * real-to-complex transform into the first half of the last axis, then the
 * other half filled by Hermitian symmetry (zff_inst_r2c.cpp). */
void zff_hermitian_fill(const vfmav<cplx> &out, const shape_t &axes, std::size_t nthreads);

extern "C" int zff_c2c_real(const zff_layout *lin, const double *in,
                            const zff_layout *lout, double *out, int naxes,
                            const int *axes, int forward, double fct, int nthreads) {
  try {
    if (!in || !out) fail(ZFF_EINVAL, "NULL data pointer");
    const shape_t shape = get_shape(lin);
    if (get_shape(lout) != shape) fail(ZFF_ESHAPE, "input and output shapes differ");
    const stride_t sin = get_stride(lin, shape), sout = get_stride(lout, shape);
    const shape_t ax = get_axes(naxes, axes, shape.size());
    const cfmav<double> vin(in, shape, sin);
    complex_out cout(out, shape, sout);
    const vfmav<cplx> half(cout.view().data(), half_shape(shape, ax), cout.view().stride());
    ducc0::r2c(vin, half, ax, forward != 0, fct, nthreads_of(nthreads));
    zff_hermitian_fill(cout.view(), ax, nthreads_of(nthreads));
    cout.finish();
    return finish_ok();
  } catch (const zff_error &e) {
    return finish_error(e);
  } catch (...) {
    return zff_status_from_exception();
  }
}

namespace {

/* DCT and DST share their checks: real buffers of equal shape, type 1-4.
 * DCT-I is the only one that needs every length >= 2. */
template <typename F>
int zff_r2r(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int type, bool is_dct,
            F transform) {
  try {
    if (!in || !out) fail(ZFF_EINVAL, "NULL data pointer");
    if (type < 1 || type > 4) fail(ZFF_EINVAL, "transform type must be 1, 2, 3 or 4");
    const shape_t shape = get_shape(lin);
    if (get_shape(lout) != shape) fail(ZFF_ESHAPE, "input and output shapes differ");
    const stride_t sin = get_stride(lin, shape), sout = get_stride(lout, shape);
    const shape_t ax = get_axes(naxes, axes, shape.size());
    if (in == out && sin != sout)
      fail(ZFF_EINVAL, "in-place transform needs identical layouts");
    if (is_dct && type == 1)
      for (auto a : ax)
        if (shape[a] < 2) fail(ZFF_ESHAPE, "DCT-I needs lengths of at least 2");
    transform(cfmav<double>(in, shape, sin), vfmav<double>(out, shape, sout), ax);
    return finish_ok();
  } catch (const zff_error &e) {
    return finish_error(e);
  } catch (...) {
    return zff_status_from_exception();
  }
}

}  // namespace

extern "C" int zff_dct(const zff_layout *lin, const double *in,
                       const zff_layout *lout, double *out, int naxes,
                       const int *axes, int type, double fct, int ortho,
                       int nthreads) {
  return zff_r2r(lin, in, lout, out, naxes, axes, type, true,
                 [&](const cfmav<double> &i, const vfmav<double> &o, const shape_t &ax) {
                   ducc0::dct(i, o, ax, type, fct, ortho != 0, nthreads_of(nthreads));
                 });
}

extern "C" int zff_dst(const zff_layout *lin, const double *in,
                       const zff_layout *lout, double *out, int naxes,
                       const int *axes, int type, double fct, int ortho,
                       int nthreads) {
  return zff_r2r(lin, in, lout, out, naxes, axes, type, false,
                 [&](const cfmav<double> &i, const vfmav<double> &o, const shape_t &ax) {
                   ducc0::dst(i, o, ax, type, fct, ortho != 0, nthreads_of(nthreads));
                 });
}
