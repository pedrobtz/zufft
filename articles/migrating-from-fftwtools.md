# Migrating from fftwtools

zufft computes the same transforms as fftwtools without the FFTW system
library, and under a permissive licence. This vignette maps every
fftwtools call to its zufft equivalent. Where fftwtools is installed,
each example also checks that both give the same values.

``` r

library(zufft)
```

## Two conventions to know

**Scaling.** fftwtools, like
[`stats::fft()`](https://rdrr.io/r/stats/fft.html), never scales: an
inverse after a forward transform multiplies by the length. zufft
follows `scipy.fft` and divides the inverse by the length by default
(`norm = "backward"`). Use `norm = "none"` to get fftwtools’ numbers
exactly.

``` r

x <- c(1, 4, 2, 8, 5, 7)
fft_c2c(fft_c2c(x), inverse = TRUE)                 # x again
#> [1] 1+0i 4+0i 2+0i 8+0i 5+0i 7+0i
fft_c2c(fft_c2c(x), inverse = TRUE, norm = "none")  # 6 * x, as fftwtools
#> [1]  6+0i 24+0i 12+0i 48+0i 30+0i 42+0i
```

**Half spectra.** fftwtools’ `HermConj = 1` (its default) returns the
full spectrum of real input, and `HermConj = 0` the non-redundant half.
In zufft that is the choice between
[`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md) and
[`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md).

``` r

fft_c2c(x)  # full spectrum, as fftw(x) and fftw_r2c(x)
#> [1]  27+0.000000i  -5+5.196152i   0+0.000000i -11+0.000000i   0+0.000000i
#> [6]  -5-5.196152i
fft_r2c(x)  # first n %/% 2 + 1 values, as fftw_r2c(x, HermConj = 0)
#> [1]  27+0.000000i  -5+5.196152i   0+0.000000i -11+0.000000i
```

To go back from a half spectrum you need the original length, because an
even and an odd length give the same half size. Both packages take it as
`n`:

``` r

X <- fft_r2c(1:7)
fft_c2r(X, n = 7, norm = "none")   # as fftw_c2r(X, HermConj = 0, n = 7)
#> [1]  7 14 21 28 35 42 49
```

## One-dimensional transforms

| fftwtools | zufft |
|----|----|
| `fftw(x)` | `fft_c2c(x)` |
| `fftw(x, inverse = 1)` | `fft_c2c(x, inverse = TRUE, norm = "none")` |
| `fftw(x, HermConj = 0)` (real `x`) | `fft_r2c(x)` |
| `fftw(X, inverse = 1, HermConj = 0, n = n)` | `fft_c2r(X, n = n, norm = "none")` |
| `fftw_r2c(x)` | `fft_c2c(x)` |
| `fftw_r2c(x, HermConj = 0)` | `fft_r2c(x)` |
| `fftw_c2r(X, HermConj = 0, n = n)` | `fft_c2r(X, n = n, norm = "none")` |
| `fftw_c2r(X)` (full spectrum) | `Re(fft_c2c(X, inverse = TRUE, norm = "none"))` |
| `fftw_c2c(x, inverse = i)` | `fft_c2c(x, inverse = i, norm = "none")` |

`inverse = 0` and `inverse = 1` work in zufft too.

``` r

z <- complex(real = rnorm(8), imaginary = rnorm(8))
all.equal(fft_c2c(z, inverse = 1, norm = "none"), fftwtools::fftw_c2c(z, inverse = 1))
#> [1] TRUE
all.equal(fft_r2c(x), fftwtools::fftw_r2c(x, HermConj = 0))
#> [1] TRUE
all.equal(fft_c2r(X, n = 7, norm = "none"), fftwtools::fftw_c2r(X, HermConj = 0, n = 7))
#> [1] TRUE
```

## Columns of a matrix

fftwtools’ `mvfftw*` functions transform each column. In zufft that is
`axes = 1`.

| fftwtools | zufft |
|----|----|
| `mvfftw(m)`, `mvfftw_c2c(m)` | `fft_c2c(m, axes = 1)` |
| `mvfftw_r2c(m, HermConj = 0)` | `fft_r2c(m, axes = 1)` |
| `mvfftw_c2r(M, HermConj = 0, n = n)` | `fft_c2r(M, n = n, axes = 1, norm = "none")` |
| `mvfftw(..., fftplanopt = 1)` | nothing to do: zufft caches its plans |

``` r

m <- matrix(rnorm(24), 6)
all.equal(fft_c2c(m, axes = 1), fftwtools::mvfftw(m))
#> [1] TRUE
M <- fft_r2c(m, axes = 1)
all.equal(fft_c2r(M, n = 6, axes = 1, norm = "none"), fftwtools::mvfftw_c2r(M, HermConj = 0, n = 6))
#> [1] TRUE
```

## Two, three and more dimensions

| fftwtools | zufft |
|----|----|
| `fftw2d(x)`, `fftw_c2c_2d(x)`, `fftw3d(x)`, `fftw_c2c_3d(x)`, `fftw_c2c_xd(x)` | `fft_c2c(x)` |
| `fftw_r2c_2d(x, HermConj = 0)` | `fft_r2c(x)` |
| `fftw_r2c_3d(x, HermConj = 0)` | `fft_r2c(x)` |

FFTW stores arrays row by row, so fftwtools’ real 2-D and 3-D transforms
halve R’s *first* dimension. zufft’s real transforms do the same by
default: in R the first dimension is the contiguous one, and halving it
is the fast choice.

``` r

x2 <- matrix(rnorm(35), 5, 7)
all.equal(fft_r2c(x2), fftwtools::fftw_r2c_2d(x2, HermConj = 0))
#> [1] TRUE
all.equal(fft_c2c(x2), fftwtools::fftw2d(x2))
#> [1] TRUE
```

## What you gain

- **No system library.** zufft compiles its bundled ducc0 code, so
  `install.packages("zufft")` is enough, everywhere.
- **No GPL.** zufft is MIT-licensed and its bundled code BSD-3, so a
  package that imports it keeps its own licence.
- **Speed.** On the benchmark grid in the package’s `bench/RESULTS.md`,
  zufft is faster than fftwtools on most cases and within 1.5 times
  everywhere, because it caches its plans while fftwtools plans on every
  call. Multi-dimensional complex transforms gain the most.
- **Threads.** `workers = 2` (or `fft_workers(2)`) splits a transform
  over threads; fftwtools has none.
- **More transforms.**
  [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  and
  [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)
  (types 1 to 4), any subset of axes, cropping and zero-padding with
  `n`, and
  [`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md)
  for fast lengths.
- **Untouched inputs.**
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)
  never modifies its input, while FFTW’s complex-to-real transform
  destroys it.
