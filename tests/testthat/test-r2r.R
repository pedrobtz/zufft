# fft_dct() and fft_dst() (design §5.1, §6.1, §6.3).

test_that("every DCT and DST type matches its defining sum", {
  withr::local_seed(41)
  expect_fft_batch({
    for (N in c(2:20, 31, 64)) {
      x <- rnorm(N)
      for (type in 1:4) {
        lab <- paste("N =", N, "type", type)
        expect_fft_equal(
          fft_dct(x, type),
          r2r_direct(x, "dct", type),
          N = 2 * N,
          label = lab
        )
        expect_fft_equal(
          fft_dst(x, type),
          r2r_direct(x, "dst", type),
          N = 2 * N,
          label = lab
        )
      }
    }
  })
  # DST-I and types 2-4 also work at length 1
  expect_fft_batch({
    for (type in 1:4) {
      expect_fft_equal(fft_dst(3, type), r2r_direct(3, "dst", type), N = 2)
    }
  })
  expect_fft_batch({
    for (type in 2:4) {
      expect_fft_equal(fft_dct(3, type), r2r_direct(3, "dct", type), N = 2)
    }
  })
})

test_that("every type and norm round-trips", {
  withr::local_seed(42)
  x <- rnorm(17)
  expect_fft_batch({
    for (type in 1:4) {
      for (norm in c("backward", "ortho", "forward")) {
        lab <- paste(type, norm)
        expect_fft_equal(
          fft_dct(fft_dct(x, type, norm = norm), type, TRUE, norm = norm),
          x,
          label = lab
        )
        expect_fft_equal(
          fft_dst(fft_dst(x, type, norm = norm), type, TRUE, norm = norm),
          x,
          label = lab
        )
      }
    }
  })
})

test_that("inverse swaps types 2 and 3 and moves the scaling", {
  withr::local_seed(43)
  x <- rnorm(12)
  N <- 2 * 12
  expect_fft_equal(fft_dct(x, 2, inverse = TRUE), fft_dct(x, 3) / N, N = N)
  expect_fft_equal(fft_dct(x, 3, inverse = TRUE), fft_dct(x, 2) / N, N = N)
  expect_fft_equal(
    fft_dst(x, 2, inverse = TRUE, norm = "forward"),
    fft_dst(x, 3),
    N = N
  )
  expect_fft_equal(
    fft_dct(x, 4, inverse = TRUE, norm = "none"),
    fft_dct(x, 4),
    N = N
  )
  expect_fft_equal(
    fft_dct(x, 1, inverse = TRUE),
    fft_dct(x, 1) / (2 * 11),
    N = N
  )
  expect_fft_equal(
    fft_dst(x, 1, inverse = TRUE),
    fft_dst(x, 1) / (2 * 13),
    N = N
  )
})

test_that("ortho transforms with orthogonalize are orthogonal matrices", {
  bad <- character(0)
  for (N in c(2, 5, 8)) {
    I <- diag(N)
    for (type in 1:4) {
      for (kind in c("dct", "dst")) {
        f <- if (kind == "dct") fft_dct else fft_dst
        M <- f(I, type, axes = 1, norm = "ortho")
        if (!isTRUE(all.equal(crossprod(M), I, tolerance = 1e-12))) {
          bad <- c(bad, paste(kind, type, N))
        }
      }
    }
  }
  expect_identical(bad, character(0))
})

test_that("orthogonalize = FALSE changes the ortho DCT-II only in its first term", {
  withr::local_seed(44)
  x <- rnorm(9)
  a <- fft_dct(x, norm = "ortho")
  b <- fft_dct(x, norm = "ortho", orthogonalize = FALSE)
  expect_equal(a[-1], b[-1])
  expect_equal(b[1], a[1] * sqrt(2))
  expect_identical(
    fft_dct(x, norm = "backward", orthogonalize = FALSE),
    fft_dct(x)
  )
})

test_that("DCT-II is the FFT of the even extension", {
  withr::local_seed(45)
  x <- rnorm(13)
  N <- 13
  V <- fft_c2c(c(x, rev(x)))[1:N]
  k <- 0:(N - 1)
  expect_fft_equal(fft_dct(x), Re(exp(-1i * pi * k / (2 * N)) * V), N = 2 * N)
})

test_that("DCT-II and DCT-III are an inverse pair", {
  withr::local_seed(46)
  x <- rnorm(10)
  expect_fft_equal(fft_dct(fft_dct(x, 2), 3) / 20, x)
  expect_fft_equal(fft_dct(fft_dct(x, 2, norm = "ortho"), 3, norm = "ortho"), x)
})

test_that("arrays transform over chosen axes", {
  withr::local_seed(47)
  a <- array(rnorm(4 * 5 * 3), c(4, 5, 3))
  got <- fft_dct(a, axes = 2)
  want <- aperm(
    apply(a, c(1, 3), function(v) r2r_direct(v, "dct", 2)),
    c(2, 1, 3)
  )
  expect_fft_equal(got, want, N = 10)
  both <- fft_dst(a, 3, axes = c(3, 1))
  step <- fft_dst(fft_dst(a, 3, axes = 1), 3, axes = 3)
  expect_fft_equal(both, step, N = 48)
  expect_identical(dim(fft_dct(a, n = c(6, 2), axes = c(1, 3))), c(6L, 5L, 2L))
})

test_that("n crops and zero-pads before the transform", {
  x <- c(1, 2, 3, 4)
  expect_fft_equal(fft_dct(x, n = 6), fft_dct(c(x, 0, 0)), N = 12)
  expect_fft_equal(fft_dst(x, n = 3), fft_dst(x[1:3]), N = 6)
})

test_that("complex input transforms real and imaginary parts", {
  withr::local_seed(48)
  z <- complex(real = rnorm(8), imaginary = rnorm(8))
  expect_fft_equal(
    fft_dct(z, 3),
    complex(real = fft_dct(Re(z), 3), imaginary = fft_dct(Im(z), 3)),
    N = 16
  )
})

test_that("for complex input an explicit orthogonalize is ignored, as in SciPy", {
  # SciPy's realtransforms.py does not pass orthogonalize to the two
  # component calls, so the effective value is norm == "ortho" (design §6.1).
  withr::local_seed(49)
  z <- complex(real = rnorm(8), imaginary = rnorm(8))
  expect_identical(
    fft_dct(z, norm = "ortho", orthogonalize = FALSE),
    fft_dct(z, norm = "ortho")
  )
  expect_identical(
    fft_dct(z, norm = "backward", orthogonalize = TRUE),
    fft_dct(z, norm = "backward")
  )
  x <- Re(z)
  expect_false(identical(
    fft_dct(x, norm = "ortho", orthogonalize = FALSE),
    fft_dct(x, norm = "ortho")
  ))
})

test_that("results keep dim and the dimnames of untransformed axes", {
  m <- matrix(1:6, 2, 3, dimnames = list(c("a", "b"), NULL))
  got <- fft_dct(m, axes = 2)
  expect_identical(dim(got), c(2L, 3L))
  expect_identical(dimnames(got), list(c("a", "b"), NULL))
  expect_type(fft_dst(1:4), "double")
})

test_that("bad arguments raise classed conditions", {
  x <- rnorm(6)
  expect_error(fft_dct(x, type = 5), class = "zufft_invalid_argument")
  expect_error(fft_dct(x, type = 1.5), class = "zufft_invalid_argument")
  expect_error(fft_dct(x, type = "2"), class = "zufft_invalid_argument")
  expect_error(fft_dct(x, orthogonalize = NA), class = "zufft_invalid_argument")
  expect_error(
    fft_dct(x, orthogonalize = "yes"),
    class = "zufft_invalid_argument"
  )
  expect_error(fft_dct(1, type = 1), class = "zufft_length_error")
  expect_error(fft_dct(x, type = 1, n = 1), class = "zufft_length_error")
  expect_error(fft_dst(x, n = 0), class = "zufft_length_error")
  expect_error(fft_dct("a"), class = "zufft_invalid_argument")
  expect_error(fft_dct(x, norm = "unitary"), class = "zufft_invalid_argument")
})
