# Identities every transform must satisfy (design §10).

test_that("the transforms are linear", {
  withr::local_seed(91)
  x <- rnorm(30)
  y <- rnorm(30)
  z <- random_complex(30)
  w <- random_complex(30)
  a <- 2.5
  b <- -1.25
  expect_fft_equal(fft_c2c(a * z + b * w), a * fft_c2c(z) + b * fft_c2c(w))
  expect_fft_equal(
    fft_r2c(a * x + b * y),
    a * fft_r2c(x) + b * fft_r2c(y),
    N = 30
  )
  for (type in 1:4) {
    expect_fft_equal(
      fft_dct(a * x + b * y, type),
      a * fft_dct(x, type) + b * fft_dct(y, type),
      N = 60
    )
    expect_fft_equal(
      fft_dst(a * x + b * y, type),
      a * fft_dst(x, type) + b * fft_dst(y, type),
      N = 60
    )
  }
})

test_that("a circular shift multiplies the spectrum by a phase", {
  withr::local_seed(92)
  for (n in c(8, 15, 64)) {
    z <- random_complex(n)
    s <- 3
    shifted <- z[((seq_len(n) - 1 - s) %% n) + 1]
    k <- 0:(n - 1)
    expect_fft_equal(
      fft_c2c(shifted),
      exp(-2i * pi * k * s / n) * fft_c2c(z),
      label = n
    )
  }
})

test_that("convolution is multiplication of spectra", {
  withr::local_seed(93)
  n <- 20
  x <- rnorm(n)
  h <- rnorm(n)
  direct <- vapply(
    0:(n - 1),
    function(i) sum(x * h[((i - 0:(n - 1)) %% n) + 1]),
    numeric(1)
  )
  via <- fft_c2r(fft_r2c(x) * fft_r2c(h), n = n)
  expect_fft_equal(via, direct)
})

test_that("Parseval holds for the orthonormal DCT and DST", {
  withr::local_seed(94)
  x <- rnorm(25)
  for (type in 1:4) {
    expect_equal(sum(fft_dct(x, type, norm = "ortho")^2), sum(x^2))
    expect_equal(sum(fft_dst(x, type, norm = "ortho")^2), sum(x^2))
  }
})
