# Installs the fixture consumer package (tests/testthat/fixtures) into a
# temporary library and loads it. Needs zufft installed, for LinkingTo.
local_consumer <- function(env = parent.frame()) {
  skip_on_cran()
  inc <- system.file("include", "zufft.h", package = "zufft")
  skip_if(!nzchar(inc) || !file.exists(inc), "zufft is not installed")
  skip_if(
    grepl("/inst/include/zufft.h$", inc),
    "zufft is loaded from source; LinkingTo needs an installed copy"
  )
  lib <- withr::local_tempdir(.local_envir = env)
  # Build from a copy: R CMD INSTALL writes objects next to the sources.
  build <- withr::local_tempdir(.local_envir = env)
  file.copy(test_path("fixtures", "zufftconsumer"), build, recursive = TRUE)
  src <- file.path(build, "zufftconsumer")
  rcmd <- file.path(R.home("bin"), "R")
  libs <- paste(c(lib, .libPaths()), collapse = .Platform$path.sep)
  out <- suppressWarnings(system2(
    rcmd,
    c(
      "CMD",
      "INSTALL",
      "--no-test-load",
      paste0("--library=", shQuote(lib)),
      shQuote(src)
    ),
    stdout = TRUE,
    stderr = TRUE,
    env = paste0("R_LIBS=", libs)
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) {
    fail(paste(
      c("installing the fixture failed:", tail(out, 30)),
      collapse = "\n"
    ))
  }
  loadNamespace("zufftconsumer", lib.loc = lib)
  withr::defer(
    try(unloadNamespace("zufftconsumer"), silent = TRUE),
    envir = env
  )
  asNamespace("zufftconsumer")
}
