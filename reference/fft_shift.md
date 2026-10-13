# Shift the zero frequency to the centre

`fft_shift()` rotates each chosen dimension of `x` by `floor(n / 2)`, so
that the zero-frequency entry of a transform sits in the middle;
`fft_ishift()` undoes it. They are SciPy's `fftshift()` and
`ifftshift()`. `dim`, `dimnames` and `names` move with the values.

## Usage

``` r
fft_shift(x, axes = NULL)

fft_ishift(x, axes = NULL)
```

## Arguments

- x:

  A vector or array.

- axes:

  The dimensions to shift, 1-based. `NULL` means all of them.

## Value

`x`, rotated.

## See also

Other helpers:
[`fft_freq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md),
[`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md)

## Examples

``` r
fft_shift(fft_freq(8))
#> [1] -0.500 -0.375 -0.250 -0.125  0.000  0.125  0.250  0.375
fft_ishift(fft_shift(1:7))
#> [1] 1 2 3 4 5 6 7
```
