# Stage 2 spikes: the complex path (design §12.2) and the Windows threading
# go/no-go (design §12.1).

test_that("the shim's complex transform matches stats::fft()", {
  withr::local_seed(1)
  for (n in c(1:64, 97, 128, 1000, 1009)) {
    z <- complex(real = rnorm(n), imaginary = rnorm(n))
    want <- stats::fft(z)
    got <- zff_scratch_c2c(z)
    tol <- 32 * .Machine$double.eps * max(1, log2(n)) * max(1, Mod(want))
    expect_lte(max(Mod(got - want)), tol, label = paste("n =", n))
    back <- zff_scratch_c2c(got, inverse = TRUE) / n
    expect_lte(max(Mod(back - z)), tol, label = paste("round trip, n =", n))
  }
})

test_that("the shim leaves its input unchanged", {
  z <- complex(real = 1:8, imaginary = 8:1)
  z0 <- z + 0i
  zff_scratch_c2c(z)
  expect_identical(z, z0)
})

test_that("zufft_info() names the complex path", {
  expect_true(zufft_info()$complex_path %in% c("zero-copy", "marshal"))
})

test_that("short threaded regions start, synchronise and stop", {
  # Two threads at most, as on CRAN. CI runs the long version on every leg
  # (ZUFFT_STRESS) to answer the Windows go/no-go of design §12.1.
  expect_identical(zff_thread_stress(2L, 5L, 50L), 5 * 50 * 3)
})

test_that("the long thread stress loop completes", {
  skip_if(!nzchar(Sys.getenv("ZUFFT_STRESS")))
  for (nt in c(2L, 3L, 4L)) {
    expect_identical(
      zff_thread_stress(nt, 200L, 200L),
      200 * 200 * nt * (nt + 1) / 2
    )
  }
})
