# Changelog

## zufft 0.1.0

First release.

- [`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  and
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  compute complex, real-to-complex and complex-to-real discrete Fourier
  transforms over any axes of an array, with SciPy’s crop-or-pad `n` and
  `norm = "backward"`, `"ortho"`, `"forward"` or `"none"` (the
  unnormalised convention of fftwtools and
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html)).
- [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  and
  [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  compute discrete cosine and sine transforms of types 1 to 4 and their
  inverses over any axes, with SciPy’s definitions, `norm` and
  `orthogonalize`.
- [`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md)
  and
  [`fft_prev_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md)
  find fast transform lengths;
  [`fft_freq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md),
  [`fft_rfreq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md),
  [`fft_shift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md)
  and
  [`fft_ishift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md)
  are SciPy’s frequency and shift helpers.
- [`fft_stats()`](https://pedrobtz.github.io/zufft/reference/fft_stats.md)
  and
  [`mvfft_stats()`](https://pedrobtz.github.io/zufft/reference/fft_stats.md)
  are drop-in replacements for
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html) and
  [`stats::mvfft()`](https://rdrr.io/r/stats/fft.html).
- `workers` runs a transform on several threads, through zufft’s own
  lazy thread pool;
  [`fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md),
  [`with_fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md)
  and
  [`local_fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md)
  set the default. Results do not depend on the number of threads, and
  forked children
  ([`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html))
  are safe.
- A registered C table and the header `inst/include/zufft.h` let other
  packages call the transforms from C with `LinkingTo: zufft`, from any
  thread.
- [`vignette("migrating-from-fftwtools")`](https://pedrobtz.github.io/zufft/articles/migrating-from-fftwtools.md)
  maps every fftwtools function to zufft; an article covers `scipy.fft`
  users.
- Bundles the BSD-licensed FFT subset of ducc0 (the files and commit
  SciPy vendors) and compiles it.
- [`zufft_info()`](https://pedrobtz.github.io/zufft/reference/zufft_info.md)
  reports the vendored ducc0 and SciPy commits, the SIMD backend and
  width, fused multiply-add support, the threading mode and the complex
  path.
