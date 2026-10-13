# zufft 0.0.0.9000

* `fft_c2c()`, `fft_r2c()` and `fft_c2r()` compute complex, real-to-complex
  and complex-to-real discrete Fourier transforms over any axes of an array,
  with SciPy's crop-or-pad `n` and `norm = "backward"`, `"ortho"`,
  `"forward"` or `"none"` (the unnormalised convention of fftwtools and
  `stats::fft()`). `workers` is accepted; every transform runs on one thread
  until the thread pool lands.
* Bundles the BSD-licensed FFT subset of ducc0 (the files and commit SciPy
  vendors) and compiles it.
* `zufft_info()` reports the vendored ducc0 and SciPy commits, the SIMD
  backend and width, fused multiply-add support, the threading mode and the
  complex path.
