# The registered C table and inst/include/zufft.h (design §7, §10).

test_that("every status maps from its failure kind", {
  expect_identical(.Call(zff_probe_call, 0L), 0L)
  expect_identical(.Call(zff_probe_call, 4L), 4L) # bad_alloc -> ENOMEM
  expect_identical(.Call(zff_probe_call, 5L), 5L) # system_error -> ETHREAD
  expect_identical(.Call(zff_probe_call, 6L), 6L) # std::exception -> EENGINE
  expect_identical(.Call(zff_probe_call, 7L), 7L) # anything else -> EINTERNAL
})

test_that("the header ships with the package", {
  expect_true(file.exists(system.file("include", "zufft.h", package = "zufft")))
})

test_that("a consumer runs FIt-SNE's 2-d convolution through r2c and c2r", {
  zc <- local_consumer()
  withr::local_seed(81)
  n <- 16
  x <- matrix(rnorm(n * n), n)
  k <- matrix(rnorm(n * n), n)
  got <- zc$conv2d(x, k)
  # direct circular convolution
  want <- matrix(0, n, n)
  for (i in 0:(n - 1)) {
    for (j in 0:(n - 1)) {
      ii <- (i - 0:(n - 1)) %% n + 1
      jj <- (j - 0:(n - 1)) %% n + 1
      want[i + 1, j + 1] <- sum(x * k[ii, jj])
    }
  }
  expect_fft_equal(got, want, N = n * n)
  expect_identical(dim(got), c(16L, 16L))
})

test_that("a consumer runs FIt-SNE's in-place 1-d pair", {
  zc <- local_consumer()
  withr::local_seed(82)
  z <- random_complex(26)
  r <- zc$inplace_pair(z)
  expect_fft_equal(r[1:26], fft_c2c(z))
  expect_fft_equal(r[27:52], z)
})

test_that("the table keeps its contract", {
  zc <- local_consumer()
  r <- zc$contract()
  expect_identical(r[["struct_size"]], 1L)
  expect_identical(r[["abi_version"]], 1L)
  expect_identical(r[["null_data"]], 1L)
  expect_identical(r[["null_layout"]], 1L)
  expect_identical(r[["zero_extent"]], 2L)
  expect_identical(r[["bad_axis"]], 1L)
  expect_identical(r[["dup_axis"]], 1L)
  expect_identical(r[["neg_stride"]], 1L)
  expect_identical(r[["bad_type"]], 1L)
  expect_identical(r[["dct1_short"]], 2L)
  expect_identical(r[["overlap_r2c"]], 1L)
  expect_identical(r[["partial_overlap_c2c"]], 1L)
  expect_identical(r[["self_overlap"]], 1L)
  expect_identical(r[["overflow"]], 3L)
  expect_identical(r[["shape_mismatch"]], 2L)
  expect_identical(r[["message_set"]], 1L)
  expect_identical(r[["message_cleared"]], 1L)
  if (.Platform$OS.type != "windows") {
    expect_identical(r[["message_thread_local"]], 1L)
  }
  expect_identical(r[["good_size"]], 1024L)
  expect_identical(r[["good_size_zero"]], 0L)
})

test_that("concurrent callers from several threads all succeed", {
  zc <- local_consumer()
  skip_on_os("windows")
  expect_true(zc$concurrent(4, 50))
})
