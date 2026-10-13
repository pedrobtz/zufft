#' Fast transform lengths
#'
#' `fft_next_len()` returns the smallest length at least `n` that zufft
#' transforms fastest, and `fft_prev_len()` the largest at most `n`. Padding
#' or cropping an input to such a length with the `n` argument of the
#' transforms can speed them up considerably. They are SciPy's
#' `next_fast_len()` and `prev_fast_len()`.
#'
#' Fast lengths have no prime factor above 11 for complex transforms, or
#' above 5 for real ones (`real = TRUE`), as in ducc0's `good_size`.
#'
#' @param n Positive whole numbers, at most 2^52.
#' @param real `TRUE` for the lengths of real transforms ([fft_r2c()],
#'   [fft_c2r()], [fft_dct()], [fft_dst()]).
#' @return A double vector of the same length as `n`.
#' @seealso [stats::nextn()], R's own version for [stats::fft()].
#' @family helpers
#' @export
#' @examples
#' fft_next_len(c(1009, 999983))
#' fft_next_len(1009, real = TRUE)
#' fft_prev_len(1009)
fft_next_len <- function(n, real = FALSE) {
  fast_len(n, real, FALSE, sys.call())
}

#' @rdname fft_next_len
#' @export
fft_prev_len <- function(n, real = FALSE) {
  fast_len(n, real, TRUE, sys.call())
}

fast_len <- function(n, real, prev, call) {
  if (!is_whole(n) || any(n < 1) || any(n > 2^52)) {
    zufft_abort(
      "`n` must contain whole numbers from 1 to 2^52.",
      "zufft_invalid_argument",
      call
    )
  }
  if (!is.logical(real) || length(real) != 1L || is.na(real)) {
    zufft_abort("`real` must be TRUE or FALSE.", "zufft_invalid_argument", call)
  }
  .Call(zff_lengths_call, as.double(n), real, prev)
}

#' Sample frequencies
#'
#' `fft_freq()` returns the frequency of each entry of a length-`n`
#' transform from [fft_c2c()], in cycles per unit of the sample spacing `d`:
#' `0, 1, ..., ceiling(n / 2) - 1, -floor(n / 2), ..., -1`, divided by
#' `d * n`. `fft_rfreq()` returns the frequencies of the `n %/% 2 + 1`
#' entries of [fft_r2c()]: `0, 1, ..., n %/% 2`, divided by `d * n`. They
#' are SciPy's `fftfreq()` and `rfftfreq()`.
#'
#' @param n The transform length, a positive whole number.
#' @param d The sample spacing, a positive number.
#' @return A double vector.
#' @family helpers
#' @export
#' @examples
#' fft_freq(8)
#' fft_freq(7, d = 0.1)
#' fft_rfreq(8)
fft_freq <- function(n, d = 1) {
  check_freq_args(n, d, sys.call())
  k <- seq_len(n) - 1
  k[k >= ceiling(n / 2)] <- k[k >= ceiling(n / 2)] - n
  k / (d * n)
}

#' @rdname fft_freq
#' @export
fft_rfreq <- function(n, d = 1) {
  check_freq_args(n, d, sys.call())
  (0:(n %/% 2)) / (d * n)
}

check_freq_args <- function(n, d, call) {
  if (!is_whole(n) || length(n) != 1L || n < 1) {
    zufft_abort(
      "`n` must be a positive whole number.",
      "zufft_invalid_argument",
      call
    )
  }
  if (!is.numeric(d) || length(d) != 1L || !is.finite(d) || d <= 0) {
    zufft_abort(
      "`d` must be a positive number.",
      "zufft_invalid_argument",
      call
    )
  }
}

#' Shift the zero frequency to the centre
#'
#' `fft_shift()` rotates each chosen dimension of `x` by `floor(n / 2)`, so
#' that the zero-frequency entry of a transform sits in the middle;
#' `fft_ishift()` undoes it. They are SciPy's `fftshift()` and
#' `ifftshift()`. `dim`, `dimnames` and `names` move with the values.
#'
#' @param x A vector or array.
#' @param axes The dimensions to shift, 1-based. `NULL` means all of them.
#' @return `x`, rotated.
#' @family helpers
#' @export
#' @examples
#' fft_shift(fft_freq(8))
#' fft_ishift(fft_shift(1:7))
fft_shift <- function(x, axes = NULL) {
  roll_axes(x, axes, inverse = FALSE, sys.call())
}

#' @rdname fft_shift
#' @export
fft_ishift <- function(x, axes = NULL) {
  roll_axes(x, axes, inverse = TRUE, sys.call())
}

roll_axes <- function(x, axes, inverse, call) {
  if (!is.atomic(x) && !is.list(x)) {
    zufft_abort(
      "`x` must be a vector or an array.",
      "zufft_invalid_argument",
      call
    )
  }
  d <- dim(x)
  if (is.null(d)) {
    d <- length(x)
  }
  axes <- check_axes(axes, length(d), call)
  idx <- lapply(d, seq_len)
  for (a in axes) {
    n <- d[a]
    s <- if (inverse) -(n %/% 2) else n %/% 2
    idx[[a]] <- ((seq_len(n) - 1 - s) %% n) + 1
  }
  if (is.null(dim(x))) {
    return(x[idx[[1]]])
  }
  do.call(`[`, c(list(x), idx, drop = FALSE))
}
