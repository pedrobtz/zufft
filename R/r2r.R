#' Discrete cosine and sine transforms
#'
#' `fft_dct()` and `fft_dst()` compute discrete cosine and sine transforms of
#' types 1 to 4, or their inverses, over any subset of the dimensions of an
#' array. The definitions, scaling and `orthogonalize` behaviour are those of
#' `scipy.fft.dct()`, `dctn()`, `dst()` and `dstn()`.
#'
#' Unnormalised (`norm = "backward"` or `"none"` in the forward direction),
#' for a length `N`, `fft_dct()` computes
#'
#' - type 1: `y[k] = x[0] + (-1)^k x[N-1] + 2 sum_{n=1}^{N-2} x[n] cos(pi k n / (N-1))`
#' - type 2: `y[k] = 2 sum_{n=0}^{N-1} x[n] cos(pi k (2n+1) / (2N))`
#' - type 3: `y[k] = x[0] + 2 sum_{n=1}^{N-1} x[n] cos(pi (2k+1) n / (2N))`
#' - type 4: `y[k] = 2 sum_{n=0}^{N-1} x[n] cos(pi (2k+1) (2n+1) / (4N))`
#'
#' and `fft_dst()` the matching sine sums (type 1 over `N + 1`, types 2 to
#' 4 as above with sines and indices shifted by one). Type 1 needs lengths of
#' at least 2 for the cosine transform.
#'
#' `inverse = TRUE` computes the inverse: types 2 and 3 swap, and the
#' scaling moves to the other direction. With `norm = "backward"` the
#' inverse is scaled by `1/N`, where `N` is `2(n - 1)` for DCT-I, `2(n + 1)`
#' for DST-I and `2n` otherwise, per transformed axis, so that
#' `fft_dct(fft_dct(x), inverse = TRUE)` returns `x`.
#'
#' @inheritParams fft_c2c
#' @param x A double, integer, logical or complex vector or array. Complex
#'   input is transformed as its real and imaginary parts separately.
#' @param type The transform type: 1, 2, 3 or 4.
#' @param inverse `TRUE` for the inverse transform.
#' @param norm Where the scaling goes, as in [fft_c2c()]. `"ortho"` makes the
#'   transform orthonormal when `orthogonalize` is `TRUE`.
#' @param orthogonalize Whether to scale the first and last terms so that
#'   the `"ortho"` transform matrix is orthogonal. `NULL` (the default)
#'   means `norm == "ortho"`, as in SciPy. For complex input an explicit
#'   value is ignored and `norm == "ortho"` is used, as SciPy does.
#'
#' @return A double vector or array (complex for complex input) of the same
#'   shape as `x` after cropping or padding to `n`.
#'
#' @family transforms
#' @export
#' @examples
#' x <- c(1, 2, 3, 4, 3, 2)
#' fft_dct(x)
#' fft_dct(fft_dct(x), inverse = TRUE)
#' fft_dst(x, type = 4, norm = "ortho")
#'
#' # an orthonormal DCT-II along the columns of a matrix
#' m <- matrix(rnorm(12), 4, 3)
#' fft_dct(m, axes = 1, norm = "ortho")
fft_dct <- function(
  x,
  type = 2L,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  orthogonalize = NULL,
  workers = NULL
) {
  r2r(x, 0L, type, inverse, n, axes, norm, orthogonalize, workers, sys.call())
}

#' @rdname fft_dct
#' @export
fft_dst <- function(
  x,
  type = 2L,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  orthogonalize = NULL,
  workers = NULL
) {
  r2r(x, 1L, type, inverse, n, axes, norm, orthogonalize, workers, sys.call())
}

# Shared body of fft_dct() (kind 0) and fft_dst() (kind 1), after SciPy's
# _r2r: an inverse swaps types 2 and 3 and the direction of the scaling.
r2r <- function(
  x,
  kind,
  type,
  inverse,
  n,
  axes,
  norm,
  orthogonalize,
  workers,
  call
) {
  x <- as_numeric_input(x, call)
  if (!is_whole(type) || length(type) != 1L || !type %in% 1:4) {
    zufft_abort("`type` must be 1, 2, 3 or 4.", "zufft_invalid_argument", call)
  }
  type <- as.integer(type)
  inverse <- check_inverse(inverse, call)
  norm <- check_norm(norm, call)
  if (
    !is.null(orthogonalize) &&
      (!is.logical(orthogonalize) ||
        length(orthogonalize) != 1L ||
        is.na(orthogonalize))
  ) {
    zufft_abort(
      "`orthogonalize` must be NULL, TRUE or FALSE.",
      "zufft_invalid_argument",
      call
    )
  }
  d <- array_dims(x)
  axes <- check_axes(axes, length(d), call)
  n <- check_n(n, length(axes), d[axes], call)
  check_lengths(n, if (type == 1L && kind == 0L) 2 else 1, call)
  nthreads <- resolve_workers(workers, call)

  forward <- !inverse
  if (inverse && type %in% 2:3) {
    type <- 5L - type
  }
  inorm <- inorm_of(norm, forward)
  one <- function(re, ortho) {
    .Call(zff_r2r_call, re, kind, d, axes - 1L, n, type, inorm, ortho, nthreads)
  }
  if (is.complex(x)) {
    # SciPy's realtransforms.py calls the transform on each part without
    # passing orthogonalize, so its default (norm == "ortho") applies.
    ortho <- norm == "ortho"
    out <- complex(real = one(Re(x), ortho), imaginary = one(Im(x), ortho))
  } else {
    ortho <- if (is.null(orthogonalize)) norm == "ortho" else orthogonalize
    out <- one(x, ortho)
  }
  od <- d
  od[axes] <- n
  set_result_attributes(out, x, od, axes)
}
