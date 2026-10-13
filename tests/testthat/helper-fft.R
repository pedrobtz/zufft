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

# Results with different thread counts: bit-identical on builds without
# fused multiply-add (CRAN's x86-64 SSE2 builds); within the tolerance on
# FMA hardware, where ducc0's SIMD batches of lines, whose boundaries depend
# on the thread split, round differently from its scalar tail (design §10).
expect_threads_equal <- function(actual, expected, N = length(expected)) {
  if (isTRUE(zufft_info()$fma)) {
    expect_fft_equal(actual, expected, N = N)
  } else {
    expect_identical(actual, expected)
  }
}

# The SciPy reference fixtures (tools/make-scipy-reference.py): the cases
# table and a reader for one stored array.
scipy_cases <- function() {
  dir <- test_path("fixtures", "scipy")
  cases <- utils::read.delim(
    file.path(dir, "cases.tsv"),
    colClasses = "character",
    na.strings = character(0)
  )
  size <- file.size(file.path(dir, "data.bin"))
  con <- file(file.path(dir, "data.bin"), "rb")
  on.exit(close(con))
  data <- readBin(con, "double", n = size / 8, size = 8, endian = "little")
  list(cases = cases, data = data)
}

scipy_array <- function(data, dims, cplx, off) {
  d <- as.integer(strsplit(dims, ";", fixed = TRUE)[[1]])
  n <- prod(d)
  off <- as.numeric(off)
  if (cplx == "1") {
    v <- data[off + seq_len(2 * n)]
    x <- complex(real = v[c(TRUE, FALSE)], imaginary = v[c(FALSE, TRUE)])
  } else {
    x <- data[off + seq_len(n)]
  }
  if (length(d) > 1) {
    dim(x) <- d
  }
  x
}

# Runs one fixture case through zufft; returns NULL on success or a string
# describing the failure.
scipy_run <- function(row, data) {
  num <- function(s) {
    if (nzchar(s)) as.numeric(strsplit(s, ";", fixed = TRUE)[[1]]) else NULL
  }
  x <- scipy_array(data, row$in_dims, row$in_cplx, row$in_off)
  n <- num(row$n)
  axes <- num(row$axes)
  norm <- if (nzchar(row$norm)) row$norm else "backward"
  orth <- if (nzchar(row$orth)) as.logical(row$orth) else NULL
  inverse <- row$inverse == "1"
  type <- if (nzchar(row$type)) as.integer(row$type) else NULL
  call <- function() {
    switch(
      row$fn,
      c2c = fft_c2c(x, inverse = inverse, n = n, axes = axes, norm = norm),
      r2c = fft_r2c(x, n = n, axes = axes, norm = norm),
      c2r = fft_c2r(x, n = n, axes = axes, norm = norm),
      dct = fft_dct(
        x,
        type,
        inverse,
        n = n,
        axes = axes,
        norm = norm,
        orthogonalize = orth
      ),
      dst = fft_dst(
        x,
        type,
        inverse,
        n = n,
        axes = axes,
        norm = norm,
        orthogonalize = orth
      )
    )
  }
  if (row$error == "1") {
    res <- tryCatch(call(), zufft_error = function(e) e)
    return(
      if (inherits(res, "zufft_error")) {
        NULL
      } else {
        "SciPy fails but zufft does not"
      }
    )
  }
  got <- tryCatch(call(), error = function(e) e)
  if (inherits(got, "error")) {
    return(paste("error:", conditionMessage(got)))
  }
  want <- scipy_array(data, row$out_dims, row$out_cplx, row$out_off)
  if (!identical(length(got), length(want))) {
    return("length differs")
  }
  dims <- as.integer(strsplit(row$in_dims, ";", fixed = TRUE)[[1]])
  ax <- if (is.null(axes)) seq_along(dims) else axes
  N <- prod(pmax(dims[ax], if (is.null(n)) 1 else n)) *
    if (row$fn %in% c("dct", "dst")) 2 else 1
  err <- max(Mod(as.vector(got) - as.vector(want)))
  if (err > fft_tol(want, N)) {
    sprintf("max error %.3g over tolerance %.3g", err, fft_tol(want, N))
  }
}
