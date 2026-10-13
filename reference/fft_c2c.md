# Discrete Fourier transforms

`fft_c2c()` computes the complex discrete Fourier transform of `x` or
its inverse, `fft_r2c()` the transform of real input keeping only the
non-redundant half of the last transformed axis, and `fft_c2r()` the
inverse of `fft_r2c()`, returning real values. All three work over any
subset of the dimensions of an array, in O(n log n) time for every
length.

## Usage

``` r
fft_c2c(
  x,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
)

fft_r2c(
  x,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
)

fft_c2r(
  x,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  workers = NULL
)
```

## Arguments

- x:

  A double, integer, logical or complex vector or array. Integer and
  logical values are converted to double. `fft_r2c()` needs real input;
  `fft_c2r()` treats real input as complex.

- inverse:

  `TRUE` for the inverse transform. `0` and `1` are accepted too, as in
  fftwtools.

- n:

  Transform lengths, one per transformed axis in the order of `axes` (no
  recycling); with `axes = NULL`, one per dimension, in dimension order.
  Each axis of `x` is cropped or zero-padded to its length first. `NULL`
  keeps the lengths of `x`. For `fft_c2r()`, `n` gives the lengths of
  the real output; the halved axis of `x` must then hold `n %/% 2 + 1`
  values and is cropped or padded to that. Its default is `2 * (m - 1)`
  for an input extent `m`, which is always even: give `n` to recover an
  odd length.

- axes:

  The dimensions to transform, 1-based, without repeats. `NULL` means
  all of them, in order; for `fft_r2c()` and `fft_c2r()` it means all of
  them in reverse order, so the first dimension is halved. With explicit
  `axes`, the real transforms halve the last axis listed, as SciPy does:
  `axes = seq_along(dim(x))` halves the last dimension. Use `axes = 1`
  for a column-wise transform of a matrix, as
  [`stats::mvfft()`](https://rdrr.io/r/stats/fft.html) does.

- norm:

  Where the scaling goes. `"backward"` (the default) leaves the forward
  transform unscaled and divides the inverse by `N`, the product of the
  transformed lengths; `"forward"` does the opposite; `"ortho"` divides
  both by `sqrt(N)`; `"none"` scales neither direction, as FFTW,
  fftwtools and [`stats::fft()`](https://rdrr.io/r/stats/fft.html) do.

- workers:

  Threads to use. `NULL` uses the session default (1). Negative values
  count back from the number of available cores: `-1` means all of them.
  Requests are capped at the available cores, and at 2 when
  `_R_CHECK_LIMIT_CORES_` is set. Threads split the independent 1-D
  transforms of a multi-dimensional array, so they help only arrays with
  at least 32 768 elements and more than one line. Results agree to
  rounding whatever the number of threads; they are bit-identical on
  builds without fused multiply-add (CRAN's x86-64 builds).

## Value

For `fft_c2c()` and `fft_r2c()` a complex vector or array, for
`fft_c2r()` a double one. Arrays keep their `dim`, with the transformed
extents, and the `dimnames` of axes that were not transformed; `names`
are dropped.

## Details

The conventions are those of `scipy.fft` (`fft`, `fftn`, `rfftn`,
`irfftn`): `n` crops or zero-pads each transformed axis before the
transform, and `norm` chooses where the scaling goes. They differ from
SciPy in three ways: `axes` are 1-based; `axes = NULL` means every
dimension rather than the last one; and with `axes = NULL` the real
transforms halve the *first* dimension, not the last. R stores arrays
column by column, so the first dimension is the contiguous one, and
halving it is the fast choice (about 1.8 times faster than halving the
last for a 2048 x 2048 matrix). It is also what fftwtools' 2-D and 3-D
real transforms do.

Coming from fftwtools: `fft_c2c(x)` is `fftw(x)` and `fftw_r2c(x)`,
`fft_r2c(x)` is `fftw_r2c(x, HermConj = 0)`, and an fftwtools inverse is
the zufft inverse with `norm = "none"`, because fftwtools, like
[`stats::fft()`](https://rdrr.io/r/stats/fft.html), never scales.

## See also

[`stats::fft()`](https://rdrr.io/r/stats/fft.html) for R's own complex
transform.

Other transforms:
[`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)

## Examples

``` r
x <- c(1, 2, 3, 4, 3, 2)
fft_c2c(x)
#> [1]  1.500000e+01+0i -4.000000e+00+0i -2.220446e-16+0i -1.000000e+00+0i
#> [5] -2.220446e-16+0i -4.000000e+00+0i
fft_r2c(x)
#> [1]  1.500000e+01+0i -4.000000e+00+0i -2.220446e-16+0i -1.000000e+00+0i
fft_c2r(fft_r2c(x), n = length(x))
#> [1] 1 2 3 4 3 2

# an inverse that matches fftwtools and stats::fft(inverse = TRUE)
fft_c2c(fft_c2c(x), inverse = TRUE, norm = "none") / length(x)
#> [1] 1+0i 2+0i 3+0i 4+0i 3+0i 2+0i

# columns of a matrix, and both axes
m <- matrix(rnorm(12), 4, 3)
fft_c2c(m, axes = 1)
#>                      [,1]                 [,2]                  [,3]
#> [1,] -3.587561+0.0000000i -0.2991786+0.000000i -0.4516224+0.0000000i
#> [2,]  1.037220-0.2608883i  2.4433704-1.395737i  0.3094998+0.9116875i
#> [3,] -4.087053+0.0000000i -2.1013512+0.000000i -1.1441756+0.0000000i
#> [4,]  1.037220+0.2608883i  2.4433704+1.395737i  0.3094998-0.9116875i
dim(fft_r2c(m))                 # halves the first dimension: 3 x 3
#> [1] 3 3
dim(fft_r2c(m, axes = 1:2))     # SciPy's choice, the last: 4 x 2
#> [1] 4 2
fft_c2r(fft_r2c(m), n = dim(m)) # back to m
#>              [,1]       [,2]       [,3]
#> [1,] -1.400043517  0.6215527 -0.2441996
#> [2,]  0.255317055  1.1484116 -0.2827054
#> [3,] -2.437263611 -1.8218177 -0.5536994
#> [4,] -0.005571287 -0.2473253  0.6289820
```
