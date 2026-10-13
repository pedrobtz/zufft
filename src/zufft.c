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
  /* Decided in Stage 2 (design §12.2). */
  SET_VECTOR_ELT(out, 8, Rf_mkString("undecided"));
  UNPROTECT(1);
  return out;
}

static const R_CallMethodDef call_methods[] = {
  {"zff_info", (DL_FUNC) &zff_info, 0},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zufft(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
