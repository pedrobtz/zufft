# Sample frequencies

`fft_freq()` returns the frequency of each entry of a length-`n`
transform from
[`fft_c2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md), in
cycles per unit of the sample spacing `d`:
`0, 1, ..., ceiling(n / 2) - 1, -floor(n / 2), ..., -1`, divided by
`d * n`. `fft_rfreq()` returns the frequencies of the `n %/% 2 + 1`
entries of
[`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md):
`0, 1, ..., n %/% 2`, divided by `d * n`. They are SciPy's `fftfreq()`
and `rfftfreq()`.

## Usage

``` r
fft_freq(n, d = 1)

fft_rfreq(n, d = 1)
```

## Arguments

- n:

  The transform length, a positive whole number.

- d:

  The sample spacing, a positive number.

## Value

A double vector.

## See also

Other helpers:
[`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md),
[`fft_shift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md)

## Examples

``` r
fft_freq(8)
#> [1]  0.000  0.125  0.250  0.375 -0.500 -0.375 -0.250 -0.125
fft_freq(7, d = 0.1)
#> [1]  0.000000  1.428571  2.857143  4.285714 -4.285714 -2.857143 -1.428571
fft_rfreq(8)
#> [1] 0.000 0.125 0.250 0.375 0.500
```
