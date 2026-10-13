/* The C interface of zufft's C++ shim over ducc0 (design §4, §7). Every
 * function is noexcept, never calls R, and reports failure through a stable
 * status code plus a thread-local message. The R glue and the registered C
 * table call the same functions. */
#ifndef ZFF_SHIM_H
#define ZFF_SHIM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Mirrors zufft_status in inst/include/zufft.h (Stage 7). */
enum {
  ZFF_OK = 0,
  ZFF_EINVAL = 1,
  ZFF_ESHAPE = 2,
  ZFF_EOVERFLOW = 3,
  ZFF_ENOMEM = 4,
  ZFF_ETHREAD = 5,
  ZFF_EENGINE = 6,
  ZFF_EINTERNAL = 7
};

/* A strided array view. Shapes are extents; strides are in elements (one
 * double for real buffers, one (re, im) pair for complex ones); a NULL
 * stride means dense column-major. Mirrors zufft_layout in zufft.h. */
typedef struct {
  int ndim;
  const size_t *shape;
  const ptrdiff_t *stride;
} zff_layout;

/* Complex-to-complex transform over `axes` (0-based). Complex buffers are
 * (re, im) pairs. in == out with identical layouts runs in place. */
int zff_c2c(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads);

/* Real-to-complex: the output's last listed axis has n / 2 + 1 entries. */
int zff_r2c(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads);

/* Complex-to-real: the input's last listed axis has n / 2 + 1 entries, where
 * n is the output's extent there. The input is not modified. */
int zff_c2r(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int forward, double fct,
            int nthreads);

/* Complex transform of real input: full-length complex output, the second
 * half filled by Hermitian symmetry (SciPy's c2c_sym_internal). */
int zff_c2c_real(const zff_layout *lin, const double *in,
                 const zff_layout *lout, double *out, int naxes,
                 const int *axes, int forward, double fct, int nthreads);

/* "zero-copy" or "marshal" (design §12.2). */
const char *zff_complex_path(void);

/* Windows go/no-go stress test (design §12.1); zff_stress.cpp. */
int zff_thread_stress(int nthreads, int pools, int regions, double *checksum);

/* This thread's last failure message; empty after a successful call. */
const char *zff_message(void);

/* Build facts reported by zufft_info(). */
int zff_simd_width(void);
const char *zff_simd_backend(void);
int zff_fma(void);
const char *zff_threading_mode(void);

/* Pool facts (zff_pool.cpp). */
size_t zff_pool_size(void);
size_t zff_hardware_threads(void);

#ifdef __cplusplus
}
#endif

#endif
