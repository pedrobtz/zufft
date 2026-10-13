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

## macOS arm64 (Apple M-series laptop)

- Date: 2026-10-13
- Machine: Darwin, aarch64, 8 hardware threads
- R 4.6.1; zufft 0.0.0.9000 (ducc0 64f42ba, SIMD ducc0 × 2, FMA TRUE, complex path zero-copy)
- fftwtools 0.9.11, fftw 1.0.9
- Medians from `bench::mark()` with a warm plan cache; "cold" is zufft's first call of that shape.
- Ratio is zufft time over fftwtools time: below 1 means zufft is faster.

| Case | Workers | zufft | zufft cold | fftwtools | zufft / fftwtools | fftw | stats |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1-D complex 1 024 | 1 | 12.2 µs | 265.7 µs | 15.5 µs | 0.79 | 17.2 µs | 6.5 µs |
| 1-D real 1 024 | 1 | 9.3 µs | 95.1 µs | 19.7 µs | 0.48 | — | 6.1 µs |
| 1-D complex 65 536 | 1 | 633.7 µs | 807.5 µs | 932.9 µs | 0.68 | 853.1 µs | 2.16 ms |
| 1-D real 65 536 | 1 | 340.6 µs | 429.0 µs | 641.0 µs | 0.53 | — | 2.16 ms |
| 1-D complex 1 048 576 | 1 | 11.83 ms | 12.29 ms | 20.04 ms | 0.59 | 22.15 ms | 56.96 ms |
| 1-D real 1 048 576 | 1 | 8.80 ms | 9.06 ms | 11.26 ms | 0.78 | — | 56.84 ms |
| 1-D complex 4 194 304 | 1 | 53.93 ms | 74.74 ms | 96.88 ms | 0.56 | 221.09 ms | 318.33 ms |
| 1-D real 4 194 304 | 1 | 43.69 ms | 54.52 ms | 58.61 ms | 0.75 | — | 316.74 ms |
| 1-D complex 273 375 | 1 | 2.63 ms | 3.84 ms | 3.73 ms | 0.70 | 3.70 ms | 4.46 ms |
| 1-D real 273 375 | 1 | 1.78 ms | 2.02 ms | 2.28 ms | 0.78 | — | 4.66 ms |
| 1-D complex 100 000 | 1 | 1.01 ms | 1.39 ms | 1.07 ms | 0.95 | 915.4 µs | 1.17 ms |
| 1-D real 100 000 | 1 | 504.5 µs | 746.5 µs | 895.4 µs | 0.56 | — | 1.16 ms |
| 1-D complex 1 000 000 | 1 | 10.54 ms | 15.02 ms | 14.10 ms | 0.75 | 18.27 ms | 19.18 ms |
| 1-D real 1 000 000 | 1 | 6.36 ms | 8.86 ms | 8.90 ms | 0.71 | — | 18.41 ms |
| 1-D complex 10 007 | 1 | 345.2 µs | 682.7 µs | 602.8 µs | 0.57 | 869.8 µs | 32.36 ms |
| 1-D real 10 007 | 1 | 343.4 µs | 690.9 µs | 612.3 µs | 0.56 | — | 32.30 ms |
| 1-D complex 100 003 | 1 | 6.33 ms | 7.16 ms | 7.65 ms | 0.83 | 11.04 ms | 4.12 s |
| 1-D real 100 003 | 1 | 6.74 ms | 7.47 ms | 7.88 ms | 0.86 | — | 4.12 s |
| 1-D complex 1 000 003 | 1 | 102.31 ms | 113.35 ms | 99.85 ms | 1.02 | 128.43 ms | — |
| 1-D real 1 000 003 | 1 | 87.24 ms | 105.88 ms | 126.47 ms | 0.69 | — | — |
| columns complex 1024 × 1024 | 1 | 4.12 ms | 6.09 ms | 6.70 ms | 0.62 | — | 5.67 ms |
| columns real 1024 × 1024 | 1 | 1.67 ms | 2.65 ms | 3.22 ms | 0.52 | — | 5.71 ms |
| columns real, full spectrum 1024 × 1024 | 1 | 5.02 ms | 4.99 ms | 10.81 ms | 0.46 | — | — |
| columns complex 16384 × 64 | 1 | 8.65 ms | 11.30 ms | 13.33 ms | 0.65 | — | 21.53 ms |
| columns real 16384 × 64 | 1 | 2.93 ms | 4.48 ms | 4.28 ms | 0.68 | — | 21.50 ms |
| columns real, full spectrum 16384 × 64 | 1 | 6.11 ms | 6.28 ms | 10.35 ms | 0.59 | — | — |
| 2-D complex 512² | 1 | 1.43 ms | 1.75 ms | 6.42 ms | 0.22 | — | 15.43 ms |
| 2-D real 512² | 1 | 712.8 µs | 1.13 ms | 1.58 ms | 0.45 | — | 15.65 ms |
| 2-D real, full spectrum 512² | 1 | 1.86 ms | 1.93 ms | 3.45 ms | 0.54 | — | — |
| 2-D complex 2048² | 1 | 40.48 ms | 51.67 ms | 128.77 ms | 0.31 | — | 476.20 ms |
| 2-D real 2048² | 1 | 14.69 ms | 19.40 ms | 27.03 ms | 0.54 | — | 476.22 ms |
| 2-D real, full spectrum 2048² | 1 | 40.56 ms | 40.48 ms | 59.50 ms | 0.68 | — | — |
| 3-D complex 128³ | 1 | 16.26 ms | 22.99 ms | 87.63 ms | 0.19 | — | 235.83 ms |


## Linux x86-64 (GitHub ubuntu-latest runner)

- Date: 2026-10-13
- Machine: Linux, x86_64, 4 hardware threads
- R 4.6.1; zufft 0.0.0.9000 (ducc0 64f42ba, SIMD std::experimental::simd × 2, FMA FALSE, complex path zero-copy)
- fftwtools 0.9.11, fftw 1.0.9
- Medians from `bench::mark()` with a warm plan cache; "cold" is zufft's first call of that shape.
- Ratio is zufft time over fftwtools time: below 1 means zufft is faster.

| Case | Workers | zufft | zufft cold | fftwtools | zufft / fftwtools | fftw | stats |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1-D complex 1 024 | 1 | 10.6 µs | 311.4 µs | 22.1 µs | 0.48 | 13.4 µs | 6.5 µs |
| 1-D real 1 024 | 1 | 11.1 µs | 104.7 µs | 21.3 µs | 0.52 | — | 7.1 µs |
| 1-D complex 65 536 | 1 | 1.03 ms | 916.0 µs | 713.4 µs | 1.44 | 579.9 µs | 2.18 ms |
| 1-D real 65 536 | 1 | 397.4 µs | 521.2 µs | 558.6 µs | 0.71 | — | 2.10 ms |
| 1-D complex 1 048 576 | 1 | 13.63 ms | 13.41 ms | 19.39 ms | 0.70 | 16.97 ms | 89.14 ms |
| 1-D real 1 048 576 | 1 | 8.97 ms | 9.92 ms | 14.77 ms | 0.61 | — | 71.87 ms |
| 1-D complex 4 194 304 | 1 | 61.90 ms | 60.66 ms | 92.99 ms | 0.67 | 78.36 ms | 435.16 ms |
| 1-D real 4 194 304 | 1 | 84.31 ms | 94.47 ms | 114.38 ms | 0.74 | — | 435.48 ms |
| 1-D complex 273 375 | 1 | 3.58 ms | 4.09 ms | 6.35 ms | 0.56 | 3.64 ms | 4.48 ms |
| 1-D real 273 375 | 1 | 1.77 ms | 1.99 ms | 2.66 ms | 0.67 | — | 4.58 ms |
| 1-D complex 100 000 | 1 | 1.04 ms | 1.21 ms | 872.5 µs | 1.19 | 558.8 µs | 1.25 ms |
| 1-D real 100 000 | 1 | 541.3 µs | 760.1 µs | 912.7 µs | 0.59 | — | 1.28 ms |
| 1-D complex 1 000 000 | 1 | 12.26 ms | 12.89 ms | 12.04 ms | 1.02 | 12.43 ms | 15.48 ms |
| 1-D real 1 000 000 | 1 | 6.86 ms | 10.35 ms | 11.03 ms | 0.62 | — | 15.62 ms |
| 1-D complex 10 007 | 1 | 366.3 µs | 772.0 µs | 469.9 µs | 0.78 | 707.4 µs | 28.15 ms |
| 1-D real 10 007 | 1 | 368.6 µs | 739.3 µs | 692.6 µs | 0.53 | — | 28.26 ms |
| 1-D complex 100 003 | 1 | 7.16 ms | 7.54 ms | 6.44 ms | 1.11 | 7.63 ms | 4.47 s |
| 1-D real 100 003 | 1 | 7.13 ms | 7.96 ms | 8.68 ms | 0.82 | — | 4.34 s |
| 1-D complex 1 000 003 | 1 | 104.25 ms | 102.06 ms | 85.02 ms | 1.23 | 104.84 ms | — |
| 1-D real 1 000 003 | 1 | 96.52 ms | 102.64 ms | 132.64 ms | 0.73 | — | — |
| columns complex 1024 × 1024 | 1 | 4.09 ms | 4.56 ms | 6.56 ms | 0.62 | — | 6.26 ms |
| columns real 1024 × 1024 | 1 | 1.54 ms | 1.99 ms | 3.29 ms | 0.47 | — | 6.00 ms |
| columns real, full spectrum 1024 × 1024 | 1 | 7.02 ms | 7.54 ms | 12.86 ms | 0.55 | — | — |
| columns complex 16384 × 64 | 1 | 9.02 ms | 11.31 ms | 10.20 ms | 0.89 | — | 20.12 ms |
| columns real 16384 × 64 | 1 | 2.64 ms | 2.99 ms | 4.05 ms | 0.65 | — | 19.88 ms |
| columns real, full spectrum 16384 × 64 | 1 | 7.29 ms | 6.67 ms | 13.46 ms | 0.54 | — | — |
| 2-D complex 512² | 1 | 1.79 ms | 2.03 ms | 10.86 ms | 0.17 | — | 23.54 ms |
| 2-D real 512² | 1 | 805.7 µs | 1.07 ms | 902.3 µs | 0.89 | — | 25.20 ms |
| 2-D real, full spectrum 512² | 1 | 2.31 ms | 2.39 ms | 2.81 ms | 0.82 | — | — |
| 2-D complex 2048² | 1 | 41.25 ms | 41.36 ms | 195.94 ms | 0.21 | — | 693.38 ms |
| 2-D real 2048² | 1 | 18.37 ms | 21.24 ms | 39.02 ms | 0.47 | — | 679.24 ms |
| 2-D real, full spectrum 2048² | 1 | 106.37 ms | 106.55 ms | 127.66 ms | 0.83 | — | — |
| 3-D complex 128³ | 1 | 23.41 ms | 22.76 ms | 35.62 ms | 0.66 | — | 358.98 ms |

