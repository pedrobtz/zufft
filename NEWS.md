# zufft (development version)

# zufft 0.1.0

First release.

* `fft_c2c()`, `fft_r2c()` and `fft_c2r()` compute complex, real-to-complex
  and complex-to-real discrete Fourier transforms over any axes of an array,
  with SciPy's crop-or-pad `n` and `norm = "backward"`, `"ortho"`,
  `"forward"` or `"none"` (the unnormalised convention of fftwtools and
  `stats::fft()`).
* With `axes = NULL`, `fft_r2c()` and `fft_c2r()` halve the first dimension,
  the contiguous one in R, as fftwtools' 2-D and 3-D real transforms do; give
  `axes` explicitly to halve the last axis listed, as SciPy does.
* Results are bit-identical whatever the number of threads:
  `zufft_info()$fp_contract` is `"off"` for every build that cannot fuse
  multiply-adds, which includes all of CRAN's.
* `fft_dct()` and `fft_dst()` compute discrete cosine and sine transforms of
  types 1 to 4 and their inverses over any axes, with SciPy's definitions,
  `norm` and `orthogonalize`.
* `fft_next_len()` and `fft_prev_len()` find fast transform lengths;
  `fft_freq()`, `fft_rfreq()`, `fft_shift()` and `fft_ishift()` are SciPy's
  frequency and shift helpers.
* `fft_stats()` and `mvfft_stats()` are drop-in replacements for
  `stats::fft()` and `stats::mvfft()`.
* `workers` runs a transform on several threads, through zufft's own lazy
  thread pool; `fft_workers()`, `with_fft_workers()` and
  `local_fft_workers()` set the default. Results do not depend on the number
  of threads, and forked children (`parallel::mclapply()`) are safe.
* A registered C table and the header `inst/include/zufft.h` let other
  packages call the transforms from C with `LinkingTo: zufft`, from any
  thread.
* Setting the environment variable `ZUFFT_CXXFLAGS` (for example to
  `"-march=native"`) before installing from source builds zufft for the local
  CPU on Linux and macOS; see the README.
* `vignette("migrating-from-fftwtools")` maps every fftwtools function to
  zufft; an article covers `scipy.fft` users.
* Bundles the BSD-licensed FFT subset of ducc0 (the files and commit SciPy
  vendors) and compiles it.
* `zufft_info()` reports the vendored ducc0 and SciPy commits, the SIMD
  backend and width, fused multiply-add support, the threading mode and the
  complex path.
