# The thread pool (design §6.5).

test_that("results agree with one and several threads", {
  withr::local_seed(71)
  m <- matrix(rnorm(512 * 256), 512)
  z <- matrix(random_complex(256 * 256), 256)
  a <- array(rnorm(64^3), c(64, 64, 64))
  expect_identical(
    fft_c2c(m, axes = 1, workers = 2),
    fft_c2c(m, axes = 1, workers = 1)
  )
  expect_threads_equal(fft_c2c(z, workers = 2), fft_c2c(z, workers = 1))
  expect_threads_equal(fft_r2c(m, workers = 2), fft_r2c(m, workers = 1))
  expect_threads_equal(
    fft_c2r(fft_r2c(m), n = dim(m), workers = 2),
    fft_c2r(fft_r2c(m), n = dim(m), workers = 1)
  )
  expect_identical(
    fft_dct(a, axes = c(1, 3), workers = 2),
    fft_dct(a, axes = c(1, 3), workers = 1)
  )
  expect_threads_equal(fft_dst(m, 4, workers = 2), fft_dst(m, 4, workers = 1))
})

test_that("the pool grows to the request and never beyond two cores under check", {
  skip_if(zufft_info()$hardware_threads < 2)
  m <- matrix(rnorm(256 * 256), 256)
  invisible(fft_c2c(m, axes = 1, workers = 2))
  expect_gte(zufft_info()$pool_size, 2)
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_lte(resolve_workers(-1), 2L)
  expect_lte(resolve_workers(64), 2L)
})

test_that("a session that never asks for threads starts none", {
  # In a fresh process, because other tests in this session use threads.
  rscript <- file.path(R.home("bin"), "Rscript")
  libs <- paste(.libPaths(), collapse = .Platform$path.sep)
  code <- paste(
    "suppressMessages(library(zufft))",
    "x <- fft_c2c(matrix(rnorm(256 * 256), 256), axes = 1)",
    "cat(zufft_info()$pool_size)",
    sep = "; "
  )
  out <- suppressWarnings(system2(
    rscript,
    c("-e", shQuote(code)),
    stdout = TRUE,
    stderr = FALSE,
    env = paste0("R_LIBS=", libs)
  ))
  skip_if(
    length(out) == 0 || !grepl("^[0-9]+$", out[length(out)]),
    "zufft is not installed"
  )
  expect_identical(out[length(out)], "1")
})

test_that("forked children work before and after the pool exists", {
  skip_on_os("windows")
  skip_if_not_installed("parallel")
  withr::local_seed(72)
  m <- matrix(rnorm(256 * 256), 256)
  want <- fft_c2c(m, axes = 1, workers = 1)
  run <- function() {
    parallel::mclapply(
      1:2,
      function(i) {
        r <- fft_c2c(m, axes = 1, workers = 2)
        # children leave by _exit(): join their workers first (valgrind)
        zff_release_threads()
        r
      },
      mc.cores = 2
    )
  }
  # The pool may not exist yet in this process: children build their own.
  for (r in run()) {
    expect_identical(r, want)
  }
  invisible(fft_c2c(m, axes = 1, workers = 2))
  # Now it does: children abandon the inherited one and rebuild.
  for (r in run()) {
    expect_identical(r, want)
  }
  # and the parent's pool still works after the forks
  expect_threads_equal(fft_c2c(m, axes = 1, workers = 2), want)
})

test_that("many short threaded calls complete", {
  withr::local_seed(73)
  m <- matrix(rnorm(256 * 128), 256)
  want <- fft_c2c(m, axes = 1)
  reps <- if (nzchar(Sys.getenv("ZUFFT_STRESS"))) 2000 else 50
  ok <- TRUE
  for (i in seq_len(reps)) {
    ok <- ok && identical(fft_c2c(m, axes = 1, workers = 2), want)
  }
  expect_true(ok)
})
