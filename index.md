# zufft

zufft computes fast Fourier, cosine and sine transforms in R. It bundles
the BSD-licensed FFT code of [ducc0](https://github.com/mreineck/ducc),
the same files and commit that SciPy uses, so it needs no system FFTW
library and carries no GPL code.

- **Replaces fftwtools without FFTW.**
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
  is enough, on every platform, and the licence is MIT.
- **Fast.** With CRAN’s build, faster than fftwtools on 30 of 33
  benchmark cases and within 1.26 times on the rest; threads help
  further.
- **Familiar.** Names a fftwtools user knows
  ([`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)),
  the conventions of `scipy.fft` for axes, normalisation and cosine and
  sine transforms, and drop-in replacements for
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html) and
  [`stats::mvfft()`](https://rdrr.io/r/stats/fft.html).

## Installation

Install zufft from CRAN with:

``` r

install.packages("zufft")
```

or the development version from
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
#> [1] 11.0227038 -4.6508890 -1.0000000  0.4082483  0.0000000 -3.8343924
fft_dct(fft_dct(x), inverse = TRUE)
#> [1] 1 4 2 8 5 7

# fast lengths for zero-padding
fft_next_len(1009)
#> [1] 1024
```

## Coming from fftwtools or scipy.fft

[`vignette("migrating-from-fftwtools")`](https://pedrobtz.github.io/zufft/articles/migrating-from-fftwtools.md)
maps every fftwtools function to zufft. The one thing to remember is
that zufft scales inverses by `1/n`, as SciPy does; add `norm = "none"`
for fftwtools’ (and
[`stats::fft()`](https://rdrr.io/r/stats/fft.html)’s) unscaled numbers.
The [scipy.fft
article](https://pedrobtz.github.io/zufft/articles/zufft-for-scipy-users.html)
covers the Python side: the definitions match, and the test suite checks
2040 cases against SciPy.

## Speed

zufft does not need a native build to keep up with fftwtools. On a Linux
x86-64 runner, against fftwtools on Ubuntu’s FFTW (built with SSE2 and
AVX vector code), one thread, from `bench/RESULTS.md`:

| Case | fftwtools | zufft, CRAN build | ratio | zufft native, ratio |
|----|----|----|----|----|
| 1-D complex 1 048 576 | 27.02 ms | 20.64 ms | 0.76 | 0.59 |
| 1-D real 1 000 000 | 16.50 ms | 11.77 ms | 0.71 | 0.57 |
| columns real 1024 × 1024 | 5.97 ms | 2.55 ms | 0.43 | 0.34 |
| 2-D complex 2048² | 279.85 ms | 67.76 ms | 0.24 | 0.19 |
| 3-D complex 128³ | 44.80 ms | 34.10 ms | 0.76 | 0.83 |
| 1-D complex 100 000 | 1.44 ms | 1.81 ms | 1.26 | 0.83 |

A ratio below 1 means zufft is faster. With CRAN’s portable build
(SSE2), zufft is faster on 30 of the 33 benchmark cases. The three where
it is slower are single 1-D complex transforms of about 10^5 to 10^6
points that cannot be split into lines (worst 1.26 times). Built for the
local CPU (below, AVX2 here), zufft is faster on all 33. Each ratio
compares runs on the same machine; the two builds ran on separate
runners.

Most of the margin comes from planning: zufft caches its plans, while
fftwtools builds a new FFTW plan on every call. Threads add more
(`workers = 2`), which fftwtools does not offer. Transforms of any
length run in O(n log n): a prime length of 100 003 takes milliseconds,
against seconds for [`stats::fft()`](https://rdrr.io/r/stats/fft.html).

On Apple silicon the gap is wider, but partly because Homebrew’s FFTW
has no vector code for double precision there; `bench/RESULTS.md` has
those numbers too.

R stores arrays column by column, so the first dimension is the
contiguous one. With `axes = NULL` the real transforms halve that
dimension, which is fast and matches fftwtools; give `axes` explicitly
to halve the last one listed, as SciPy does. Results are bit-identical
whatever the number of threads.

## Native build

CRAN’s binaries are compiled for any CPU of their architecture, so on
x86-64 they use SSE2, two doubles per vector. On a CPU with AVX2 or
AVX-512 a build for your own machine runs faster. Set `ZUFFT_CXXFLAGS`
before installing from source; zufft adds it to its compiler flags and
nothing else:

``` r

Sys.setenv(ZUFFT_CXXFLAGS = "-march=native")
install.packages("zufft", type = "source")
# or the development version: pak::pak("pedrobtz/zufft")

zufft::zufft_info()$simd_width   # 4 with AVX2, 8 with AVX-512; 2 is portable
```

This works on Linux and macOS; installing from source needs a compiler
(on macOS, the Xcode command line tools). Windows builds ignore
`ZUFFT_CXXFLAGS` and stay portable: code built for AVX by the GCC in
Rtools crashed in our tests. On the Linux x86-64 runner of
`bench/RESULTS.md`, where this gives AVX2, the 16384 × 64 complex column
case drops from 15.39 ms to 9.17 ms and a complex prime length of 10 007
from 659.6 µs to 389.5 µs. On Apple silicon the vector width stays at
two doubles, so a native build (`-mcpu=native` there) gains little.

Two things to know:

- The package then runs only on CPUs like yours: do not copy the
  installed library to other machines.
- With GCC on a CPU with fused multiply-add, results can differ in the
  last bit between thread counts; `zufft::zufft_info()$fp_contract`
  reports `"fast"` when that applies. CRAN’s builds report `"off"`.

## Licence

zufft is MIT-licensed. Its bundled ducc0 files are the “BSD-3-Clause OR
GPL-2.0-or-later” subset that SciPy vendors, used under BSD-3-Clause;
`inst/COPYRIGHTS` lists every copyright holder. No GPL-only ducc0 code
is included.
