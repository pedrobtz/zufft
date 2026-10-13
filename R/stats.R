#' Drop-in replacements for stats::fft() and stats::mvfft()
#'
#' `fft_stats()` and `mvfft_stats()` take the same arguments, check them the
#' same way and return the same structure as [stats::fft()] and
#' [stats::mvfft()]: the attributes of `z` are kept, the inverse is not
#' scaled, and inputs of length 0 or 1 come back unchanged (as complex). The
#' values agree to rounding. The differences: every length runs in
#' O(n log n) (R's code is quadratic in a large prime factor), real input
#' uses a real transform, and threads follow
#' [fft_workers()].
#'
#' A package moves by replacing `fft(` with `zufft::fft_stats(` and adding
#' zufft to `Imports`.
#'
#' @param z A real or complex vector or array (`fft_stats()`), or matrix
#'   (`mvfft_stats()`).
#' @param inverse `TRUE` for the unnormalised inverse transform. `NA` means
#'   forward, as in [stats::fft()].
#' @return A complex vector, array or matrix with the attributes of `z`.
#' @family compatibility
#' @export
#' @examples
#' x <- 1:4
#' fft_stats(x)
#' fft_stats(fft_stats(x), inverse = TRUE) / length(x)
#' all.equal(fft_stats(x), stats::fft(x))
#'
#' m <- matrix(rnorm(12), 4)
#' all.equal(mvfft_stats(m), stats::mvfft(m))
fft_stats <- function(z, inverse = FALSE) {
  out <- stats_input(z, sys.call())
  if (length(out) <= 1L) {
    return(out)
  }
  d <- dim(z)
  dims <- if (is.null(d)) as.double(length(z)) else as.double(d)
  forward <- stats_forward(inverse)
  vals <- if (is.complex(z)) as.vector(z) else as.double(as.vector(z))
  res <- .Call(
    zff_fft_call,
    vals,
    0L,
    dims,
    seq_along(dims) - 1L,
    dims,
    forward,
    0L,
    resolve_workers(NULL)
  )
  attributes(res) <- attributes(out)
  res
}

#' @rdname fft_stats
#' @export
mvfft_stats <- function(z, inverse = FALSE) {
  call <- sys.call()
  out <- stats_input(z, call)
  d <- dim(z)
  if (length(d) != 2L) {
    zufft_abort(
      "vector-valued (multivariate) series required",
      "zufft_invalid_argument",
      call
    )
  }
  if (d[1] <= 1L || d[2] < 1L) {
    return(out)
  }
  vals <- if (is.complex(z)) as.vector(z) else as.double(as.vector(z))
  res <- .Call(
    zff_fft_call,
    vals,
    0L,
    as.double(d),
    0L,
    as.double(d[1]),
    stats_forward(inverse),
    0L,
    resolve_workers(NULL)
  )
  attributes(res) <- attributes(out)
  res
}

# z as complex with its attributes, or stats' "non-numeric argument" error.
stats_input <- function(z, call) {
  if (
    !(is.numeric(z) || is.complex(z) || is.logical(z)) ||
      is.object(z) && is.factor(z)
  ) {
    zufft_abort("non-numeric argument", "zufft_invalid_argument", call)
  }
  out <- z
  storage.mode(out) <- "complex"
  out
}

# fourier.c: asLogical(inverse); NA or FALSE is forward.
stats_forward <- function(inverse) {
  inv <- if (length(inverse)) as.logical(inverse[[1]]) else NA
  is.na(inv) || !inv
}
