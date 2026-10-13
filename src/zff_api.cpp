/* The registered C table of inst/include/zufft.h (design §7).
 *
 * Each member converts the public layout to the shim's, resolves the thread
 * request, and calls the same shim function the R glue uses, so the two
 * paths cannot drift. Nothing here calls R. */
#include <algorithm>
#include <cstddef>
#include <cstdlib>
#include <cstring>

#include "zff_shim.h"
#define ZUFFT_NO_R
#include "zufft.h"

void zff_set_message(const char *msg) noexcept;

static_assert(ZUFFT_OK == ZFF_OK && ZUFFT_EINVAL == ZFF_EINVAL &&
                  ZUFFT_ESHAPE == ZFF_ESHAPE && ZUFFT_EOVERFLOW == ZFF_EOVERFLOW &&
                  ZUFFT_ENOMEM == ZFF_ENOMEM && ZUFFT_ETHREAD == ZFF_ETHREAD &&
                  ZUFFT_EENGINE == ZFF_EENGINE && ZUFFT_EINTERNAL == ZFF_EINTERNAL,
              "zufft.h and zff_shim.h disagree on status codes");

namespace {

zff_layout convert(const zufft_layout *l) {
  zff_layout out = {0, nullptr, nullptr};
  if (l) out = {l->ndim, l->shape, l->stride};
  return out;
}

/* nthreads as in design §6.5: 0 is the session default from fft_workers(),
 * -k is all available cores but k - 1; capped at the cores and at 2 when
 * _R_CHECK_LIMIT_CORES_ is set. */
int resolve(int nthreads) {
  int n = nthreads == 0 ? zff_default_workers() : nthreads;
  const int cores = int(std::min<size_t>(zff_hardware_threads(), 1 << 20));
  if (n < 0) n = std::max(1, cores + 1 + n);
  n = std::min(n, cores);
  const char *lim = std::getenv("_R_CHECK_LIMIT_CORES_");
  if (lim && *lim && std::strcmp(lim, "false") != 0 && std::strcmp(lim, "FALSE") != 0)
    n = std::min(n, 2);
  return std::max(n, 1);
}

int api_c2c(const zufft_layout *lin, const double *in, const zufft_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads) {
  const zff_layout a = convert(lin), b = convert(lout);
  return zff_c2c(lin ? &a : nullptr, in, lout ? &b : nullptr, out, naxes, axes,
                 forward, fct, resolve(nthreads));
}

int api_r2c(const zufft_layout *lin, const double *in, const zufft_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads) {
  const zff_layout a = convert(lin), b = convert(lout);
  return zff_r2c(lin ? &a : nullptr, in, lout ? &b : nullptr, out, naxes, axes,
                 forward, fct, resolve(nthreads));
}

int api_c2r(const zufft_layout *lin, const double *in, const zufft_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads) {
  const zff_layout a = convert(lin), b = convert(lout);
  return zff_c2r(lin ? &a : nullptr, in, lout ? &b : nullptr, out, naxes, axes,
                 forward, fct, resolve(nthreads));
}

int api_dct(const zufft_layout *lin, const double *in, const zufft_layout *lout,
            double *out, int naxes, const int *axes, int type, double fct,
            int ortho, int nthreads) {
  const zff_layout a = convert(lin), b = convert(lout);
  return zff_dct(lin ? &a : nullptr, in, lout ? &b : nullptr, out, naxes, axes,
                 type, fct, ortho, resolve(nthreads));
}

int api_dst(const zufft_layout *lin, const double *in, const zufft_layout *lout,
            double *out, int naxes, const int *axes, int type, double fct,
            int ortho, int nthreads) {
  const zff_layout a = convert(lin), b = convert(lout);
  return zff_dst(lin ? &a : nullptr, in, lout ? &b : nullptr, out, naxes, axes,
                 type, fct, ortho, resolve(nthreads));
}

size_t api_good_size(size_t n, int real) {
  if (n == 0 || n > (size_t(1) << 52)) return 0;
  return zff_good_size(n, real);
}

const zufft_api table = {
    sizeof(zufft_api), ZUFFT_ABI_VERSION, 0u,
    api_c2c,           api_r2c,           api_c2r, api_dct, api_dst,
    api_good_size,     zff_message,
};

}  // namespace

/* Registered as "zufft_api_v1" with R_RegisterCCallable (zufft.c). */
extern "C" const zufft_api *zff_api_v1(void) { return &table; }
