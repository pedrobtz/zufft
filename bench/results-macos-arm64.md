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

