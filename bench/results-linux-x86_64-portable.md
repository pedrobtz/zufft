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

