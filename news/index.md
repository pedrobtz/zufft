# Changelog

## zufft 0.0.0.9000

- Bundles the BSD-licensed FFT subset of ducc0 (the files and commit
  SciPy vendors) and compiles it; no transform is exposed yet.
- [`zufft_info()`](https://pedrobtz.github.io/zufft/reference/zufft_info.md)
  reports the vendored ducc0 and SciPy commits, the SIMD backend and
  width, fused multiply-add support and the threading mode.
