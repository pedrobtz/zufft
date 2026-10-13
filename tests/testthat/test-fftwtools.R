# Every row of design §5.2 that involves c2c, r2c or c2r, executed against
# fftwtools when it is installed (design §10). Skipped otherwise.

test_that("1-D rows of the fftwtools table hold", {
  skip_if_not_installed("fftwtools")
  withr::local_seed(31)
  expect_fft_batch({
    for (n in c(1, 2, 7, 8, 64, 97)) {
      x <- rnorm(n)
      z <- random_complex(n)
      h <- n %/% 2 + 1
      X <- fft_r2c(x)
      expect_fft_equal(fft_c2c(x), fftwtools::fftw(x), label = n)
      expect_fft_equal(fft_c2c(z), fftwtools::fftw(z), label = n)
      expect_fft_equal(
        fft_c2c(z, inverse = TRUE, norm = "none"),
        fftwtools::fftw(z, inverse = 1),
        label = n
      )
      expect_fft_equal(
        fft_r2c(x),
        fftwtools::fftw(x, HermConj = 0),
        N = n,
        label = n
      )
      expect_fft_equal(
        fft_c2r(X, n = n, norm = "none"),
        fftwtools::fftw(X, inverse = 1, HermConj = 0, n = n),
        N = n,
        label = n
      )
      expect_fft_equal(fft_c2c(x), fftwtools::fftw_r2c(x), label = n)
      expect_fft_equal(
        fft_r2c(x),
        fftwtools::fftw_r2c(x, HermConj = 0),
        N = n,
        label = n
      )
      expect_fft_equal(
        fft_c2r(X, n = n, norm = "none"),
        fftwtools::fftw_c2r(X, HermConj = 0, n = n),
        N = n,
        label = n
      )
      Z <- fft_c2c(x)
      expect_fft_equal(
        Re(fft_c2c(Z, inverse = TRUE, norm = "none")),
        fftwtools::fftw_c2r(Z),
        label = n
      )
      for (i in 0:1) {
        expect_fft_equal(
          fft_c2c(z, inverse = i, norm = "none"),
          fftwtools::fftw_c2c(z, inverse = i),
          label = paste(n, i)
        )
      }
    }
  })
})

test_that("column-wise rows of the fftwtools table hold", {
  skip_if_not_installed("fftwtools")
  withr::local_seed(32)
  expect_fft_batch({
    for (nr in c(6, 7)) {
      m <- matrix(rnorm(nr * 4), nr)
      mz <- matrix(random_complex(nr * 4), nr)
      expect_fft_equal(fft_c2c(m, axes = 1), fftwtools::mvfftw(m), N = nr)
      expect_fft_equal(fft_c2c(mz, axes = 1), fftwtools::mvfftw_c2c(mz), N = nr)
      M <- fft_r2c(m, axes = 1)
      expect_fft_equal(M, fftwtools::mvfftw_r2c(m, HermConj = 0), N = nr)
      expect_fft_equal(
        fft_c2r(M, n = nr, axes = 1, norm = "none"),
        fftwtools::mvfftw_c2r(M, HermConj = 0, n = nr),
        N = nr
      )
    }
  })
})

test_that("2-d, 3-d and n-d rows of the fftwtools table hold", {
  skip_if_not_installed("fftwtools")
  withr::local_seed(33)
  x <- matrix(rnorm(35), 5, 7)
  z <- matrix(random_complex(35), 5, 7)
  a <- array(rnorm(60), c(3, 4, 5))
  az <- array(random_complex(60), c(3, 4, 5))
  expect_fft_equal(fft_c2c(x), fftwtools::fftw2d(x), N = 35)
  expect_fft_equal(fft_c2c(z), fftwtools::fftw_c2c_2d(z), N = 35)
  expect_fft_equal(fft_c2c(a), fftwtools::fftw3d(a), N = 60)
  expect_fft_equal(fft_c2c(az), fftwtools::fftw_c2c_3d(az), N = 60)
  expect_fft_equal(fft_c2c(az), fftwtools::fftw_c2c_xd(az), N = 60)
  # FFTW is row-major, so fftwtools halves R's first axis.
  expect_fft_equal(
    fft_r2c(x, axes = 2:1),
    fftwtools::fftw_r2c_2d(x, HermConj = 0),
    N = 35
  )
  expect_fft_equal(
    fft_r2c(a, axes = 3:1),
    fftwtools::fftw_r2c_3d(a, HermConj = 0),
    N = 60
  )
})
