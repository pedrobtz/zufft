# zufft for scipy.fft users

zufft runs the same ducc0 code as `scipy.fft`, with the same
definitions, normalisations and fast lengths, so spectra computed in R
and in Python agree to rounding. The test suite checks this against 2040
SciPy reference cases.

``` r

library(zufft)
```

## Names

| scipy.fft | zufft |
|----|----|
| `fft(x, n, axis)` | `fft_c2c(x, n = n, axes = axis + 1)` |
| `ifft` | `fft_c2c(..., inverse = TRUE)` |
| `fft2`, `fftn(x, s, axes)` | `fft_c2c(x, n = s, axes = axes + 1)` |
| `rfft`, `rfft2`, `rfftn` | `fft_r2c(x, axes = seq_along(dim(x)))` (see below) |
| `irfft`, `irfft2`, `irfftn` | `fft_c2r(x, axes = seq_along(dim(x)))` |
| `dct`, `dctn` | [`fft_dct()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md) |
| `idct`, `idctn` | `fft_dct(..., inverse = TRUE)` |
| `dst`, `dstn`, `idst`, `idstn` | [`fft_dst()`](https://pedrobtz.github.io/zufft/reference/fft_dct.md) |
| `fftfreq`, `rfftfreq` | [`fft_freq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md), [`fft_rfreq()`](https://pedrobtz.github.io/zufft/reference/fft_freq.md) |
| `fftshift`, `ifftshift` | [`fft_shift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md), [`fft_ishift()`](https://pedrobtz.github.io/zufft/reference/fft_shift.md) |
| `next_fast_len`, `prev_fast_len` | [`fft_next_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md), [`fft_prev_len()`](https://pedrobtz.github.io/zufft/reference/fft_next_len.md) |
| `get_workers`, `set_workers` | [`fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md), [`with_fft_workers()`](https://pedrobtz.github.io/zufft/reference/fft_workers.md) |

`hfft`, `ihfft`, the fast Hankel transform, the backend machinery and
`overwrite_x` are not offered.

## Axes

Axes are 1-based in R. NumPy axis `k` is R axis `k + 1`, and an array
moved between R and NumPy by reticulate keeps its shape, so the mapping
is the same for every array.

The default differs: SciPy’s 1-D functions use the last axis, while
zufft’s `axes = NULL` means every axis, as
[`stats::fft()`](https://rdrr.io/r/stats/fft.html) does. A 1-D SciPy
call on a matrix is therefore `axes = 2` here:

``` r

m <- matrix(1:6, 2)
fft_c2c(m, axes = 2)   # scipy.fft.fft(m) along the last axis
#>       [,1]         [,2]         [,3]
#> [1,]  9+0i -3+1.732051i -3-1.732051i
#> [2,] 12+0i -3+1.732051i -3-1.732051i
```

`n` takes one value per transformed axis and is never recycled; SciPy’s
rule that a short `s` selects the trailing axes does not apply.

## Normalisation

`norm` has SciPy’s three values, with the same meaning: `"backward"`
(the default) scales the inverse by `1/N`, `"forward"` the forward
transform, and `"ortho"` both by `1/sqrt(N)`. zufft adds `"none"`, which
scales neither, as FFTW and
[`stats::fft()`](https://rdrr.io/r/stats/fft.html) do.

``` r

x <- c(1, 2, 3, 4, 3, 2)
fft_dct(x, norm = "ortho")
#> [1]  6.123724e+00 -1.115355e+00 -2.000000e+00  4.082483e-01 -1.110223e-16
#> [6] -2.988585e-01
```

For the cosine and sine transforms, `orthogonalize` defaults to
`norm == "ortho"`, as in SciPy. Like SciPy, zufft ignores an explicit
`orthogonalize` for complex input.

## The halved axis

The real transforms halve one axis. SciPy halves the last axis listed,
and with `axes` given, so does zufft. With `axes = NULL`, though, zufft
halves the *first* dimension. R stores arrays column by column, so the
first dimension is the contiguous one (in NumPy it is the last), and
halving it is the fast choice, about 1.8 times faster for a large
matrix. To get `scipy.fft.rfftn()`’s layout, list the axes in order:

``` r

m <- matrix(rnorm(512 * 512), 512)
dim(fft_r2c(m))                           # halves dimension 1, the fast one
#> [1] 257 512
dim(fft_r2c(m, axes = seq_along(dim(m)))) # as rfftn(): halves dimension 2
#> [1] 512 257
```

With `axes = NULL`, `n` still lists one length per dimension, in
dimension order.
