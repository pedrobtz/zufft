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

/* Discrete cosine and sine transforms of type 1-4 on real buffers of equal
 * shape. `ortho` applies SciPy's orthogonalize correction to the first and
 * last entries. DCT-I needs every transformed length >= 2. */
int zff_dct(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int type, double fct,
            int ortho, int nthreads);
int zff_dst(const zff_layout *lin, const double *in, const zff_layout *lout,
            double *out, int naxes, const int *axes, int type, double fct,
            int ortho, int nthreads);

/* Fast lengths (zff_lengths.cpp): the smallest length >= n, or the largest
 * <= n, with factors 2, 3, 5, 7, 11 (complex) or 2, 3, 5 (real). For n >= 1
 * and n <= 2^52; never throw. */
size_t zff_good_size(size_t n, int real);
size_t zff_prev_good_size(size_t n, int real);

/* The session's default thread request, as fft_workers() stores it
 * (zff_pool.cpp): a positive count or -k for all cores but k - 1. Read
 * without R by the C table when a caller passes nthreads = 0. */
void zff_set_default_workers(int n);
int zff_default_workers(void);

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
const char *zff_fp_contract(void);
const char *zff_threading_mode(void);

/* The thread pool (zff_pool.cpp). zff_pool_enter() takes the process-wide
 * entry gate and grows the pool for a transform on `nthreads` threads;
 * zff_pool_leave() releases the gate. zff_pool_shutdown() joins every
 * worker (package unload). */
int zff_pool_enter(int nthreads);
void zff_pool_leave(void);
void zff_pool_shutdown(void);
size_t zff_pool_size(void);
size_t zff_hardware_threads(void);

#ifdef __cplusplus
}
#endif

#endif
