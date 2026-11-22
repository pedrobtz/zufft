# The vector width ducc0 selects for R's C++17 compiler and flags, from the
# macros that compiler predefines; skips when the compiler cannot be run.
default_simd_width <- function() {
  rcmd <- file.path(R.home("bin"), "R")
  config <- function(var) {
    out <- suppressWarnings(
      system2(rcmd, c("CMD", "config", var), stdout = TRUE, stderr = TRUE)
    )
    if (!is.null(attr(out, "status"))) "" else paste(out, collapse = " ")
  }
  cxx <- config("CXX17")
  skip_if(!nzchar(cxx), "R has no C++17 compiler configured")
  src <- withr::local_tempfile(fileext = ".cpp")
  writeLines("int x;", src)
  cmd <- paste(
    cxx, config("CXX17FLAGS"), config("CPPFLAGS"), "-dM -E", shQuote(src)
  )
  macros <- tryCatch(
    suppressWarnings(system(cmd, intern = TRUE, ignore.stderr = TRUE)),
    error = function(e) character()
  )
  skip_if(length(macros) == 0L, "could not run the C++ preprocessor")
  has <- function(m) any(startsWith(macros, paste0("#define ", m, " ")))
  if (has("__AVX512F__")) 8L else if (has("__AVX__")) 4L else 2L
}
