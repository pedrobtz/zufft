test_that("zufft_info() reports the vendored source and the build", {
  info <- zufft_info()
  expect_named(
    info,
    c(
      "ducc0_commit",
      "scipy_commit",
      "simd_backend",
      "simd_width",
      "fma",
      "threading",
      "pool_size",
      "hardware_threads",
      "complex_path",
      "fp_contract"
    )
  )
  expect_match(info$ducc0_commit, "^[0-9a-f]{40}$")
  expect_match(info$scipy_commit, "^[0-9a-f]{40}$")
  expect_true(
    info$simd_backend %in% c("ducc0", "std::experimental::simd", "none")
  )
  expect_true(info$simd_width %in% c(1L, 2L, 4L, 8L))
  expect_type(info$fma, "logical")
  expect_true(info$threading %in% c("zufft", "none"))
  expect_true(info$fp_contract %in% c("off", "fast"))
  expect_gte(info$pool_size, 1)
  expect_gte(info$hardware_threads, 1)
})

test_that("the SIMD width is the one the compiler targets by default", {
  # ducc0 picks its vector width from the target macros (simd.h): 8 doubles
  # with AVX-512F, 4 with AVX, 2 with SSE2 or NEON. CRAN's default flags
  # select SSE2 on x86-64 and NEON on arm64 (design §12.2), but a toolchain
  # may target more by default: Ubuntu 26.04's amd64v3 builds give AVX2
  # (#55). Ask R's C++17 compiler which macros it defines, with R's flags.
  skip_if_not(R.version$arch %in% c("x86_64", "aarch64", "arm64"))
  skip_if(nzchar(Sys.getenv("ZUFFT_NATIVE_BUILD")))
  expect_identical(zufft_info()$simd_width, default_simd_width())
})
