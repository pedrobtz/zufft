# zufft 0.0.0.9000

* Bundles the BSD-licensed FFT subset of ducc0 (the files and commit SciPy
  vendors) and compiles it; no transform is exposed yet.
* `zufft_info()` reports the vendored ducc0 and SciPy commits, the SIMD
  backend and width, fused multiply-add support and the threading mode.
