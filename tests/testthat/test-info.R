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
      "complex_path"
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
  expect_gte(info$pool_size, 1)
  expect_gte(info$hardware_threads, 1)
})

test_that("SSE2 and NEON builds use two-double vectors", {
  # CRAN's default flags select SSE2 on x86-64 and NEON on arm64 (design
  # §12.2); wider vectors appear only with user flags such as -march=native.
  skip_if_not(R.version$arch %in% c("x86_64", "aarch64", "arm64"))
  skip_if(nzchar(Sys.getenv("ZUFFT_NATIVE_BUILD")))
  expect_identical(zufft_info()$simd_width, 2L)
})
