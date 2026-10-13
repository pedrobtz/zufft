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

