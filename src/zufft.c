#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zff_shim.h"
#include "zff_version.h"

/* zufft_info(): build and runtime facts (design §5.1). */
static SEXP zff_info(void) {
  const char *names[] = {"ducc0_commit", "scipy_commit", "simd_backend",
                         "simd_width", "fma", "threading", "pool_size",
                         "hardware_threads", "complex_path", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_mkString(ZFF_DUCC0_COMMIT));
  SET_VECTOR_ELT(out, 1, Rf_mkString(ZFF_SCIPY_COMMIT));
  SET_VECTOR_ELT(out, 2, Rf_mkString(zff_simd_backend()));
  SET_VECTOR_ELT(out, 3, Rf_ScalarInteger(zff_simd_width()));
  SET_VECTOR_ELT(out, 4, Rf_ScalarLogical(zff_fma()));
  SET_VECTOR_ELT(out, 5, Rf_mkString(zff_threading_mode()));
  SET_VECTOR_ELT(out, 6, Rf_ScalarReal((double) zff_pool_size()));
  SET_VECTOR_ELT(out, 7, Rf_ScalarReal((double) zff_hardware_threads()));
  SET_VECTOR_ELT(out, 8, Rf_mkString(zff_complex_path()));
  UNPROTECT(1);
  return out;
}

/* Stage 2 spikes (design §12.1, §12.2): internal entry points, not API. */

/* A dense column-major complex-to-complex transform of a plain complex
 * vector, unnormalised, through the shim. Exercises the complex path. */
static SEXP zff_scratch_c2c(SEXP z, SEXP forward) {
  if (TYPEOF(z) != CPLXSXP) Rf_error("internal: complex vector expected");
  R_xlen_t n = XLENGTH(z);
  SEXP out = PROTECT(Rf_allocVector(CPLXSXP, n));
  if (n > 0) {
    size_t shape = (size_t) n;
    zff_layout l = {1, &shape, NULL};
    int axis = 0;
    int st = zff_c2c(&l, (const double *) COMPLEX(z), &l, (double *) COMPLEX(out),
                     1, &axis, Rf_asLogical(forward), 1.0, 1);
    if (st != ZFF_OK) Rf_error("zufft engine error %d: %s", st, zff_message());
  }
  UNPROTECT(1);
  return out;
}

/* The Windows go/no-go stress loop; returns the checksum. */
static SEXP zff_stress(SEXP nthreads, SEXP pools, SEXP regions) {
  double checksum = 0;
  int st = zff_thread_stress(Rf_asInteger(nthreads), Rf_asInteger(pools),
                             Rf_asInteger(regions), &checksum);
  if (st != ZFF_OK) Rf_error("zufft thread stress failed (%d): %s", st, zff_message());
  return Rf_ScalarReal(checksum);
}

static const R_CallMethodDef call_methods[] = {
  {"zff_info", (DL_FUNC) &zff_info, 0},
  {"zff_scratch_c2c_call", (DL_FUNC) &zff_scratch_c2c, 2},
  {"zff_stress_call", (DL_FUNC) &zff_stress, 3},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zufft(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
