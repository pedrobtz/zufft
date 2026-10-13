# fft_c2c(), fft_r2c(), fft_c2r() (design §5.1, §6.1–6.3).

test_that("fft_c2c() matches the defining sum for n <= 64", {
  withr::local_seed(11)
  expect_fft_batch({
    for (n in 1:64) {
      z <- random_complex(n)
      expect_fft_equal(fft_c2c(z), dft_direct(z), label = paste("complex", n))
      x <- rnorm(n)
      expect_fft_equal(fft_c2c(x), dft_direct(x), label = paste("real", n))
      expect_fft_equal(
        fft_c2c(z, inverse = TRUE, norm = "none"),
        dft_direct(z, inverse = TRUE),
        label = paste("inverse", n)
      )
    }
  })
})

test_that("fft_r2c() and fft_c2r() match the defining sum for n <= 64", {
  withr::local_seed(12)
  expect_fft_batch({
    for (n in 1:64) {
      x <- rnorm(n)
      h <- n %/% 2 + 1
      expect_fft_equal(fft_r2c(x), dft_direct(x)[seq_len(h)], N = n, label = n)
      full <- dft_direct(x)
      expect_fft_equal(
        fft_c2r(full[seq_len(h)], n = n, norm = "none"),
        Re(dft_direct(full, inverse = TRUE)),
        N = n,
        label = paste("c2r", n)
      )
    }
  })
})

test_that("fft_c2c() agrees with stats::fft() for lengths 1 to 1024", {
  withr::local_seed(13)
  expect_fft_batch({
    for (n in 1:1024) {
      z <- random_complex(n)
      expect_fft_equal(fft_c2c(z), stats::fft(z), label = n)
    }
  })
})

test_that("fft_c2c() agrees with stats::fft() on large composite lengths", {
  withr::local_seed(14)
  expect_fft_batch({
    for (n in c(2^16, 3^7 * 5, 2 * 3 * 5 * 7 * 11 * 13)) {
      z <- random_complex(n)
      expect_fft_equal(fft_c2c(z), stats::fft(z), label = n)
    }
  })
})

test_that("large prime lengths are exact on a pure tone", {
  # stats::fft() is no oracle here: its O(n^2) pass for a large prime factor
  # misses the tolerance at n = 65537 (1.2e-8 against 7.5e-9 on this signal,
  # where zufft's error is 2.9e-11). A pure tone has an exact spectrum.
  expect_fft_batch({
    for (n in c(10007, 65537, 100003)) {
      m <- 123
      k <- 0:(n - 1)
      x <- exp(2i * pi * ((m * k) %% n) / n)
      want <- complex(n)
      want[m + 1] <- n
      expect_fft_equal(fft_c2c(x), want, label = n)
      expect_fft_equal(
        fft_c2c(want, inverse = TRUE),
        x,
        label = paste("inverse", n)
      )
    }
  })
})

test_that("column-wise transforms agree with stats::mvfft()", {
  withr::local_seed(15)
  m <- matrix(random_complex(60), 12, 5)
  expect_fft_equal(fft_c2c(m, axes = 1), stats::mvfft(m), N = 12)
  expect_fft_equal(
    fft_c2c(m, inverse = TRUE, axes = 1, norm = "none"),
    stats::mvfft(m, inverse = TRUE),
    N = 12
  )
  r <- matrix(rnorm(60), 12, 5)
  expect_fft_equal(fft_c2c(r, axes = 1), stats::mvfft(r), N = 12)
})

test_that("every ordered axis subset of a 3-d array matches the oracle", {
  withr::local_seed(16)
  a <- array(random_complex(5 * 4 * 3), c(5, 4, 3))
  ra <- array(rnorm(5 * 4 * 3), c(5, 4, 3))
  subsets <- list(
    1,
    2,
    3,
    c(1, 2),
    c(2, 1),
    c(1, 3),
    c(3, 2),
    c(1, 2, 3),
    c(3, 1, 2)
  )
  expect_fft_batch({
    for (ax in subsets) {
      lab <- paste(ax, collapse = ",")
      want <- fft_axes_oracle(a, ax)
      expect_fft_equal(
        fft_c2c(a, axes = ax),
        want,
        N = prod(dim(a)[ax]),
        label = lab
      )
      rwant <- fft_axes_oracle(ra, ax)
      expect_fft_equal(
        fft_c2c(ra, axes = ax),
        rwant,
        N = prod(dim(a)[ax]),
        label = lab
      )
      # r2c keeps the first half of the last listed axis
      last <- ax[length(ax)]
      idx <- lapply(dim(ra), seq_len)
      idx[[last]] <- seq_len(dim(ra)[last] %/% 2 + 1)
      half <- do.call(`[`, c(list(rwant), idx, drop = FALSE))
      expect_fft_equal(
        fft_r2c(ra, axes = ax),
        half,
        N = prod(dim(a)[ax]),
        label = lab
      )
      # and c2r inverts it, odd lengths included
      back <- fft_c2r(fft_r2c(ra, axes = ax), n = dim(ra)[ax], axes = ax)
      expect_fft_equal(back, ra, N = prod(dim(a)[ax]), label = lab)
    }
  })
})

test_that("fft_c2c() with no axes transforms every dimension, as stats::fft()", {
  withr::local_seed(17)
  a <- array(random_complex(3 * 4 * 5), c(3, 4, 5))
  expect_fft_equal(fft_c2c(a), stats::fft(a), N = 60)
  expect_identical(dim(fft_c2c(a)), c(3L, 4L, 5L))
})

test_that("every norm round-trips and scales as documented", {
  withr::local_seed(18)
  z <- random_complex(30)
  x <- rnorm(30)
  expect_fft_batch({
    for (norm in c("backward", "ortho", "forward")) {
      expect_fft_equal(
        fft_c2c(fft_c2c(z, norm = norm), TRUE, norm = norm),
        z,
        label = norm
      )
      expect_fft_equal(
        fft_c2r(fft_r2c(x, norm = norm), n = 30, norm = norm),
        x,
        label = norm
      )
    }
  })
  expect_fft_equal(
    fft_c2c(fft_c2c(z, norm = "none"), TRUE, norm = "none") / 30,
    z
  )
  base <- fft_c2c(z, norm = "none")
  expect_fft_equal(fft_c2c(z, norm = "backward"), base)
  expect_fft_equal(fft_c2c(z, norm = "forward"), base / 30)
  expect_fft_equal(fft_c2c(z, norm = "ortho"), base / sqrt(30))
  inv <- fft_c2c(z, TRUE, norm = "none")
  expect_fft_equal(fft_c2c(z, TRUE), inv / 30)
  expect_fft_equal(fft_c2c(z, TRUE, norm = "forward"), inv)
  expect_fft_equal(fft_c2c(z, TRUE, norm = "ortho"), inv / sqrt(30))
})

test_that("Parseval holds under backward, none and ortho", {
  withr::local_seed(19)
  z <- random_complex(100)
  e <- sum(Mod(z)^2)
  expect_equal(sum(Mod(fft_c2c(z))^2) / 100, e)
  expect_equal(sum(Mod(fft_c2c(z, norm = "none"))^2) / 100, e)
  expect_equal(sum(Mod(fft_c2c(z, norm = "ortho"))^2), e)
})

test_that("real input to fft_c2c() gives a Hermitian spectrum", {
  withr::local_seed(20)
  expect_fft_batch({
    for (n in c(1, 2, 7, 8, 33)) {
      X <- fft_c2c(rnorm(n))
      k <- (n - seq_len(n) + 1) %% n + 1
      expect_fft_equal(X, Conj(X[k]), label = n)
    }
  })
  m <- matrix(rnorm(35), 5, 7)
  X <- fft_c2c(m)
  flip <- function(i, n) (n - i + 1) %% n + 1
  expect_fft_equal(X, Conj(X[flip(1:5, 5), flip(1:7, 7)]), N = 35)
})

test_that("inverse accepts fftwtools' 0 and 1", {
  z <- complex(real = 1:6, imaginary = 6:1)
  expect_identical(fft_c2c(z, 1), fft_c2c(z, TRUE))
  expect_identical(fft_c2c(z, 0), fft_c2c(z, FALSE))
})

test_that("n crops and zero-pads each transformed axis", {
  withr::local_seed(21)
  x <- rnorm(10)
  expect_fft_equal(fft_c2c(x, n = 16), stats::fft(c(x, rep(0, 6))))
  expect_fft_equal(fft_c2c(x, n = 7), stats::fft(x[1:7]))
  expect_fft_equal(fft_r2c(x, n = 16), stats::fft(c(x, rep(0, 6)))[1:9], N = 16)
  a <- array(random_complex(24), c(2, 3, 4))
  padded <- array(0i, c(4, 3, 2))
  padded[1:2, , ] <- a[,, 1:2]
  got <- fft_c2c(a, n = c(4, 2), axes = c(1, 3))
  expect_identical(dim(got), c(4L, 3L, 2L))
  expect_fft_equal(got, fft_axes_oracle(padded, c(1, 3)), N = 8)
})

test_that("fft_c2r() default length is 2 * (m - 1), and odd n is honoured", {
  x <- c(1, 4, 2, 8, 5, 7, 3)
  X <- fft_r2c(x)
  expect_length(fft_c2r(X), 6)
  expect_fft_equal(fft_c2r(X, n = 7), x)
  expect_fft_equal(fft_c2r(fft_r2c(x[1:6])), x[1:6])
})

test_that("fft_c2r() treats real input as complex", {
  expect_identical(fft_c2r(c(4, 1, 0)), fft_c2r(c(4, 1, 0) + 0i))
})

test_that("integer and logical input are converted to double", {
  expect_identical(fft_c2c(1:8), fft_c2c(as.double(1:8)))
  expect_identical(fft_r2c(c(TRUE, FALSE, TRUE)), fft_r2c(c(1, 0, 1)))
  m <- matrix(1:6, 2)
  expect_identical(dim(fft_c2c(m)), c(2L, 3L))
})

test_that("results keep dim and the dimnames of untransformed axes", {
  m <- matrix(rnorm(6), 2, 3, dimnames = list(c("a", "b"), c("x", "y", "z")))
  got <- fft_c2c(m, axes = 1)
  expect_identical(dimnames(got), list(NULL, c("x", "y", "z")))
  expect_null(dimnames(fft_c2c(m)))
  expect_identical(dim(fft_r2c(m, axes = 2)), c(2L, 2L))
  expect_identical(dimnames(fft_r2c(m, axes = 2)), list(c("a", "b"), NULL))
  v <- c(a = 1, b = 2, c = 3)
  expect_null(names(fft_c2c(v)))
  expect_null(dim(fft_c2c(v)))
})

test_that("inputs are never modified", {
  z <- complex(real = 1:8, imaginary = 8:1)
  z0 <- z + 0i
  invisible(fft_c2c(z))
  invisible(fft_c2r(z))
  expect_identical(z, z0)
  x <- as.double(1:8)
  x0 <- x + 0
  invisible(fft_r2c(x))
  invisible(fft_c2c(x, n = 12))
  expect_identical(x, x0)
})

test_that("an empty untransformed axis gives an empty result", {
  m <- matrix(numeric(0), 0, 4)
  expect_identical(dim(fft_c2c(m, axes = 2)), c(0L, 4L))
  expect_identical(dim(fft_r2c(m, axes = 2)), c(0L, 3L))
})

test_that("workers is validated and gives identical results", {
  withr::local_seed(22)
  m <- matrix(rnorm(64 * 64), 64)
  expect_identical(fft_c2c(m, workers = 2), fft_c2c(m, workers = 1))
  expect_identical(fft_c2c(m, workers = -1), fft_c2c(m))
  expect_error(fft_c2c(m, workers = 0), class = "zufft_invalid_argument")
  expect_error(fft_c2c(m, workers = 1.5), class = "zufft_invalid_argument")
  expect_error(fft_c2c(m, workers = -1e6), class = "zufft_invalid_argument")
})

test_that("bad arguments raise classed conditions", {
  z <- 1:8 + 0i
  expect_error(fft_c2c("a"), class = "zufft_invalid_argument")
  expect_error(fft_c2c(list(1)), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, inverse = NA), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, inverse = 2), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, norm = "bogus"), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, axes = 2), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, axes = integer(0)), class = "zufft_invalid_argument")
  expect_error(
    fft_c2c(matrix(z, 2), axes = c(1, 1)),
    class = "zufft_invalid_argument"
  )
  expect_error(fft_c2c(z, axes = 1.5), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, n = c(4, 4)), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, n = 2.5), class = "zufft_invalid_argument")
  expect_error(fft_c2c(z, n = 0), class = "zufft_length_error")
  expect_error(fft_c2c(numeric(0)), class = "zufft_length_error")
  expect_error(fft_r2c(z), class = "zufft_invalid_argument")
  expect_error(fft_c2r(1 + 0i), class = "zufft_length_error")
  expect_error(fft_c2c(z, n = 2^60), class = "zufft_invalid_argument")
  expect_error(
    fft_c2c(matrix(z, 2), n = c(2^31, 2^31)),
    class = "zufft_length_error"
  )
  expect_s3_class(
    tryCatch(fft_c2c("a"), error = identity),
    c("zufft_invalid_argument", "zufft_error")
  )
})
