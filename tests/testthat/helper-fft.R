# Shared helpers for the transform tests (design §10).

# The numerical criterion of design §10: max |actual - expected| within
# 32 eps max(1, log2 N) max(1, max |expected|).
fft_tol <- function(expected, N) {
  32 * .Machine$double.eps * max(1, log2(N)) * max(1, max(Mod(expected)))
}

# The comparison itself: NULL when within the tolerance, else a message.
fft_mismatch <- function(actual, expected, N = length(expected)) {
  if (!identical(length(actual), length(expected))) {
    return(sprintf("length %d, expected %d", length(actual), length(expected)))
  }
  err <- if (length(expected)) max(Mod(actual - expected)) else 0
  tol <- fft_tol(expected, N)
  if (err > tol) sprintf("max error %.3g over tolerance %.3g", err, tol)
}

# Batches of comparisons made inside expect_fft_batch() (below).
fft_batch <- new.env(parent = emptyenv())

expect_fft_equal <- function(
  actual,
  expected,
  N = length(expected),
  label = NULL
) {
  msg <- fft_mismatch(actual, expected, N)
  b <- fft_batch$current
  if (!is.null(b)) {
    b$count <- b$count + 1L
    if (!is.null(msg)) {
      b$bad <- c(b$bad, paste0(if (is.null(label)) "?" else label, ": ", msg))
    }
    return(invisible(actual))
  }
  if (is.null(msg)) {
    succeed()
  } else {
    fail(paste0(if (is.null(label)) "" else paste0(label, ": "), msg))
  }
  invisible(actual)
}

# Runs `code`, collecting every expect_fft_equal() inside it into one
# expectation. Loops over many lengths then cost one expectation instead of
# hundreds, which matters under gctorture (r-actions' gctorture.yml).
expect_fft_batch <- function(code) {
  b <- new.env(parent = emptyenv())
  b$bad <- character(0)
  b$count <- 0L
  old <- fft_batch$current
  fft_batch$current <- b
  on.exit(fft_batch$current <- old)
  force(code)
  fft_batch$current <- old
  expect_gt(b$count, 0L)
  expect_identical(b$bad, character(0))
}

# The defining sum, O(n^2), for vectors. The exponent is reduced modulo n
# before scaling so the twiddles stay accurate.
dft_direct <- function(x, inverse = FALSE) {
  n <- length(x)
  k <- 0:(n - 1)
  s <- if (inverse) 1 else -1
  w <- exp(s * 2i * pi * (outer(k, k) %% n) / n)
  as.vector(w %*% as.complex(x))
}

# stats::fft along one axis of an array, through aperm and mvfft.
fft_axis_oracle <- function(a, axis, inverse = FALSE) {
  d <- dim(a)
  p <- c(axis, setdiff(seq_along(d), axis))
  b <- aperm(a, p)
  m <- matrix(as.complex(b), nrow = d[axis])
  b2 <- array(stats::mvfft(m, inverse = inverse), dim(b))
  aperm(b2, order(p))
}

fft_axes_oracle <- function(a, axes, inverse = FALSE) {
  for (ax in axes) {
    a <- fft_axis_oracle(a, ax, inverse)
  }
  a
}

random_complex <- function(n) complex(real = rnorm(n), imaginary = rnorm(n))

# SciPy's unnormalised DCT and DST definitions, by direct summation.
r2r_direct <- function(x, kind = c("dct", "dst"), type = 2) {
  kind <- match.arg(kind)
  N <- length(x)
  k <- 0:(N - 1)
  nn <- 0:(N - 1)
  y <- numeric(N)
  for (i in seq_len(N)) {
    kk <- k[i]
    y[i] <- switch(
      paste(kind, type),
      "dct 1" = x[1] +
        (-1)^kk * x[N] +
        2 * sum(x[-c(1, N)] * cos(pi * kk * nn[-c(1, N)] / (N - 1))),
      "dct 2" = 2 * sum(x * cos(pi * kk * (2 * nn + 1) / (2 * N))),
      "dct 3" = x[1] +
        2 * sum(x[-1] * cos(pi * (2 * kk + 1) * nn[-1] / (2 * N))),
      "dct 4" = 2 * sum(x * cos(pi * (2 * kk + 1) * (2 * nn + 1) / (4 * N))),
      "dst 1" = 2 * sum(x * sin(pi * (kk + 1) * (nn + 1) / (N + 1))),
      "dst 2" = 2 * sum(x * sin(pi * (kk + 1) * (2 * nn + 1) / (2 * N))),
      "dst 3" = (-1)^kk *
        x[N] +
        2 * sum(x[-N] * sin(pi * (2 * kk + 1) * (nn[-N] + 1) / (2 * N))),
      "dst 4" = 2 * sum(x * sin(pi * (2 * kk + 1) * (2 * nn + 1) / (4 * N)))
    )
  }
  y
}

# TRUE when n has no prime factor outside `primes`.
largest_factor_ok <- function(n, primes) {
  for (p in primes) {
    while (n %% p == 0) {
      n <- n / p
    }
  }
  n == 1
}

# Same attributes and type as expected, values within the tolerance.
expect_stats_equal <- function(actual, expected) {
  b <- fft_batch$current
  if (!is.null(b)) {
    b$count <- b$count + 1L
    if (
      !identical(attributes(actual), attributes(expected)) ||
        !identical(typeof(actual), typeof(expected))
    ) {
      b$bad <- c(b$bad, "attributes or type differ")
      return(invisible(actual))
    }
    return(expect_fft_equal(as.vector(actual), as.vector(expected)))
  }
  expect_identical(attributes(actual), attributes(expected))
  expect_identical(typeof(actual), typeof(expected))
  expect_fft_equal(as.vector(actual), as.vector(expected))
}
