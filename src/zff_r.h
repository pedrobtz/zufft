/* Declarations shared by zufft's R glue files. */
#ifndef ZFF_R_H
#define ZFF_R_H

#include <Rinternals.h>
#include <stddef.h>

void zff_raise(int status, const char *msg);
double zff_norm_factor(int inorm, const size_t *len, int naxes, size_t mult, int delta);
SEXP zff_fft(SEXP x, SEXP kind, SEXP dims, SEXP axes, SEXP n, SEXP forward,
             SEXP inorm, SEXP nthreads);
SEXP zff_r2r(SEXP x, SEXP kind, SEXP dims, SEXP axes, SEXP n, SEXP type,
             SEXP inorm, SEXP ortho, SEXP nthreads);

#endif
