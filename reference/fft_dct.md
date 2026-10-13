# Discrete cosine and sine transforms

`fft_dct()` and `fft_dst()` compute discrete cosine and sine transforms
of types 1 to 4, or their inverses, over any subset of the dimensions of
an array. The definitions, scaling and `orthogonalize` behaviour are
those of `scipy.fft.dct()`, `dctn()`, `dst()` and `dstn()`.

## Usage

``` r
fft_dct(
  x,
  type = 2L,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  orthogonalize = NULL,
  workers = NULL
)

fft_dst(
  x,
  type = 2L,
  inverse = FALSE,
  n = NULL,
  axes = NULL,
  norm = c("backward", "ortho", "forward", "none"),
  orthogonalize = NULL,
  workers = NULL
)
```

## Arguments

- x:

  A double, integer, logical or complex vector or array. Complex input
  is transformed as its real and imaginary parts separately.

- type:

  The transform type: 1, 2, 3 or 4.

- inverse:

  `TRUE` for the inverse transform.

- n:

  Transform lengths, one per transformed axis (no recycling). Each axis
  of `x` is cropped or zero-padded to its length first. `NULL` keeps the
  lengths of `x`. For
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  `n` gives the lengths of the real output; the last transformed axis of
  `x` must then hold `n %/% 2 + 1` values and is cropped or padded to
  that. Its default is `2 * (m - 1)` for an input extent `m`, which is
  always even: give `n` to recover an odd length.

- axes:

  The dimensions to transform, 1-based, without repeats. `NULL` means
  all of them, in order. For the real transforms the last listed axis is
  the one that is halved. Use `axes = 1` for a column-wise transform of
  a matrix, as [`stats::mvfft()`](https://rdrr.io/r/stats/fft.html)
  does.

- norm:

  Where the scaling goes, as in
  [`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md).
  `"ortho"` makes the transform orthonormal when `orthogonalize` is
  `TRUE`.

- orthogonalize:

  Whether to scale the first and last terms so that the `"ortho"`
  transform matrix is orthogonal. `NULL` (the default) means
  `norm == "ortho"`, as in SciPy. For complex input an explicit value is
  ignored and `norm == "ortho"` is used, as SciPy does.

- workers:

  Threads to use. `NULL` uses the session default (1). Negative values
  count back from the number of available cores: `-1` means all of them.
  Requests are capped at the available cores, and at 2 when
  `_R_CHECK_LIMIT_CORES_` is set. Until the thread pool lands, every
  transform runs on one thread whatever `workers` says.

## Value

A double vector or array (complex for complex input) of the same shape
as `x` after cropping or padding to `n`.

## Details

Unnormalised (`norm = "backward"` or `"none"` in the forward direction),
for a length `N`, `fft_dct()` computes

- type 1:
  `y[k] = x[0] + (-1)^k x[N-1] + 2 sum_{n=1}^{N-2} x[n] cos(pi k n / (N-1))`

- type 2: `y[k] = 2 sum_{n=0}^{N-1} x[n] cos(pi k (2n+1) / (2N))`

- type 3: `y[k] = x[0] + 2 sum_{n=1}^{N-1} x[n] cos(pi (2k+1) n / (2N))`

- type 4: `y[k] = 2 sum_{n=0}^{N-1} x[n] cos(pi (2k+1) (2n+1) / (4N))`

and `fft_dst()` the matching sine sums (type 1 over `N + 1`, types 2 to
4 as above with sines and indices shifted by one). Type 1 needs lengths
of at least 2 for the cosine transform.

`inverse = TRUE` computes the inverse: types 2 and 3 swap, and the
scaling moves to the other direction. With `norm = "backward"` the
inverse is scaled by `1/N`, where `N` is `2(n - 1)` for DCT-I,
`2(n + 1)` for DST-I and `2n` otherwise, per transformed axis, so that
`fft_dct(fft_dct(x), inverse = TRUE)` returns `x`.

## See also

Other transforms:
[`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md)

## Examples

``` r
x <- c(1, 2, 3, 4, 3, 2)
fft_dct(x)
#> [1]  3.000000e+01 -3.863703e+00 -6.928203e+00  1.414214e+00 -8.881784e-16
#> [6] -1.035276e+00
fft_dct(fft_dct(x), inverse = TRUE)
#> [1] 1 2 3 4 3 2
fft_dst(x, type = 4, norm = "ortho")
#> [1]  6.14884909  2.04209106 -0.84419068  0.38140113  0.40397705 -0.01403076

# an orthonormal DCT-II along the columns of a matrix
m <- matrix(rnorm(12), 4, 3)
fft_dct(m, axes = 1, norm = "ortho")
#>            [,1]        [,2]       [,3]
#> [1,] -0.4582745 -0.47284645  0.1321692
#> [2,]  1.9861091  0.09495932  0.2750818
#> [3,]  0.6602879 -0.96324089  1.0737615
#> [4,]  2.4631732  0.49518461 -1.1623026
```
