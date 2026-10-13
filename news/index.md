# Changelog

## zufft 0.0.0.9000

- [`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  and
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  compute complex, real-to-complex and complex-to-real discrete Fourier
  transforms over any axes of an array, with SciPy’s crop-or-pad `n` and
  `norm = "backward"`, `"ortho"`, `"forward"` or `"none"` (the
  unnormalised convention of fftwtools and
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html)). `workers` is
  accepted; every transform runs on one thread until the thread pool
  lands.
- [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  and
  [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  compute discrete cosine and sine transforms of types 1 to 4 and their
  inverses over any axes, with SciPy’s definitions, `norm` and
  `orthogonalize`.
- Bundles the BSD-licensed FFT subset of ducc0 (the files and commit
  SciPy vendors) and compiles it.
- [`zufft_info()`](https://pedrobtz.github.io/zufft/reference/zufft_info.md)
  reports the vendored ducc0 and SciPy commits, the SIMD backend and
  width, fused multiply-add support, the threading mode and the complex
  path.
