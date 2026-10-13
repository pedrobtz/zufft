# Drop-in replacements for stats::fft() and stats::mvfft()

`fft_stats()` and `mvfft_stats()` take the same arguments, check them
the same way and return the same structure as
[`stats::fft()`](https://rdrr.io/r/stats/fft.html) and
[`stats::mvfft()`](https://rdrr.io/r/stats/fft.html): the attributes of
`z` are kept, the inverse is not scaled, and inputs of length 0 or 1
come back unchanged (as complex). The values agree to rounding. The
differences: every length runs in O(n log n) (R's code is quadratic in a
large prime factor), real input uses a real transform, and threads
follow
[`fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md).

## Usage

``` r
fft_stats(z, inverse = FALSE)

mvfft_stats(z, inverse = FALSE)
```

## Arguments

- z:

  A real or complex vector or array (`fft_stats()`), or matrix
  (`mvfft_stats()`).

- inverse:

  `TRUE` for the unnormalised inverse transform. `NA` means forward, as
  in [`stats::fft()`](https://rdrr.io/r/stats/fft.html).

## Value

A complex vector, array or matrix with the attributes of `z`.

## Details

A package moves by replacing `fft(` with `zufft::fft_stats(` and adding
zufft to `Imports`.

## Examples

``` r
x <- 1:4
fft_stats(x)
#> [1] 10+0i -2+2i -2+0i -2-2i
fft_stats(fft_stats(x), inverse = TRUE) / length(x)
#> [1] 1+0i 2+0i 3+0i 4+0i
all.equal(fft_stats(x), stats::fft(x))
#> [1] TRUE

m <- matrix(rnorm(12), 4)
all.equal(mvfft_stats(m), stats::mvfft(m))
#> [1] TRUE
```
