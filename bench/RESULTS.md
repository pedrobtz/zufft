# zufft benchmarks

Measured with `tools/run-benchmarks` (design §11). Each section is one
machine, in one R session, against fftwtools on that machine's FFTW, R's
`stats::fft()` and, where installed, the `fftw` package. Medians come from
`bench::mark()` with a warm plan cache. "zufft cold" is the first call of
that shape, which builds and caches ducc0's plan; fftwtools plans with
`FFTW_ESTIMATE` and destroys the plan on every call, so its median already
includes planning. The ratio is zufft's time over fftwtools' time: below 1
means zufft is faster.

How to read the cases:

- "1-D real" compares `fft_r2c(x)` with `fftw_r2c(x, HermConj = 0)`.
- "columns" compares `axes = 1` with fftwtools' `mvfftw_*`.
- "full spectrum" compares `fft_c2c()` on real input with fftwtools'
  `HermConj = 1` output, which fftwtools completes in R code.
- "2-D real" compares `fft_r2c(x, axes = 2:1)` with
  `fftw_r2c_2d(x, HermConj = 0)`, because fftwtools halves R's first axis.

Shared CI runners are noisy, so read their ratios rather than their
absolute times.

The FFTW under fftwtools matters. Ubuntu's FFTW (the Linux sections) is
built with `--enable-sse2 --enable-avx` for double precision, so FFTW picks
AVX codelets at run time. Homebrew's FFTW on Apple silicon (the macOS
section) has no vector code for double precision: FFTW 3.3's NEON support
is single precision only, and its version string reads plain
`fftw-3.3.11`. fftwtools itself adds no compiler flags; its one option,
`fftplanopt = 1` (`FFTW_MEASURE`) for the column-wise functions, made
complex columns about three times slower and real columns about 17%
faster in a local check, because fftwtools still re-plans on every call.

## macOS arm64 (Apple M-series laptop)

- Date: 2026-10-13
- Machine: Darwin, aarch64, 8 hardware threads
- R 4.6.1; zufft 0.0.0.9000 (ducc0 64f42ba, SIMD ducc0 × 2, FMA TRUE, complex path zero-copy)
- fftwtools 0.9.11, fftw 1.0.9
- Medians from `bench::mark()` with a warm plan cache; "cold" is zufft's first call of that shape.
- Ratio is zufft time over fftwtools time: below 1 means zufft is faster.

| Case | Workers | zufft | zufft cold | fftwtools | zufft / fftwtools | fftw | stats |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1-D complex 1 024 | 1 | 12.4 µs | 429.1 µs | 15.7 µs | 0.79 | 17.3 µs | 6.4 µs |
| 1-D complex 1 024 | 2 | 13.6 µs | 315.5 µs | 12.7 µs | 1.07 | — | — |
| 1-D real 1 024 | 1 | 9.2 µs | 95.7 µs | 20.6 µs | 0.45 | — | 6.1 µs |
| 1-D real 1 024 | 2 | 12.1 µs | 42.6 µs | 20.9 µs | 0.58 | — | — |
| 1-D complex 65 536 | 1 | 637.5 µs | 903.3 µs | 934.0 µs | 0.68 | 1.00 ms | 2.16 ms |
| 1-D complex 65 536 | 2 | 416.8 µs | 503.3 µs | 928.5 µs | 0.45 | — | — |
| 1-D real 65 536 | 1 | 337.7 µs | 488.4 µs | 631.5 µs | 0.53 | — | 2.17 ms |
| 1-D real 65 536 | 2 | 269.1 µs | 330.5 µs | 637.8 µs | 0.42 | — | — |
| 1-D complex 1 048 576 | 1 | 11.94 ms | 14.38 ms | 20.47 ms | 0.58 | 23.95 ms | 57.89 ms |
| 1-D complex 1 048 576 | 2 | 6.98 ms | 7.12 ms | 19.99 ms | 0.35 | — | — |
| 1-D real 1 048 576 | 1 | 8.46 ms | 10.16 ms | 11.26 ms | 0.75 | — | 56.93 ms |
| 1-D real 1 048 576 | 2 | 5.01 ms | 5.22 ms | 11.39 ms | 0.44 | — | — |
| 1-D complex 4 194 304 | 1 | 64.96 ms | 84.22 ms | 109.05 ms | 0.60 | 129.15 ms | 311.13 ms |
| 1-D complex 4 194 304 | 2 | 32.38 ms | 31.52 ms | 94.77 ms | 0.34 | — | — |
| 1-D real 4 194 304 | 1 | 44.99 ms | 54.96 ms | 61.40 ms | 0.73 | — | 326.24 ms |
| 1-D real 4 194 304 | 2 | 26.03 ms | 28.82 ms | 58.99 ms | 0.44 | — | — |
| 1-D complex 273 375 | 1 | 2.92 ms | 4.06 ms | 4.44 ms | 0.66 | 3.97 ms | 4.52 ms |
| 1-D complex 273 375 | 2 | 1.53 ms | 1.56 ms | 4.09 ms | 0.37 | — | — |
| 1-D real 273 375 | 1 | 1.85 ms | 2.53 ms | 2.41 ms | 0.77 | — | 4.80 ms |
| 1-D real 273 375 | 2 | 1.85 ms | 1.60 ms | 2.43 ms | 0.76 | — | — |
| 1-D complex 100 000 | 1 | 1.07 ms | 1.45 ms | 1.12 ms | 0.96 | 881.5 µs | 1.20 ms |
| 1-D complex 100 000 | 2 | 612.5 µs | 683.4 µs | 996.5 µs | 0.61 | — | — |
| 1-D real 100 000 | 1 | 506.4 µs | 762.7 µs | 897.0 µs | 0.56 | — | 1.17 ms |
| 1-D real 100 000 | 2 | 362.7 µs | 501.3 µs | 897.3 µs | 0.40 | — | — |
| 1-D complex 1 000 000 | 1 | 10.37 ms | 13.76 ms | 14.17 ms | 0.73 | 18.48 ms | 20.37 ms |
| 1-D complex 1 000 000 | 2 | 5.35 ms | 5.32 ms | 14.13 ms | 0.38 | — | — |
| 1-D real 1 000 000 | 1 | 6.47 ms | 8.92 ms | 8.95 ms | 0.72 | — | 18.59 ms |
| 1-D real 1 000 000 | 2 | 3.91 ms | 5.30 ms | 8.93 ms | 0.44 | — | — |
| 1-D complex 10 007 | 1 | 343.7 µs | 689.6 µs | 594.4 µs | 0.58 | 845.1 µs | 32.41 ms |
| 1-D complex 10 007 | 2 | 303.5 µs | 359.5 µs | 594.5 µs | 0.51 | — | — |
| 1-D real 10 007 | 1 | 338.4 µs | 662.6 µs | 599.4 µs | 0.56 | — | 32.34 ms |
| 1-D real 10 007 | 2 | 310.0 µs | 349.2 µs | 599.2 µs | 0.52 | — | — |
| 1-D complex 100 003 | 1 | 6.39 ms | 7.29 ms | 7.72 ms | 0.83 | 10.27 ms | 4.17 s |
| 1-D complex 100 003 | 2 | 4.79 ms | 5.28 ms | 6.84 ms | 0.70 | — | — |
| 1-D real 100 003 | 1 | 6.68 ms | 8.48 ms | 7.68 ms | 0.87 | — | 4.12 s |
| 1-D real 100 003 | 2 | 4.98 ms | 16.23 ms | 7.65 ms | 0.65 | — | — |
| 1-D complex 1 000 003 | 1 | 101.65 ms | 119.20 ms | 101.30 ms | 1.00 | 128.29 ms | — |
| 1-D complex 1 000 003 | 2 | 77.09 ms | 77.40 ms | 93.14 ms | 0.83 | — | — |
| 1-D real 1 000 003 | 1 | 84.92 ms | 105.31 ms | 123.70 ms | 0.69 | — | — |
| 1-D real 1 000 003 | 2 | 65.90 ms | 65.01 ms | 124.69 ms | 0.53 | — | — |
| columns complex 1024 × 1024 | 1 | 3.22 ms | 12.69 ms | 6.68 ms | 0.48 | — | 5.68 ms |
| columns complex 1024 × 1024 | 2 | 1.73 ms | 1.77 ms | 6.66 ms | 0.26 | — | — |
| columns real 1024 × 1024 | 1 | 1.64 ms | 4.20 ms | 3.21 ms | 0.51 | — | 5.61 ms |
| columns real 1024 × 1024 | 2 | 898.6 µs | 901.6 µs | 3.23 ms | 0.28 | — | — |
| columns real, full spectrum 1024 × 1024 | 1 | 5.01 ms | 4.98 ms | 10.84 ms | 0.46 | — | — |
| columns real, full spectrum 1024 × 1024 | 2 | 3.24 ms | 3.39 ms | 10.81 ms | 0.30 | — | — |
| columns complex 16384 × 64 | 1 | 8.68 ms | 12.35 ms | 13.39 ms | 0.65 | — | 21.38 ms |
| columns complex 16384 × 64 | 2 | 4.55 ms | 4.59 ms | 13.39 ms | 0.34 | — | — |
| columns real 16384 × 64 | 1 | 2.93 ms | 4.52 ms | 4.30 ms | 0.68 | — | 21.51 ms |
| columns real 16384 × 64 | 2 | 1.53 ms | 1.57 ms | 4.30 ms | 0.36 | — | — |
| columns real, full spectrum 16384 × 64 | 1 | 6.14 ms | 6.11 ms | 10.43 ms | 0.59 | — | — |
| columns real, full spectrum 16384 × 64 | 2 | 3.25 ms | 3.23 ms | 10.40 ms | 0.31 | — | — |
| 2-D complex 512² | 1 | 1.22 ms | 2.04 ms | 5.85 ms | 0.21 | — | 15.46 ms |
| 2-D complex 512² | 2 | 827.7 µs | 909.0 µs | 6.40 ms | 0.13 | — | — |
| 2-D real 512² | 1 | 722.5 µs | 1.05 ms | 1.60 ms | 0.45 | — | 15.67 ms |
| 2-D real 512² | 2 | 449.2 µs | 506.2 µs | 1.59 ms | 0.28 | — | — |
| 2-D real, full spectrum 512² | 1 | 1.86 ms | 1.93 ms | 3.47 ms | 0.54 | — | — |
| 2-D real, full spectrum 512² | 2 | 1.14 ms | 1.18 ms | 3.46 ms | 0.33 | — | — |
| 2-D complex 2048² | 1 | 38.19 ms | 53.60 ms | 123.25 ms | 0.31 | — | 479.99 ms |
| 2-D complex 2048² | 2 | 20.31 ms | 20.92 ms | 118.80 ms | 0.17 | — | — |
| 2-D real 2048² | 1 | 15.33 ms | 20.97 ms | 27.88 ms | 0.55 | — | 484.38 ms |
| 2-D real 2048² | 2 | 8.19 ms | 8.09 ms | 27.11 ms | 0.30 | — | — |
| 2-D real, full spectrum 2048² | 1 | 42.42 ms | 45.40 ms | 60.86 ms | 0.70 | — | — |
| 2-D real, full spectrum 2048² | 2 | 33.12 ms | 33.73 ms | 59.75 ms | 0.55 | — | — |
| 3-D complex 128³ | 1 | 16.29 ms | 23.88 ms | 88.70 ms | 0.18 | — | 239.35 ms |
| 3-D complex 128³ | 2 | 9.20 ms | 8.97 ms | 89.32 ms | 0.10 | — | — |


## Linux x86-64 (GitHub ubuntu-latest runner, portable build)

- Date: 2026-10-13
- Machine: Linux, x86_64, 4 hardware threads
- R 4.6.1; zufft 0.0.0.9000 (ducc0 64f42ba, SIMD std::experimental::simd × 2, FMA FALSE, complex path zero-copy)
- fftwtools 0.9.11, fftw 1.0.9
- Medians from `bench::mark()` with a warm plan cache; "cold" is zufft's first call of that shape.
- Ratio is zufft time over fftwtools time: below 1 means zufft is faster.

| Case | Workers | zufft | zufft cold | fftwtools | zufft / fftwtools | fftw | stats |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1-D complex 1 024 | 1 | 19.1 µs | 416.8 µs | 36.0 µs | 0.53 | 21.0 µs | 12.4 µs |
| 1-D complex 1 024 | 2 | 25.8 µs | 292.5 µs | 20.0 µs | 1.29 | — | — |
| 1-D real 1 024 | 1 | 17.0 µs | 133.5 µs | 37.9 µs | 0.45 | — | 12.3 µs |
| 1-D real 1 024 | 2 | 22.3 µs | 101.8 µs | 36.8 µs | 0.61 | — | — |
| 1-D complex 65 536 | 1 | 1.43 ms | 1.61 ms | 2.62 ms | 0.54 | 3.17 ms | 6.04 ms |
| 1-D complex 65 536 | 2 | 742.2 µs | 1.23 ms | 2.48 ms | 0.30 | — | — |
| 1-D real 65 536 | 1 | 631.7 µs | 909.6 µs | 1.01 ms | 0.62 | — | 4.13 ms |
| 1-D real 65 536 | 2 | 456.2 µs | 809.7 µs | 1.01 ms | 0.45 | — | — |
| 1-D complex 1 048 576 | 1 | 20.64 ms | 20.89 ms | 27.02 ms | 0.76 | 27.59 ms | 131.02 ms |
| 1-D complex 1 048 576 | 2 | 10.52 ms | 11.49 ms | 26.55 ms | 0.40 | — | — |
| 1-D real 1 048 576 | 1 | 13.03 ms | 15.10 ms | 24.81 ms | 0.53 | — | 129.64 ms |
| 1-D real 1 048 576 | 2 | 8.06 ms | 11.34 ms | 24.99 ms | 0.32 | — | — |
| 1-D complex 4 194 304 | 1 | 97.22 ms | 92.93 ms | 152.06 ms | 0.64 | 139.82 ms | 608.99 ms |
| 1-D complex 4 194 304 | 2 | 55.58 ms | 59.70 ms | 153.44 ms | 0.36 | — | — |
| 1-D real 4 194 304 | 1 | 70.00 ms | 68.03 ms | 144.25 ms | 0.49 | — | 613.00 ms |
| 1-D real 4 194 304 | 2 | 42.86 ms | 45.81 ms | 150.45 ms | 0.28 | — | — |
| 1-D complex 273 375 | 1 | 5.73 ms | 6.04 ms | 9.14 ms | 0.63 | 4.71 ms | 8.04 ms |
| 1-D complex 273 375 | 2 | 2.74 ms | 3.33 ms | 9.24 ms | 0.30 | — | — |
| 1-D real 273 375 | 1 | 3.00 ms | 3.25 ms | 4.38 ms | 0.68 | — | 7.93 ms |
| 1-D real 273 375 | 2 | 3.01 ms | 3.29 ms | 4.39 ms | 0.69 | — | — |
| 1-D complex 100 000 | 1 | 1.81 ms | 2.09 ms | 1.44 ms | 1.26 | 2.59 ms | 2.27 ms |
| 1-D complex 100 000 | 2 | 1.04 ms | 1.81 ms | 1.14 ms | 0.91 | — | — |
| 1-D real 100 000 | 1 | 964.0 µs | 1.77 ms | 1.56 ms | 0.62 | — | 2.19 ms |
| 1-D real 100 000 | 2 | 652.5 µs | 1.13 ms | 1.57 ms | 0.42 | — | — |
| 1-D complex 1 000 000 | 1 | 19.55 ms | 19.74 ms | 21.15 ms | 0.92 | 19.78 ms | 30.76 ms |
| 1-D complex 1 000 000 | 2 | 10.55 ms | 11.21 ms | 20.93 ms | 0.50 | — | — |
| 1-D real 1 000 000 | 1 | 11.77 ms | 11.85 ms | 16.50 ms | 0.71 | — | 28.88 ms |
| 1-D real 1 000 000 | 2 | 7.18 ms | 7.44 ms | 16.49 ms | 0.44 | — | — |
| 1-D complex 10 007 | 1 | 659.6 µs | 1.35 ms | 812.0 µs | 0.81 | 1.11 ms | 42.99 ms |
| 1-D complex 10 007 | 2 | 541.9 µs | 1.20 ms | 936.4 µs | 0.58 | — | — |
| 1-D real 10 007 | 1 | 705.6 µs | 1.35 ms | 1.12 ms | 0.63 | — | 44.59 ms |
| 1-D real 10 007 | 2 | 498.1 µs | 968.5 µs | 1.12 ms | 0.44 | — | — |
| 1-D complex 100 003 | 1 | 12.58 ms | 13.05 ms | 11.22 ms | 1.12 | 13.30 ms | 6.93 s |
| 1-D complex 100 003 | 2 | 9.24 ms | 10.46 ms | 9.46 ms | 0.98 | — | — |
| 1-D real 100 003 | 1 | 13.17 ms | 13.28 ms | 14.30 ms | 0.92 | — | 7.07 s |
| 1-D real 100 003 | 2 | 9.76 ms | 12.91 ms | 14.11 ms | 0.69 | — | — |
| 1-D complex 1 000 003 | 1 | 157.94 ms | 160.10 ms | 144.54 ms | 1.09 | 174.12 ms | — |
| 1-D complex 1 000 003 | 2 | 119.25 ms | 121.55 ms | 146.55 ms | 0.81 | — | — |
| 1-D real 1 000 003 | 1 | 165.19 ms | 170.40 ms | 220.78 ms | 0.75 | — | — |
| 1-D real 1 000 003 | 2 | 115.47 ms | 114.20 ms | 220.67 ms | 0.52 | — | — |
| columns complex 1024 × 1024 | 1 | 6.75 ms | 6.94 ms | 11.48 ms | 0.59 | — | 11.21 ms |
| columns complex 1024 × 1024 | 2 | 3.51 ms | 3.98 ms | 11.60 ms | 0.30 | — | — |
| columns real 1024 × 1024 | 1 | 2.55 ms | 2.85 ms | 5.97 ms | 0.43 | — | 10.88 ms |
| columns real 1024 × 1024 | 2 | 1.29 ms | 2.01 ms | 5.83 ms | 0.22 | — | — |
| columns real, full spectrum 1024 × 1024 | 1 | 8.27 ms | 8.61 ms | 17.62 ms | 0.47 | — | — |
| columns real, full spectrum 1024 × 1024 | 2 | 4.48 ms | 5.62 ms | 17.38 ms | 0.26 | — | — |
| columns complex 16384 × 64 | 1 | 15.39 ms | 15.52 ms | 16.10 ms | 0.96 | — | 42.37 ms |
| columns complex 16384 × 64 | 2 | 7.94 ms | 13.65 ms | 16.13 ms | 0.49 | — | — |
| columns real 16384 × 64 | 1 | 4.87 ms | 5.29 ms | 7.51 ms | 0.65 | — | 40.54 ms |
| columns real 16384 × 64 | 2 | 2.53 ms | 3.25 ms | 7.48 ms | 0.34 | — | — |
| columns real, full spectrum 16384 × 64 | 1 | 9.23 ms | 10.53 ms | 15.62 ms | 0.59 | — | — |
| columns real, full spectrum 16384 × 64 | 2 | 4.80 ms | 5.19 ms | 15.63 ms | 0.31 | — | — |
| 2-D complex 512² | 1 | 3.14 ms | 3.64 ms | 16.18 ms | 0.19 | — | 27.69 ms |
| 2-D complex 512² | 2 | 1.67 ms | 2.31 ms | 16.15 ms | 0.10 | — | — |
| 2-D real 512² | 1 | 1.27 ms | 1.60 ms | 1.81 ms | 0.70 | — | 27.95 ms |
| 2-D real 512² | 2 | 731.6 µs | 1.06 ms | 1.79 ms | 0.41 | — | — |
| 2-D real, full spectrum 512² | 1 | 3.24 ms | 3.69 ms | 4.28 ms | 0.76 | — | — |
| 2-D real, full spectrum 512² | 2 | 1.82 ms | 2.41 ms | 4.29 ms | 0.42 | — | — |
| 2-D complex 2048² | 1 | 67.76 ms | 69.45 ms | 279.85 ms | 0.24 | — | 618.93 ms |
| 2-D complex 2048² | 2 | 35.70 ms | 46.99 ms | 291.25 ms | 0.12 | — | — |
| 2-D real 2048² | 1 | 32.29 ms | 30.66 ms | 57.05 ms | 0.57 | — | 690.69 ms |
| 2-D real 2048² | 2 | 16.30 ms | 16.90 ms | 56.24 ms | 0.29 | — | — |
| 2-D real, full spectrum 2048² | 1 | 85.77 ms | 94.37 ms | 109.88 ms | 0.78 | — | — |
| 2-D real, full spectrum 2048² | 2 | 43.77 ms | 45.37 ms | 113.54 ms | 0.39 | — | — |
| 3-D complex 128³ | 1 | 34.10 ms | 34.31 ms | 44.80 ms | 0.76 | — | 402.30 ms |
| 3-D complex 128³ | 2 | 17.91 ms | 18.58 ms | 39.71 ms | 0.45 | — | — |


## Linux x86-64 (GitHub ubuntu-latest runner, native build)

- Date: 2026-10-13
- Machine: Linux, x86_64, 4 hardware threads
- R 4.6.1; zufft 0.0.0.9000 (ducc0 64f42ba, SIMD std::experimental::simd × 4, FMA TRUE, complex path zero-copy)
- fftwtools 0.9.11, fftw 1.0.9
- Medians from `bench::mark()` with a warm plan cache; "cold" is zufft's first call of that shape.
- Ratio is zufft time over fftwtools time: below 1 means zufft is faster.

| Case | Workers | zufft | zufft cold | fftwtools | zufft / fftwtools | fftw | stats |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1-D complex 1 024 | 1 | 19.5 µs | 402.5 µs | 36.7 µs | 0.53 | 20.7 µs | 12.2 µs |
| 1-D complex 1 024 | 2 | 26.0 µs | 255.6 µs | 20.1 µs | 1.30 | — | — |
| 1-D real 1 024 | 1 | 17.2 µs | 118.0 µs | 37.8 µs | 0.46 | — | 12.2 µs |
| 1-D real 1 024 | 2 | 22.7 µs | 64.8 µs | 37.6 µs | 0.60 | — | — |
| 1-D complex 65 536 | 1 | 1.05 ms | 999.7 µs | 1.13 ms | 0.93 | 3.04 ms | 6.16 ms |
| 1-D complex 65 536 | 2 | 681.7 µs | 870.2 µs | 1.69 ms | 0.40 | — | — |
| 1-D real 65 536 | 1 | 416.2 µs | 617.0 µs | 965.6 µs | 0.43 | — | 3.64 ms |
| 1-D real 65 536 | 2 | 423.7 µs | 582.5 µs | 979.8 µs | 0.43 | — | — |
| 1-D complex 1 048 576 | 1 | 15.15 ms | 14.89 ms | 25.54 ms | 0.59 | 24.03 ms | 127.30 ms |
| 1-D complex 1 048 576 | 2 | 7.83 ms | 9.29 ms | 27.21 ms | 0.29 | — | — |
| 1-D real 1 048 576 | 1 | 9.61 ms | 11.52 ms | 27.01 ms | 0.36 | — | 94.85 ms |
| 1-D real 1 048 576 | 2 | 5.90 ms | 6.55 ms | 26.39 ms | 0.22 | — | — |
| 1-D complex 4 194 304 | 1 | 79.46 ms | 78.03 ms | 153.67 ms | 0.52 | 127.83 ms | 590.64 ms |
| 1-D complex 4 194 304 | 2 | 45.84 ms | 51.93 ms | 137.72 ms | 0.33 | — | — |
| 1-D real 4 194 304 | 1 | 55.88 ms | 56.91 ms | 147.29 ms | 0.38 | — | 595.46 ms |
| 1-D real 4 194 304 | 2 | 34.95 ms | 34.75 ms | 146.31 ms | 0.24 | — | — |
| 1-D complex 273 375 | 1 | 5.44 ms | 5.43 ms | 8.78 ms | 0.62 | 4.82 ms | 7.89 ms |
| 1-D complex 273 375 | 2 | 2.53 ms | 2.86 ms | 4.05 ms | 0.63 | — | — |
| 1-D real 273 375 | 1 | 2.25 ms | 2.53 ms | 3.94 ms | 0.57 | — | 8.61 ms |
| 1-D real 273 375 | 2 | 2.28 ms | 2.47 ms | 3.96 ms | 0.57 | — | — |
| 1-D complex 100 000 | 1 | 1.15 ms | 1.46 ms | 1.38 ms | 0.83 | 2.53 ms | 2.22 ms |
| 1-D complex 100 000 | 2 | 1.16 ms | 1.41 ms | 1.38 ms | 0.84 | — | — |
| 1-D real 100 000 | 1 | 664.1 µs | 916.7 µs | 1.52 ms | 0.44 | — | 2.20 ms |
| 1-D real 100 000 | 2 | 670.3 µs | 884.5 µs | 1.52 ms | 0.44 | — | — |
| 1-D complex 1 000 000 | 1 | 17.78 ms | 17.93 ms | 22.81 ms | 0.78 | 21.25 ms | 26.54 ms |
| 1-D complex 1 000 000 | 2 | 9.54 ms | 10.05 ms | 22.36 ms | 0.43 | — | — |
| 1-D real 1 000 000 | 1 | 9.15 ms | 10.37 ms | 16.04 ms | 0.57 | — | 26.79 ms |
| 1-D real 1 000 000 | 2 | 5.62 ms | 6.17 ms | 15.89 ms | 0.35 | — | — |
| 1-D complex 10 007 | 1 | 389.5 µs | 788.0 µs | 791.8 µs | 0.49 | 1.66 ms | 43.32 ms |
| 1-D complex 10 007 | 2 | 397.5 µs | 1.01 ms | 791.1 µs | 0.50 | — | — |
| 1-D real 10 007 | 1 | 401.4 µs | 780.3 µs | 1.12 ms | 0.36 | — | 44.68 ms |
| 1-D real 10 007 | 2 | 406.9 µs | 590.8 µs | 1.13 ms | 0.36 | — | — |
| 1-D complex 100 003 | 1 | 9.47 ms | 10.22 ms | 11.14 ms | 0.85 | 16.95 ms | 6.28 s |
| 1-D complex 100 003 | 2 | 7.52 ms | 10.15 ms | 11.09 ms | 0.68 | — | — |
| 1-D real 100 003 | 1 | 9.65 ms | 10.32 ms | 13.86 ms | 0.70 | — | 6.99 s |
| 1-D real 100 003 | 2 | 7.12 ms | 8.09 ms | 13.89 ms | 0.51 | — | — |
| 1-D complex 1 000 003 | 1 | 127.12 ms | 125.80 ms | 139.52 ms | 0.91 | 167.94 ms | — |
| 1-D complex 1 000 003 | 2 | 95.26 ms | 95.71 ms | 137.79 ms | 0.69 | — | — |
| 1-D real 1 000 003 | 1 | 129.11 ms | 133.35 ms | 197.57 ms | 0.65 | — | — |
| 1-D real 1 000 003 | 2 | 93.44 ms | 93.45 ms | 199.81 ms | 0.47 | — | — |
| columns complex 1024 × 1024 | 1 | 6.63 ms | 6.85 ms | 10.55 ms | 0.63 | — | 10.94 ms |
| columns complex 1024 × 1024 | 2 | 3.46 ms | 5.00 ms | 10.51 ms | 0.33 | — | — |
| columns real 1024 × 1024 | 1 | 1.84 ms | 2.12 ms | 5.38 ms | 0.34 | — | 10.68 ms |
| columns real 1024 × 1024 | 2 | 993.2 µs | 2.05 ms | 5.38 ms | 0.18 | — | — |
| columns real, full spectrum 1024 × 1024 | 1 | 7.52 ms | 7.30 ms | 16.67 ms | 0.45 | — | — |
| columns real, full spectrum 1024 × 1024 | 2 | 3.95 ms | 5.51 ms | 16.72 ms | 0.24 | — | — |
| columns complex 16384 × 64 | 1 | 9.17 ms | 10.72 ms | 15.31 ms | 0.60 | — | 40.84 ms |
| columns complex 16384 × 64 | 2 | 4.71 ms | 5.26 ms | 15.06 ms | 0.31 | — | — |
| columns real 16384 × 64 | 1 | 3.61 ms | 4.05 ms | 6.90 ms | 0.52 | — | 41.24 ms |
| columns real 16384 × 64 | 2 | 1.77 ms | 2.89 ms | 6.93 ms | 0.26 | — | — |
| columns real, full spectrum 16384 × 64 | 1 | 7.75 ms | 8.34 ms | 14.77 ms | 0.52 | — | — |
| columns real, full spectrum 16384 × 64 | 2 | 4.04 ms | 4.94 ms | 14.91 ms | 0.27 | — | — |
| 2-D complex 512² | 1 | 2.79 ms | 3.04 ms | 15.57 ms | 0.18 | — | 27.70 ms |
| 2-D complex 512² | 2 | 1.54 ms | 2.61 ms | 15.96 ms | 0.10 | — | — |
| 2-D real 512² | 1 | 1.21 ms | 1.41 ms | 1.71 ms | 0.71 | — | 27.63 ms |
| 2-D real 512² | 2 | 702.7 µs | 1.15 ms | 1.71 ms | 0.41 | — | — |
| 2-D real, full spectrum 512² | 1 | 2.54 ms | 2.68 ms | 4.11 ms | 0.62 | — | — |
| 2-D real, full spectrum 512² | 2 | 1.57 ms | 1.99 ms | 4.16 ms | 0.38 | — | — |
| 2-D complex 2048² | 1 | 56.32 ms | 55.66 ms | 291.85 ms | 0.19 | — | 683.50 ms |
| 2-D complex 2048² | 2 | 29.89 ms | 35.00 ms | 269.30 ms | 0.11 | — | — |
| 2-D real 2048² | 1 | 28.31 ms | 27.55 ms | 47.79 ms | 0.59 | — | 688.34 ms |
| 2-D real 2048² | 2 | 14.94 ms | 15.20 ms | 48.41 ms | 0.31 | — | — |
| 2-D real, full spectrum 2048² | 1 | 84.83 ms | 82.77 ms | 113.66 ms | 0.75 | — | — |
| 2-D real, full spectrum 2048² | 2 | 43.44 ms | 45.96 ms | 114.68 ms | 0.38 | — | — |
| 3-D complex 128³ | 1 | 33.79 ms | 32.15 ms | 40.72 ms | 0.83 | — | 397.33 ms |
| 3-D complex 128³ | 2 | 17.90 ms | 20.75 ms | 41.59 ms | 0.43 | — | — |

