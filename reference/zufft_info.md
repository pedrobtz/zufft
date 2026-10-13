# Information about the zufft build

Reports which ducc0 source zufft was built from and how: the vendored
commit and the SciPy commit that pins it, the SIMD backend and vector
width the compiler selected, whether the target has fused multiply-add
instructions, the threading mode, and the thread pool.

## Usage

``` r
zufft_info()
```

## Value

A named list:

- `ducc0_commit`:

  ducc0 commit of the vendored FFT subset.

- `scipy_commit`:

  SciPy commit whose vendoring script pins it.

- `simd_backend`:

  `"ducc0"`, `"std::experimental::simd"` or `"none"`.

- `simd_width`:

  Doubles per SIMD vector, `1` without SIMD.

- `fma`:

  `TRUE` if the target has fused multiply-add.

- `threading`:

  `"zufft"` when zufft supplies the thread pool, `"none"` when threads
  are compiled out.

- `pool_size`:

  Threads the pool can use now, the caller included.

- `hardware_threads`:

  Threads the hardware offers.

- `complex_path`:

  `"zero-copy"` when complex vectors are viewed in place, `"marshal"`
  when they are copied (design §12.2).

## Examples

``` r
zufft_info()$simd_width
#> [1] 2
```
