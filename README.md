
<!-- README.md is generated from README.Rmd. Please edit that file -->

# zufft

<!-- badges: start -->

[![R-CMD-check](https://github.com/pedrobtz/zufft/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zufft/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zufft/main/.github/badges/coverage.svg)](https://github.com/pedrobtz/zufft/actions/workflows/coverage.yaml)
<!-- badges: end -->

zufft computes fast Fourier, cosine and sine transforms in R. It bundles
the BSD-licensed FFT code of [ducc0](https://github.com/mreineck/ducc),
the same files and commit that SciPy uses, so it needs no system FFTW
library and carries no GPL code.

- **Replaces fftwtools without FFTW.** `install.packages()` is enough,
  on every platform, and the licence is MIT.
- **Fast.** Faster than fftwtools on most of the benchmark grid and
  within 1.5 times on the rest; threads help further.
- **Familiar.** Names a fftwtools user knows (`fft_c2c()`, `fft_r2c()`,
  `fft_c2r()`), the conventions of `scipy.fft` for axes, normalisation
  and cosine and sine transforms, and drop-in replacements for
  `stats::fft()` and `stats::mvfft()`.

## Installation

You can install the development version of zufft from
[GitHub](https://github.com/pedrobtz/zufft) with:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zufft")
```

## Example

``` r
library(zufft)

x <- c(1, 4, 2, 8, 5, 7)
fft_c2c(x)                       # full complex spectrum, as stats::fft(x)
#> [1]  27+0.000000e+00i  -5+5.196152e+00i   0+4.440892e-16i -11+0.000000e+00i
#> [5]   0-4.440892e-16i  -5-5.196152e+00i
X <- fft_r2c(x)                  # the non-redundant half
fft_c2r(X, n = length(x))        # and back
#> [1] 1 4 2 8 5 7

# columns of a matrix, on two threads
m <- matrix(rnorm(4096 * 64), 4096)
spec <- fft_r2c(m, axes = 1, workers = 2)
dim(spec)
#> [1] 2049   64

# cosine and sine transforms, SciPy's definitions
fft_dct(x, norm = "ortho")
#> [1]  1.102270e+01 -4.650889e+00 -1.000000e+00  4.082483e-01  5.551115e-17
#> [6] -3.834392e+00
fft_dct(fft_dct(x), inverse = TRUE)
#> [1] 1 4 2 8 5 7

# fast lengths for zero-padding
fft_next_len(1009)
#> [1] 1024
```

## Coming from fftwtools or scipy.fft

`vignette("migrating-from-fftwtools")` maps every fftwtools function to
zufft. The one thing to remember is that zufft scales inverses by `1/n`,
as SciPy does; add `norm = "none"` for fftwtools’ (and `stats::fft()`’s)
unscaled numbers. The [scipy.fft
article](https://pedrobtz.github.io/zufft/articles/zufft-for-scipy-users.html)
covers the Python side: the definitions match, and the test suite checks
2040 cases against SciPy.

## Speed

Medians on an Apple M-series laptop, against fftwtools on Homebrew’s
FFTW, from `bench/RESULTS.md` (which also has a Linux x86-64 runner):

| Case                     | zufft, 1 thread | zufft, 2 threads | fftwtools |
|--------------------------|-----------------|------------------|-----------|
| 1-D complex 1 048 576    | 11.94 ms        | 6.98 ms          | 20.47 ms  |
| 1-D real 1 000 000       | 6.47 ms         | 3.91 ms          | 8.95 ms   |
| columns real 1024 × 1024 | 1.64 ms         | 898.6 µs         | 3.21 ms   |
| 2-D complex 2048²        | 38.19 ms        | 20.31 ms         | 123.25 ms |
| 3-D complex 128³         | 16.29 ms        | 9.20 ms          | 88.70 ms  |

zufft caches its plans, where fftwtools plans every call, and transforms
of any length run in O(n log n): a prime length of 100 003 takes 6.39 ms
here against 4.17 s for `stats::fft()`.

R stores arrays column by column, so the first axis is the contiguous
one. The real transforms halve the last axis listed, as SciPy does; for
speed, list the first axis last, as in `fft_r2c(m, axes = 2:1)`.

**A native build** is the user’s choice: CRAN’s binaries use the
portable SSE2 (x86-64) or NEON (arm64) vector width. To compile for your
own CPU, add this line to `~/.R/Makevars` and reinstall from source:

```
CXX17FLAGS += -march=native
```

`zufft_info()$simd_width` then reports the width you got.

## Licence

zufft is MIT-licensed. Its bundled ducc0 files are the “BSD-3-Clause OR
GPL-2.0-or-later” subset that SciPy vendors, used under BSD-3-Clause;
`inst/COPYRIGHTS` lists every copyright holder. No GPL-only ducc0 code
is included.
