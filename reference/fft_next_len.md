# Fast transform lengths

`fft_next_len()` returns the smallest length at least `n` that zufft
transforms fastest, and `fft_prev_len()` the largest at most `n`.
Padding or cropping an input to such a length with the `n` argument of
the transforms can speed them up considerably. They are SciPy's
`next_fast_len()` and `prev_fast_len()`.

## Usage

``` r
fft_next_len(n, real = FALSE)

fft_prev_len(n, real = FALSE)
```

## Arguments

- n:

  Positive whole numbers, at most 2^52.

- real:

  `TRUE` for the lengths of real transforms
  ([`fft_r2c()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_c2r()`](https://pedrobtz.github.io/zufft/reference/fft_c2c.md),
  [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md),
  [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md)).

## Value

A double vector of the same length as `n`.

## Details

Fast lengths have no prime factor above 11 for complex transforms, or
above 5 for real ones (`real = TRUE`), as in ducc0's `good_size`.

## See also

[`stats::nextn()`](https://rdrr.io/r/stats/nextn.html), R's own version
for [`stats::fft()`](https://rdrr.io/r/stats/fft.html).

Other helpers:
[`fft_freq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md),
[`fft_shift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md)

## Examples

``` r
fft_next_len(c(1009, 999983))
#> [1]    1024 1000000
fft_next_len(1009, real = TRUE)
#> [1] 1024
fft_prev_len(1009)
#> [1] 1008
```
