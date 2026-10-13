# fft_stats() and mvfft_stats() against stats::fft() and stats::mvfft()
# (design §5.3).

test_that("fft_stats() matches stats::fft() on vectors and arrays", {
  withr::local_seed(51)
  expect_fft_batch({
    for (n in c(2:20, 64, 97, 1000)) {
      z <- random_complex(n)
      expect_stats_equal(fft_stats(z), stats::fft(z))
      expect_stats_equal(
        fft_stats(z, inverse = TRUE),
        stats::fft(z, inverse = TRUE)
      )
      x <- rnorm(n)
      expect_stats_equal(fft_stats(x), stats::fft(x))
    }
  })
  a <- array(rnorm(60), c(3, 4, 5))
  expect_stats_equal(fft_stats(a), stats::fft(a))
  m <- matrix(random_complex(12), 3, dimnames = list(letters[1:3], NULL))
  expect_stats_equal(fft_stats(m), stats::fft(m))
})

test_that("fft_stats() keeps every attribute of z, as stats::fft() does", {
  x <- c(a = 1, b = 2, c = 3, d = 4)
  expect_stats_equal(fft_stats(x), stats::fft(x))
  t <- stats::ts(c(1, 4, 2, 8, 5, 7), frequency = 2)
  expect_stats_equal(fft_stats(t), stats::fft(t))
  y <- structure(1:6, myattr = "kept")
  expect_stats_equal(fft_stats(y), stats::fft(y))
})

test_that("inputs of length 0 and 1 come back unchanged, as complex", {
  expect_identical(fft_stats(numeric(0)), stats::fft(numeric(0)))
  expect_identical(fft_stats(3), stats::fft(3))
  expect_identical(fft_stats(2i), stats::fft(2i))
  expect_identical(fft_stats(c(a = 1L)), stats::fft(c(a = 1L)))
})

test_that("integer and logical input work, and inverse = NA is forward", {
  expect_stats_equal(fft_stats(1:8), stats::fft(1:8))
  expect_stats_equal(
    fft_stats(c(TRUE, FALSE, TRUE)),
    stats::fft(c(TRUE, FALSE, TRUE))
  )
  expect_stats_equal(
    fft_stats(1:8, inverse = NA),
    stats::fft(1:8, inverse = NA)
  )
})

test_that("non-numeric input fails as in stats::fft()", {
  expect_error(stats::fft("a"))
  expect_error(fft_stats("a"), class = "zufft_invalid_argument")
  expect_error(fft_stats(factor(c("a", "b"))), class = "zufft_invalid_argument")
  expect_error(fft_stats(list(1, 2)), class = "zufft_invalid_argument")
})

test_that("mvfft_stats() matches stats::mvfft()", {
  withr::local_seed(52)
  expect_fft_batch({
    for (nr in c(2, 7, 16)) {
      m <- matrix(random_complex(nr * 3), nr)
      expect_stats_equal(mvfft_stats(m), stats::mvfft(m))
      expect_stats_equal(
        mvfft_stats(m, inverse = TRUE),
        stats::mvfft(m, inverse = TRUE)
      )
      r <- matrix(rnorm(nr * 3), nr, dimnames = list(NULL, c("x", "y", "z")))
      expect_stats_equal(mvfft_stats(r), stats::mvfft(r))
    }
  })
  one <- matrix(1:3, 1)
  expect_identical(mvfft_stats(one), stats::mvfft(one))
  expect_error(mvfft_stats(1:4), class = "zufft_invalid_argument")
  expect_error(
    mvfft_stats(array(1:8, c(2, 2, 2))),
    class = "zufft_invalid_argument"
  )
})

test_that("stats::fft() help-page examples hold for fft_stats()", {
  x <- 1:4
  expect_stats_equal(fft_stats(x), stats::fft(x))
  expect_stats_equal(
    fft_stats(fft_stats(x), inverse = TRUE) / length(x),
    stats::fft(stats::fft(x), inverse = TRUE) / length(x)
  )
  # the help page's slow DFT and relative-difference check
  fft0 <- function(z, inverse = FALSE) {
    n <- length(z)
    if (n == 0) {
      return(z)
    }
    k <- 0:(n - 1)
    ff <- (if (inverse) 1 else -1) * 2 * pi * 1i * k / n
    vapply(1:n, function(h) sum(z * exp(ff * (h - 1))), complex(1))
  }
  relD <- function(x, y) 2 * abs(x - y) / abs(x + y)
  withr::local_seed(53)
  n <- 2^8
  z <- complex(n, rnorm(n), rnorm(n))
  expect_lt(max(relD(fft_stats(z), fft0(z))), 1e-10)
  expect_lt(
    max(relD(fft_stats(z, inverse = TRUE), fft0(z, inverse = TRUE))),
    1e-10
  )
})
