#' Discrete Fourier transforms
#'
#' `fft_c2c()` computes the complex discrete Fourier transform of `x` or its
#' inverse, `fft_r2c()` the transform of real input keeping only the
#' non-redundant half of the last transformed axis, and `fft_c2r()` the
#' inverse of `fft_r2c()`, returning real values. All three work over any
#' subset of the dimensions of an array, in O(n log n) time for every length.
#'
#' The conventions are those of `scipy.fft` (`fft`, `fftn`, `rfftn`,
#' `irfftn`): `n` crops or zero-pads each transformed axis before the
#' transform, and `norm` chooses where the scaling goes. They differ from
#' SciPy in two ways: `axes` are 1-based, and `axes = NULL` means every
#' dimension rather than the last one.
#'
#' Speed: R stores arrays column by column, so the first axis is the
#' contiguous one, whereas in NumPy it is the last. The real transforms halve
#' the last listed axis, as SciPy does; listing the first axis last, for
#' example `fft_r2c(m, axes = 2:1)` for a matrix, halves the contiguous axis
#' and is often much faster (about 1.8 times for a 2048 x 2048 matrix).
#'
#' Coming from fftwtools: `fft_c2c(x)` is `fftw(x)` and `fftw_r2c(x)`,
#' `fft_r2c(x)` is `fftw_r2c(x, HermConj = 0)`, and an fftwtools inverse is
#' the zufft inverse with `norm = "none"`, because fftwtools, like
#' [stats::fft()], never scales.
#'
#' @param x A double, integer, logical or complex vector or array. Integer
#'   and logical values are converted to double. `fft_r2c()` needs real
#'   input; `fft_c2r()` treats real input as complex.
#' @param inverse `TRUE` for the inverse transform. `0` and `1` are accepted
#'   too, as in fftwtools.
#' @param n Transform lengths, one per transformed axis (no recycling).
#'   Each axis of `x` is cropped or zero-padded to its length first. `NULL`
#'   keeps the lengths of `x`. For `fft_c2r()`, `n` gives the lengths of the
#'   real output; the last transformed axis of `x` must then hold
#'   `n %/% 2 + 1` values and is cropped or padded to that. Its default is
#'   `2 * (m - 1)` for an input extent `m`, which is always even: give `n`
#'   to recover an odd length.
#' @param axes The dimensions to transform, 1-based, without repeats. `NULL`
#'   means all of them, in order. For the real transforms the last listed
#'   axis is the one that is halved. Use `axes = 1` for a column-wise
#'   transform of a matrix, as [stats::mvfft()] does.
#' @param norm Where the scaling goes. `"backward"` (the default) leaves the
#'   forward transform unscaled and divides the inverse by `N`, the product
#'   of the transformed lengths; `"forward"` does the opposite; `"ortho"`
#'   divides both by `sqrt(N)`; `"none"` scales neither direction, as FFTW,
#'   fftwtools and [stats::fft()] do.
#' @param workers Threads to use. `NULL` uses the session default (1).
#'   Negative values count back from the number of available cores: `-1`
#'   means all of them. Requests are capped at the available cores, and at
#'   2 when `_R_CHECK_LIMIT_CORES_` is set. Threads split the independent
#'   1-D transforms of a multi-dimensional array, so they help only arrays
#'   with at least 32 768 elements and more than one line. Results agree to
#'   rounding whatever the number of threads; they are bit-identical on
#'   builds without fused multiply-add (CRAN's x86-64 builds).
#'
#' @return For `fft_c2c()` and `fft_r2c()` a complex vector or array, for
#'   `fft_c2r()` a double one. Arrays keep their `dim`, with the transformed
#'   extents, and the `dimnames` of axes that were not transformed; `names`
#'   are dropped.
#'
#' @family transforms
#' @seealso [stats::fft()] for R's own complex transform.
#' @export
#' @examples
#' x <- c(1, 2, 3, 4, 3, 2)
#' fft_c2c(x)
#' fft_r2c(x)
#' fft_c2r(fft_r2c(x), n = length(x))
#'
#' # an inverse that matches fftwtools and stats::fft(inverse = TRUE)
#' fft_c2c(fft_c2c(x), inverse = TRUE, norm = "none") / length(x)
#'
#' # columns of a matrix, and both axes
#' m <- matrix(rnorm(12), 4, 3)
#' fft_c2c(m, axes = 1)
#' fft_r2c(m)
fft_c2c <- function(
  x,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
) {
  call <- sys.call()
  x <- as_numeric_input(x, call)
  inverse <- check_inverse(inverse, call)
  norm <- check_norm(norm, call)
  d <- array_dims(x)
  axes <- check_axes(axes, length(d), call)
  n <- check_n(n, length(axes), d[axes], call)
  check_lengths(n, 1, call)
  nthreads <- resolve_workers(workers, call)
  forward <- !inverse
  out <- .Call(
    zff_fft_call,
    x,
    0L,
    d,
    axes - 1L,
    n,
    forward,
    inorm_of(norm, forward),
    nthreads
  )
  od <- d
  od[axes] <- n
  set_result_attributes(out, x, od, axes)
}

#' @rdname fft_c2c
#' @export
fft_r2c <- function(
  x,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
) {
  call <- sys.call()
  x <- as_numeric_input(x, call)
  if (is.complex(x)) {
    zufft_abort(
      "`x` must be real for `fft_r2c()`; use `fft_c2c()` for complex input.",
      "zufft_invalid_argument",
      call
    )
  }
  norm <- check_norm(norm, call)
  d <- array_dims(x)
  axes <- check_axes(axes, length(d), call)
  n <- check_n(n, length(axes), d[axes], call)
  check_lengths(n, 1, call)
  nthreads <- resolve_workers(workers, call)
  out <- .Call(
    zff_fft_call,
    x,
    1L,
    d,
    axes - 1L,
    n,
    TRUE,
    inorm_of(norm, TRUE),
    nthreads
  )
  od <- d
  od[axes] <- n
  last <- axes[length(axes)]
  od[last] <- n[length(n)] %/% 2 + 1
  set_result_attributes(out, x, od, axes)
}

#' @rdname fft_c2c
#' @export
fft_c2r <- function(
  x,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
) {
  call <- sys.call()
  x <- as_numeric_input(x, call)
  if (!is.complex(x)) {
    storage.mode(x) <- "complex"
  }
  norm <- check_norm(norm, call)
  d <- array_dims(x)
  axes <- check_axes(axes, length(d), call)
  default <- d[axes]
  default[length(default)] <- 2 * (default[length(default)] - 1)
  n <- check_n(n, length(axes), default, call)
  check_lengths(n, 1, call)
  nthreads <- resolve_workers(workers, call)
  out <- .Call(
    zff_fft_call,
    x,
    2L,
    d,
    axes - 1L,
    n,
    FALSE,
    inorm_of(norm, FALSE),
    nthreads
  )
  od <- d
  od[axes] <- n
  set_result_attributes(out, x, od, axes)
}
