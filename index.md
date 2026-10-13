# zufft

## Overview

zufft provides fast Fourier transforms (FFTs) for R, along with discrete
cosine and sine transforms (DCTs and DSTs). It’s designed to replace
fftwtools, without the need for FFTW:

- [`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  computes the discrete Fourier transform (DFT), like
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html).
- [`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  computes the DFT of real input and returns only the non-negative
  frequency terms.
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  is its inverse.
- [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  and
  [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  compute DCTs and DSTs of types 1 to 4.
- [`fft_stats()`](https://pedrobtz.github.io/zufft/reference/fft_stats.md)
  and
  [`mvfft_stats()`](https://pedrobtz.github.io/zufft/reference/fft_stats.md)
  are drop-in replacements for
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html) and
  [`stats::mvfft()`](https://rdrr.io/r/stats/fft.html).

The names will be familiar if you’ve used fftwtools. The conventions for
axes, normalisation and the DCT and DST definitions follow `scipy.fft`.
Helpers such as
[`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md),
[`fft_freq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md)
and
[`fft_shift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md)
mirror SciPy’s `next_fast_len()`, `fftfreq()` and `fftshift()`.

zufft bundles the BSD-licensed FFT code of
[ducc0](https://github.com/mreineck/ducc), the same files and commit
that SciPy uses. This means you don’t need a system FFTW library:
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html) is
all it takes, on every platform. zufft is MIT-licensed and carries no
GPL code.

It’s also fast. With CRAN’s build, zufft is faster than fftwtools on 30
of 33 benchmark cases, and at most 1.26 times slower on the other three.
Threads help further.

## Installation

``` r

# Install zufft from CRAN:
install.packages("zufft")

# Or the development version from GitHub:
# install.packages("pak")
pak::pak("pedrobtz/zufft")
```

## Usage

``` r

library(zufft)
```

[`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
computes the full spectrum, just like
[`stats::fft()`](https://rdrr.io/r/stats/fft.html):

``` r

x <- c(1, 4, 2, 8, 5, 7)
fft_c2c(x)
#> [1]  27+0.000000e+00i  -5+5.196152e+00i   0+4.440892e-16i -11+0.000000e+00i
#> [5]   0-4.440892e-16i  -5-5.196152e+00i
```

For real input, the spectrum is Hermitian-symmetric: the
negative-frequency terms are the complex conjugates of the positive
ones.
[`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
returns only the `n %/% 2 + 1` non-negative frequency terms, and
[`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
takes you back. Give `n` to recover an odd length: by default
[`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
assumes an even one, as SciPy’s `irfft()` does:

``` r

X <- fft_r2c(x)
X
#> [1]  27+0.000000e+00i  -5+5.196152e+00i   0+4.440892e-16i -11+0.000000e+00i
fft_c2r(X, n = length(x))
#> [1] 1 4 2 8 5 7
```

Use `axes` to choose the dimensions to transform, and `workers` to
spread the work over several threads. Here we transform each column of a
matrix on two threads:

``` r

m <- matrix(rnorm(4096 * 64), 4096)
spec <- fft_r2c(m, axes = 1, workers = 2)
dim(spec)
#> [1] 2049   64
```

R stores arrays in column-major order, so the first dimension is
contiguous in memory. That’s why, with `axes = NULL`, the real
transforms halve the first dimension (to `n %/% 2 + 1`): it’s fast, and
it matches fftwtools. If you give `axes` explicitly, the last axis
listed is halved instead, as in SciPy. The results are bit-identical
whatever the number of threads.

[`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md) and
[`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
compute DCTs and DSTs with SciPy’s definitions. The default is type 2,
and the inverse takes you back to `x`:

``` r

fft_dct(x, norm = "ortho")
#> [1] 11.0227038 -4.6508890 -1.0000000  0.4082483  0.0000000 -3.8343924
fft_dct(fft_dct(x), inverse = TRUE)
#> [1] 1 4 2 8 5 7
```

Lengths with only small prime factors transform fastest.
[`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md)
returns the smallest fast length at or above `n`, so you can zero-pad
the input to it:

``` r

fft_next_len(1009)
#> [1] 1024
```

## Coming from fftwtools or scipy.fft

[`vignette("migrating-from-fftwtools")`](https://pedrobtz.github.io/zufft/articles/migrating-from-fftwtools.md)
maps every fftwtools function to its zufft equivalent. The main thing to
remember is scaling: zufft scales inverse transforms by `1/n`, as SciPy
does. Use `norm = "none"` if you want the unscaled inverse that
fftwtools and [`stats::fft()`](https://rdrr.io/r/stats/fft.html) return.

If you’re coming from Python, the [scipy.fft
article](https://pedrobtz.github.io/zufft/articles/zufft-for-scipy-users.html)
covers the other side. The definitions match, and the test suite checks
zufft against SciPy on 2040 cases.

## Speed

You don’t need a native build for zufft to keep up with fftwtools. The
table below compares the two on a Linux x86-64 runner, using one thread.
fftwtools uses Ubuntu’s FFTW, which is built with SSE2 and AVX SIMD
code. The numbers come from `bench/RESULTS.md`.

| Case | fftwtools | zufft, CRAN build | ratio | zufft native, ratio |
|----|----|----|----|----|
| 1-D complex 1 048 576 | 27.02 ms | 20.64 ms | 0.76 | 0.59 |
| 1-D real 1 000 000 | 16.50 ms | 11.77 ms | 0.71 | 0.57 |
| columns real 1024 × 1024 | 5.97 ms | 2.55 ms | 0.43 | 0.34 |
| 2-D complex 2048² | 279.85 ms | 67.76 ms | 0.24 | 0.19 |
| 3-D complex 128³ | 44.80 ms | 34.10 ms | 0.76 | 0.83 |
| 1-D complex 100 000 | 1.44 ms | 1.81 ms | 1.26 | 0.83 |

A ratio below 1 means zufft is faster. With CRAN’s portable build
(SSE2), zufft is faster on 30 of the 33 benchmark cases. It’s slower on
three: single 1-D complex transforms of about 10^5 to 10^6 points.
Unlike the columns of a matrix, a single transform can’t be split into
independent 1-D transforms. The worst of these is 1.26 times slower.
Built for the local CPU (AVX2 here, see [Native build](#native-build)),
zufft is faster on all 33. Each ratio compares runs on the same machine,
but the two builds ran on separate runners.

Where does the speed come from? Most of it comes from planning. zufft
caches its plans, while fftwtools creates a new FFTW plan (with
`FFTW_ESTIMATE`) and destroys it on every call. Threads add more
(`workers = 2`), which fftwtools doesn’t offer. And every length runs in
O(n log n), even a prime one: a prime length of 100 003 takes
milliseconds, compared with seconds for
[`stats::fft()`](https://rdrr.io/r/stats/fft.html).

On Apple silicon the gap is wider. That’s partly because Homebrew’s FFTW
has no SIMD code for double precision there: FFTW’s NEON support is
single precision only. You’ll find those numbers in `bench/RESULTS.md`
too.

## Native build

CRAN’s binaries are compiled to run on any CPU of their architecture. On
x86-64, that means SSE2, whose SIMD registers hold two doubles. If your
CPU has AVX2 or AVX-512, a build for your own machine runs faster. It
takes two steps in R:

1.  Set the environment variable `ZUFFT_CXXFLAGS` with
    [`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html). zufft adds
    it to its compiler flags, and no other package sees it.

2.  Install from source with `install.packages(..., type = "source")`. A
    prebuilt binary, which is what you get by default on macOS, is
    already compiled and ignores the variable.

``` r

Sys.setenv(ZUFFT_CXXFLAGS = "-march=native") # "-mcpu=native" on Apple silicon
install.packages("zufft", type = "source")
```

If you want the development version, clear pak’s cache first. Otherwise
pak reuses a cached build of the same commit, which ignores the
variable:

``` r

pak::cache_delete(package = "zufft")
pak::pak("pedrobtz/zufft")
```

You can check the result with
[`zufft_info()`](https://pedrobtz.github.io/zufft/reference/zufft_info.md).
The SIMD width, in doubles, is 4 with AVX2, 8 with AVX-512, and 2 for a
portable build:

``` r

zufft::zufft_info()$simd_width
```

This works on Linux and macOS. Installing from source needs a compiler
(on macOS, the Xcode command line tools). Windows builds ignore
`ZUFFT_CXXFLAGS` and stay portable, because code built for AVX by the
GCC in Rtools crashed in our tests.

How much does it help? On the Linux x86-64 runner of `bench/RESULTS.md`,
where this gives AVX2, the 16384 × 64 complex column case drops from
15.39 ms to 9.17 ms. A complex transform of prime length 10 007 drops
from 659.6 µs to 389.5 µs. On Apple silicon the SIMD width stays at two
doubles (NEON), so a native build (`-mcpu=native` there) gains little.

There are two things to keep in mind:

- The package then runs only on CPUs like yours, so don’t copy the
  installed library to other machines.

- With GCC on a CPU with fused multiply-add (FMA), results can differ in
  the last bit between thread counts. `zufft::zufft_info()$fp_contract`
  reports `"fast"` when that applies. CRAN’s builds report `"off"`.

## Licence

zufft is MIT-licensed. Its bundled ducc0 files are the “BSD-3-Clause OR
GPL-2.0-or-later” subset that SciPy vendors, used under BSD-3-Clause.
`inst/COPYRIGHTS` lists every copyright holder. No GPL-only ducc0 code
is included.

## Getting help

If you encounter a clear bug, please file an issue with a minimal
reproducible example on
[GitHub](https://github.com/pedrobtz/zufft/issues).
