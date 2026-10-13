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

