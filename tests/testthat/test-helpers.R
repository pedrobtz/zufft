# fft_next_len(), fft_prev_len(), fft_freq(), fft_rfreq(), fft_shift(),
# fft_ishift() (design §5.1, §6.2).

largest_factor_ok <- function(n, primes) {
  for (p in primes) {
    while (n %% p == 0) {
      n <- n / p
    }
  }
  n == 1
}

test_that("fast lengths are the nearest smooth numbers, as SciPy defines them", {
  # SciPy documents next_fast_len as the smallest 11-smooth (complex) or
  # 5-smooth (real) number >= n, and prev_fast_len as the largest <= n.
  # Checked exhaustively against that definition for n in 1..10000.
  n <- 1:10000
  cs <- vapply(
    1:20000,
    largest_factor_ok,
    logical(1),
    primes = c(2, 3, 5, 7, 11)
  )
  rs <- vapply(1:20000, largest_factor_ok, logical(1), primes = c(2, 3, 5))
  smooth_c <- which(cs)
  smooth_r <- which(rs)
  next_c <- smooth_c[findInterval(n - 1, smooth_c) + 1]
  next_r <- smooth_r[findInterval(n - 1, smooth_r) + 1]
  prev_c <- smooth_c[findInterval(n, smooth_c)]
  prev_r <- smooth_r[findInterval(n, smooth_r)]
  expect_identical(fft_next_len(n), as.double(next_c))
  expect_identical(fft_next_len(n, real = TRUE), as.double(next_r))
  expect_identical(fft_prev_len(n), as.double(prev_c))
  expect_identical(fft_prev_len(n, real = TRUE), as.double(prev_r))
})

test_that("fast lengths match the values recorded in the design", {
  expect_identical(fft_next_len(c(1009, 999983)), c(1024, 1e6))
  expect_identical(fft_next_len(2^52), 2^52)
})

test_that("fast-length arguments are checked", {
  expect_error(fft_next_len(0), class = "zufft_invalid_argument")
  expect_error(fft_next_len(1.5), class = "zufft_invalid_argument")
  expect_error(fft_next_len(2^53), class = "zufft_invalid_argument")
  expect_error(fft_next_len(NA), class = "zufft_invalid_argument")
  expect_error(fft_prev_len(8, real = NA), class = "zufft_invalid_argument")
  expect_identical(fft_next_len(numeric(0)), numeric(0))
})

test_that("fft_freq() and fft_rfreq() follow SciPy's fftfreq and rfftfreq", {
  expect_identical(fft_freq(8), c(0, 1, 2, 3, -4, -3, -2, -1) / 8)
  expect_identical(fft_freq(7, d = 0.5), c(0, 1, 2, 3, -3, -2, -1) / 3.5)
  expect_identical(fft_freq(1), 0)
  expect_identical(fft_rfreq(8), (0:4) / 8)
  expect_identical(fft_rfreq(7, d = 2), (0:3) / 14)
  expect_error(fft_freq(0), class = "zufft_invalid_argument")
  expect_error(fft_freq(8, d = 0), class = "zufft_invalid_argument")
  expect_error(fft_rfreq(8, d = c(1, 2)), class = "zufft_invalid_argument")
})

test_that("fft_shift() centres the zero frequency and fft_ishift() undoes it", {
  for (n in 1:9) {
    f <- fft_freq(n)
    s <- fft_shift(f)
    expect_identical(s, sort(f), label = n)
    expect_identical(fft_ishift(s), f, label = n)
  }
  expect_identical(fft_shift(1:5), c(4L, 5L, 1L, 2L, 3L))
  expect_identical(fft_ishift(1:5), c(3L, 4L, 5L, 1L, 2L))
})

test_that("fft_shift() works on chosen axes and moves dimnames along", {
  m <- matrix(1:12, 3, 4, dimnames = list(letters[1:3], LETTERS[1:4]))
  s <- fft_shift(m)
  expect_identical(s, m[c(3, 1, 2), c(3, 4, 1, 2)])
  expect_identical(fft_shift(m, axes = 2), m[, c(3, 4, 1, 2)])
  expect_identical(fft_ishift(fft_shift(m)), m)
  v <- c(a = 1, b = 2, c = 3)
  expect_identical(names(fft_shift(v)), c("c", "a", "b"))
  expect_error(fft_shift(m, axes = 3), class = "zufft_invalid_argument")
  expect_error(fft_shift(sum), class = "zufft_invalid_argument")
})
