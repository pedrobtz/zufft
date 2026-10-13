# zufft against scipy.fft fixtures (design §10): every transform and type,
# every norm, orthogonalize for real and complex input, 2-d and 3-d arrays
# over every ordered axis subset, crop and pad, odd and even c2r lengths,
# and SciPy's validation failures. tests/testthat/fixtures/scipy/MANIFEST
# names the SciPy release that produced them.

test_that("every SciPy fixture case agrees within the tolerance", {
  f <- scipy_cases()
  for (fn in c("c2c", "r2c", "c2r", "dct", "dst")) {
    rows <- f$cases[f$cases$fn == fn, , drop = FALSE]
    bad <- character(0)
    for (i in seq_len(nrow(rows))) {
      msg <- scipy_run(rows[i, ], f$data)
      if (!is.null(msg)) bad <- c(bad, paste0("case ", rows$id[i], ": ", msg))
    }
    expect_identical(bad, character(0), label = paste(fn, "failures"))
    expect_gt(nrow(rows), 0)
  }
})

test_that("the fixtures cover what design section 10 lists", {
  f <- scipy_cases()$cases
  expect_true(all(c("c2c", "r2c", "c2r", "dct", "dst") %in% f$fn))
  expect_true(all(
    c("1", "2", "3", "4") %in% f$type[f$fn == "dct" & f$error == "0"]
  ))
  expect_true(all(c("backward", "ortho", "forward") %in% f$norm))
  expect_true(any(f$orth == "FALSE" & f$in_cplx == "1"))
  expect_true(any(grepl(";.*;", f$in_dims)))
  expect_true(any(f$error == "1"))
  expect_true(all(
    1:64 %in% as.integer(f$in_dims[f$fn == "c2c" & !grepl(";", f$in_dims)])
  ))
})
