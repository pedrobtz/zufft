# fft_workers(), with_fft_workers(), local_fft_workers() (design §6.5).

test_that("fft_workers() gets and sets the default and returns the old value", {
  old <- fft_workers()
  withr::defer(fft_workers(old))
  expect_identical(fft_workers(), 1L)
  expect_identical(fft_workers(3), 1L)
  expect_identical(fft_workers(), 3L)
  expect_invisible(fft_workers(-1))
  expect_identical(fft_workers(), -1L)
})

test_that("with_fft_workers() restores the old value, also on error", {
  expect_identical(with_fft_workers(2, fft_workers()), 2L)
  expect_identical(fft_workers(), 1L)
  expect_error(with_fft_workers(2, stop("boom")), "boom")
  expect_identical(fft_workers(), 1L)
})

test_that("local_fft_workers() restores the old value when the frame exits", {
  f <- function() {
    local_fft_workers(4)
    fft_workers()
  }
  expect_identical(f(), 4L)
  expect_identical(fft_workers(), 1L)
})

test_that("the default reaches the transforms and the results do not change", {
  withr::local_seed(61)
  m <- matrix(rnorm(256 * 256), 256)
  base <- fft_c2c(m, axes = 1)
  expect_identical(with_fft_workers(2, fft_c2c(m, axes = 1)), base)
  expect_identical(with_fft_workers(-1, fft_c2c(m, axes = 1)), base)
})

test_that("bad values are rejected", {
  expect_error(fft_workers(0), class = "zufft_invalid_argument")
  expect_error(fft_workers(1.5), class = "zufft_invalid_argument")
  expect_error(fft_workers("2"), class = "zufft_invalid_argument")
  expect_error(fft_workers(c(1, 2)), class = "zufft_invalid_argument")
  expect_identical(fft_workers(), 1L)
})
