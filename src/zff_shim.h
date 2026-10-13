/* The C interface of zufft's C++ shim over ducc0 (design §4, §7). Every
 * function is noexcept, never calls R, and reports failure through a stable
 * status code plus a thread-local message. The R glue and the registered C
 * table call the same functions. */
#ifndef ZFF_SHIM_H
#define ZFF_SHIM_H

#include <stddef.h>

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
