# RFC 0026: `zufft`, a self-contained alternative to fftwtools, built on ducc0's BSD-licensed FFT

- **Status:** Proposed. Merging this file adopts the design. Stage 0 records
  the portability and build decisions in section 12 before feature work
  begins; a failed go/no-go changes this RFC before implementation
  continues.
- **Date:** 2026-10-11; revised 2026-10-13 (goals restated around
  fftwtools, API reshaped, Makevars specified, bit-for-bit promise
  withdrawn; see section 18).
- **Package:** `zufft` (repository skeleton created; no package of that name
  was present in CRAN's package index or the `github.com/cran` mirror on
  2026-10-11). Vendors the FFT subset of Martin Reinecke's ducc0 that
  SciPy vendors: every file in the subset is "BSD-3-Clause OR
  GPL-2.0-or-later", zufft elects BSD-3-Clause and takes MIT for its own
  code. Nothing else of ducc0 is ever copied in (§8).
- **Sources read.** fftwtools 0.9-11 from the `github.com/cran` mirror
  (`DESCRIPTION`, `NAMESPACE`, `R/fftwtools.R`, `src/fftwtools.c`); the
  `fftw` package's `NAMESPACE`. SciPy (`scipy/scipy`) default branch at
  `ecee36d` (2026-10-09): `subprojects/duccfft/meson.build` (version
  `0.41.1`, sources `mav.cc`, `string_utils.cc`, `threading.cc`),
  `LICENSE.md`, the 19 files under `subprojects/duccfft/ducc0/`,
  `tools/vendoring/vendor_duccfft.sh` (pins ducc commit `64f42ba`, keeps
  only files whose SPDX line reads "BSD-3-Clause OR GPL-2.0-or-later"),
  `scipy/fft/_duccfft/` (`meson.build`, `pyduccfft.cxx`, `helper.py`,
  `realtransforms.py`) and `scipy/fft/_basic_backend.py`. Upstream ducc0
  (GitHub mirror `mreineck/ducc`, branch `ducc0`) at `64f42ba`
  (2026-09-11): `LICENSE` (GPL-2), `README.md`, `pyproject.toml`
  (`0.41.1`, "GPLv2+"), `CMakeLists.txt` and `CMakeLists-C++.txt`
  (compiler flags, §12.3), `src/ducc0/infra/simd.h`,
  `src/ducc0/fft/fftnd_impl.h` (threading, vectorisation, plan cache),
  `src/ducc0/fft/fft1d_impl.h`, `src/ducc0/infra/threading.{h,cc}`,
  `src/ducc0/infra/error_handling.h`. 19 of the 73 C++ files under `src/`
  carry the dual SPDX line; the 19 files SciPy vendors are byte-identical
  to that commit, which postdates tag `ducc0_0_41_1` (`8e30567`,
  2026-04-09) and differs from it in `fft.h`, `fftnd_impl.h`, `simd.h`,
  `unity_roots.h`, `misc_utils.h` and `pswf_rokhlin.h`. R: `stats`
  sources from the `wch/r-source` trunk mirror (`src/fft.c`,
  `src/fourier.c`, `R/fft.R`, `man/fft.Rd`); `tools:::.check_packages`
  (the compilation-flags check) from the installed R 4.6.1; `etc/Makeconf`
  of that installation (macOS arm64); *Writing R Extensions* §1.2.1 and
  the CRAN Repository Policy as of 2026-10-13. FIt-SNE
  (`KlugerLab/FIt-SNE`) at `47ff14f`: `src/nbodyfft.cpp`. `zufast`'s design
  (`pedrobtz/zufast` at `ccb56d5`). In the drafting session the three
  `.cc` files and one translation unit instantiating `fft_inst_inc.h` for
  `double` compiled with GCC 13.3 under `-std=c++17 -O2 -Wall -Wextra
  -pedantic -fvisibility=hidden` with no warnings (26 s for that unit on
  one core); the shared object (782 KB unstripped, 585 KB stripped)
  imported no stdio, `abort` or `exit` symbol; results matched the
  installed SciPy 1.18.1 (which vendors `8e30567`, not `64f42ba`) bit for
  bit on the cases tried. Nothing has been built under R and nothing has
  been benchmarked; section 12 says what Stage 0 must prove and section
  11 what Stage 1 must measure.

## 1. What zufft is

`zufft` is an FFT package for R that needs no system library and carries
no GPL code. It computes discrete Fourier transforms (complex,
real-to-complex and complex-to-real) and discrete cosine and sine
transforms of types I–IV, over any chosen axes of an R array, through
the FFT code of ducc0, vendored into the package in the BSD-licensed
subset that SciPy uses as the engine of `scipy.fft`.

Its three goals, in order:

1. **Replace fftwtools without FFTW.** Today, fast FFTs in R mean binding
   the system FFTW3 library: `fftwtools`, `fftw` and `ravetools` all
   declare `SystemRequirements: fftw3` and are GPL because FFTW is
   GPL-2+. That means a system dependency to install, a licence a
   downstream package inherits, and for CRAN binaries a dependence on
   whatever FFTW the build machine had. zufft offers the same job with
   `install.packages()` alone and a permissive licence.
2. **Perform like fftwtools.** On the benchmark grid of §11, zufft is to
   be within 1.5× of fftwtools everywhere and faster on the shapes where
   ducc0's design wins (prime lengths, many simultaneous transforms,
   threads). "Similar", not "faster everywhere": ducc0's own README says
   its 1-D transforms are "somewhat slower than those provided by FFTW
   (if FFTW's plan generation overhead is ignored)" and its multi-D
   double-precision transforms "perform fairly similar to FFTW with
   FFTW_MEASURE". fftwtools does not ignore planning: it plans with
   `FFTW_ESTIMATE` and destroys the plan on every call (§3).
3. **An API that is easy, familiar, and consistent.** Function names and
   argument names a fftwtools user recognises (`_c2c`, `_r2c`, `_c2r`,
   `inverse`, `n`), with the conventions of `scipy.fft` for everything
   fftwtools does not have (axes, `norm`, DCT/DST, `workers`, length
   helpers). Section 5 gives the surface and the two migration tables.

Why ducc0 and not R's own code: `stats::fft()` and `mvfft()` are a C
translation of Richard Singleton's 1979 mixed-radix routine. They are
complex-only, so a real series costs a full complex transform; they have
no DCT or DST; a prime length is quadratic and R's help warns it "may
take a long time"; they run on one thread; they transform all dimensions
of an array or the columns of a matrix, nothing in between; and "Long
vectors are not supported". ducc0's FFT handles any length in O(n log n)
(Bluestein passes for large prime factors), has true real transforms,
DCT/DST I–IV, arbitrary axes, strided input, SIMD across simultaneous
1-D transforms, an internal plan cache, and a thread pool.

Users: anyone who today installs libfftw3 to get `fftwtools`; signal and
image work on real data; people who validate a model across R and Python
and need spectra, filters or DCT features to agree with `scipy.fft`; and
family packages that need FFT convolutions from C, first `zutsne` (§3).

The compatibility statement that governs the decisions below:

> **The API follows `scipy.fft`'s conventions (axes, lengths, `norm`,
> transform types, fast-length rules) and its results agree with
> `scipy.fft` within the stated tolerance (§10) on every supported
> platform. The vendored source is exactly the ducc0 subset at the commit
> SciPy pins, so the two share one algorithm; bit-for-bit equality is not
> promised, because zufft is compiled with ducc0's own floating-point
> flags and the platform's SIMD width (§12.3), both of which change
> rounding.**

The previous revision promised bit-for-bit agreement with a locked
reference build. That promise conflicts with goal 2: fused multiply-add
contraction and vector width are exactly what the performance flags
change. It is withdrawn (D14).

## 2. Scope

**In v0.1.0:**

- Complex-to-complex, real-to-complex and complex-to-real transforms over
  any subset of an array's axes, forward and inverse, with crop or
  zero-pad lengths per axis.
- DCT and DST types I–IV and their inverses, with `orthogonalize` as in
  SciPy.
- `norm = "backward"`, `"ortho"` or `"forward"` with SciPy's meaning, and
  `norm = "none"` for FFTW's and `stats::fft()`'s unnormalised
  convention (D12).
- `workers`: threads per call, default one; `fft_workers()`,
  `with_fft_workers()`, `local_fft_workers()`.
- `fft_next_len()` and `fft_prev_len()` (ducc0's `good_size`, SciPy's
  `next_fast_len` and `prev_fast_len`), frequency and shift helpers.
- `fft_stats()` and `mvfft_stats()`: drop-in replacements for
  `stats::fft()` and `mvfft()` (§5.3).
- A registered C table and a C header for `LinkingTo` (§7).
- A "Migrating from fftwtools" vignette built from the table in §5.2.

**Later, when asked:**

- Long vectors as a promise. The code carries every length as `size_t`
  and no `int` sits in between (§6.2), but the release gate of §10 needs a
  runner with about 50 GB that Stage 8 did not have, so v0.1.0 does not
  claim them (Stage 8, 2026-10-13).
- Hermitian transforms (`hfft`, `ihfft`) and the Hartley transforms
  already in the vendored subset (`r2r_genuine_hartley` and siblings).
- Single precision in the C table, for consumers that want it.
- ducc0's `convolve_axis` (FFT-based resampling along an axis).
- Plan or workspace objects, if profiling shows the internal cache (ten
  entries per plan type, plans above 2^20 bytes never cached) is not
  enough.
- A run-time SIMD dispatch build for x86-64 (§12.3, open question 3).

**Never:**

- ducc0's non-uniform FFT, spherical harmonics or gridders: those files are
  GPL-2.0-or-later only and are not in the subset.
- Long double: R has no long double vectors.
- Spectral estimation, windows and filter design: `stats::spectrum()`,
  `gsignal` and others do these on top of an FFT.
- GPU transforms.
- FFTW itself, as a dependency or as an optional backend.

## 3. Position among R's FFT packages and in the `zu*` family

### 3.1 fftwtools, as the thing to replace

fftwtools 0.9-11 (GPL >= 2, published 2021-03-01, `SystemRequirements:
fftw3 (libfftw3-dev (deb), or fftw-devel (rpm))`) exports fifteen
functions:

| Family | Functions | Arguments |
| --- | --- | --- |
| 1-D | `fftw`, `fftw_r2c`, `fftw_c2r`, `fftw_c2c` | `data, inverse = 0, HermConj = 1, n = NULL` |
| columns | `mvfftw`, `mvfftw_r2c`, `mvfftw_c2r`, `mvfftw_c2c` | as 1-D plus `fftplanopt = 0` |
| 2-D | `fftw2d`, `fftw_r2c_2d`, `fftw_c2c_2d` | `data, inverse = 0, HermConj = 1` |
| 3-D | `fftw3d`, `fftw_r2c_3d`, `fftw_c2c_3d` | as 2-D |
| n-D | `fftw_c2c_xd` | `data, inverse = 0` |

Its conventions, from the sources: `inverse` is `0`/`1` and the inverse
is never scaled (no `1/n` anywhere, as in `stats::fft()`); `fftw()`
sends non-complex input to `fftw_r2c()` and complex input to
`fftw_c2c()`; `HermConj = 1` (the default) returns the full-length
spectrum for real input and `HermConj = 0` the non-redundant `n %/% 2 +
1` values; `fftw_c2r(data, HermConj = 0, n)` needs the original length
`n` because the half spectrum does not determine parity. In C, every
1-D, 2-D, 3-D and n-D call creates a plan with `FFTW_ESTIMATE`, executes
it and destroys it; nothing is cached; the column-wise functions use
`FFTW_MEASURE` only when `fftplanopt = 1`. R's vectors are handed to
FFTW directly without copying. For `mvfftw_r2c()`, `fftw_r2c_2d()` and
`fftw_r2c_3d()` with `HermConj = 1`, the redundant conjugate half is
reconstructed in R code after the C call.

These facts shape §5 (what to be familiar with), §11 (where ducc0's plan
cache and C-side Hermitian fill are structural advantages, and where
FFTW's codelets are) and §12.3 (the system FFTW that fftwtools links
selects AVX2 codelets at run time, while a CRAN-portable zufft is
compiled for SSE2 on x86-64).

### 3.2 The others

- `stats::fft()`, `mvfft()`, `nextn()`, `convolve()`: §1.
- `fftw` 1.0-9 (GPL-2): `planFFT`, `FFT`, `IFFT`, `planDCT`, `DCT`,
  `IDCT` on system FFTW3; the only package with a DCT.
- `ravetools` 0.3.2 (GPL >= 2): also on system FFTW3.
- `gsignal` 0.3-7 (GPL-3) and `pracma` 2.4.6 (GPL >= 3): signal-processing
  functions in the MATLAB style; which FFT they call underneath was not
  checked.
- `torch` (MIT): FFTs through LibTorch, a very large dependency.
- No R binding of ducc0 or of pocketfft was found by a web search.

### 3.3 In the `zu*` family

| | zufft |
| --- | --- |
| Role | provider (C table, `LinkingTo` header); R API |
| R prefix | `fft_`; `fft_stats()`, `mvfft_stats()` for compatibility |
| Info function | `zufft_info()` |
| Root condition class | `zufft_error` |
| Public C prefix | `zufft_` for the table and header; internal `zff_` |
| From C | `R_GetCCallable("zufft", "zufft_api_v1")` |
| Hides symbols | yes (R3; `$(CXX_VISIBILITY)` plus a linker export list, §12.2) |
| Vendored code | ducc0 FFT subset as SciPy vendors it, 17 files |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

- **`zufast`** cannot hold an FFT. Its design makes it header-only C99 and
  lists "a registered function table or a static archive" among its
  permanent non-goals; ducc0 is C++17 with three compiled sources and a
  thread pool. zufast's argument for avoiding a table (an indirect call
  is the whole cost of a tiny primitive) does not apply to an O(n log n)
  transform.
- **`zutsne`** (RFC 0028) is the first consumer of the C table. FIt-SNE's
  `nbodyfft.cpp` uses FFTW for exactly three shapes: a 2-D real-to-complex
  and complex-to-real pair on an `n × n` grid (once per embedding term per
  iteration) and an in-place 1-D complex pair of length
  `2 × interpolation points`, all unnormalised and planned with
  `FFTW_ESTIMATE`. The table's `r2c`, `c2r` and `c2c` members (§7) cover
  all three; FFTW is GPL-2+, so this also keeps zutsne free of it.
- No other family package is required to adopt zufft.

## 4. Architecture

```text
R array (double / integer / logical / complex), dims, axes, n, norm
   |
   v
R layer: argument checks, axes (1-based), crop or zero-pad, norm and
         workers resolved, output dims computed
   |
   v
C glue (src/zff_*.c): R vectors in, data pointers, shape and strides
         (column-major, in elements), output allocated with R's allocator
   |
   v
C++ shim (src/zff_shim.cpp): extern "C", noexcept; builds ducc0
         cfmav/vfmav views, computes the scale as pyduccfft does, calls
         c2c / r2c / c2r / dct / dst, catches every exception into a
         status code and a thread-local message
   |
   v
ducc0 FFT (vendored, C++17), threads from zufft's pool (§6.5)
   |
   v
R result: complex or double array with the transformed dims
```

- zufft's own code is C; the shim is the only C++ it writes. No C++ type
  or exception crosses into C or R, and R's API is never called from the
  shim or from a pool thread, so no `longjmp` passes through C++ frames.
- R's column-major arrays are passed as strided views; nothing is
  transposed. An R axis `k` is axis `k - 1` to ducc0.
- The same shim functions serve the R glue and the C table (§7), so the
  two paths cannot drift.
- The R layer does no arithmetic on the data: crop and pad are done by
  the C glue into the output buffer, and the Hermitian fill for
  `fft_c2c()` on real input is done in C (§6.1). fftwtools does the
  latter in R for its 2-D, 3-D and column-wise real transforms, which is
  part of the performance gap §11 expects to find there.

## 5. Public R API (complete v0.1.0 surface)

### 5.1 Native

```r
# discrete Fourier transforms
fft_c2c(x, inverse = FALSE, n = NULL, axes = NULL,
        norm = c("backward", "ortho", "forward", "none"), workers = NULL)
fft_r2c(x, n = NULL, axes = NULL,
        norm = c("backward", "ortho", "forward", "none"), workers = NULL)
fft_c2r(x, n = NULL, axes = NULL,
        norm = c("backward", "ortho", "forward", "none"), workers = NULL)

# real trigonometric transforms
fft_dct(x, type = 2L, inverse = FALSE, n = NULL, axes = NULL,
        norm = c("backward", "ortho", "forward", "none"),
        orthogonalize = NULL, workers = NULL)
fft_dst(x, type = 2L, inverse = FALSE, n = NULL, axes = NULL,
        norm = c("backward", "ortho", "forward", "none"),
        orthogonalize = NULL, workers = NULL)

# lengths, frequencies, shifts
fft_next_len(n, real = FALSE)     # smallest fast length >= n
fft_prev_len(n, real = FALSE)     # largest fast length <= n
fft_freq(n, d = 1)                # sample frequencies (fftfreq)
fft_rfreq(n, d = 1)               # rfftfreq
fft_shift(x, axes = NULL)         # fftshift
fft_ishift(x, axes = NULL)        # ifftshift

# threads
fft_workers(n = NULL)             # get, or set and return the old value
with_fft_workers(n, code)         # scipy.fft.set_workers() as a context
local_fft_workers(n, .local_envir = parent.frame())

zufft_info()                      # ducc0 commit, SciPy commit, SIMD width
                                  # and backend, FMA contraction, threading
                                  # mode, pool size, complex path (§12.2)
```

**Argument order.** `x` first; `inverse` second where it exists, so that
`fft_c2c(x, TRUE)` reads like `fft(z, TRUE)` and `fftw(data, 1)`; then
`n`, then `axes`, as SciPy's `fft(x, n, axis)`; everything after that is
meant to be named. `fft_c2r(x, n)` puts the one argument an inverse real
transform usually needs where fftwtools users look for it.

**`axes = NULL`** means every dimension in ascending order (a plain vector
has one), as `stats::fft()` does for arrays; for the real transforms
`fft_r2c()` and `fft_c2r()` it means every dimension in *descending*
order, so the first dimension is the halved one (D17). Otherwise `axes` contains
unique, 1-based, exactly representable whole numbers in
`1..length(dim(x))`; an empty vector and duplicate axes are errors. Axis
order is significant for real transforms: the last listed axis is the
half-complex axis, as in SciPy. With `axes = NULL`, `n` is still given in
dimension order and reordered to match. Column-wise transforms, fftwtools' `mvfftw*` and R's
`mvfft()`, are `axes = 1` on a matrix.

**`n = NULL`** uses the input lengths. Otherwise `n` contains one positive,
exactly representable whole number per transformed axis, with no
recycling; when `axes = NULL` it must therefore contain one value per
input dimension. This deliberately avoids SciPy's rule that a short `s`
selects trailing axes. Shape products and byte counts are checked for
overflow before any allocation. `n` combines SciPy's 1-D `n` and n-D `s`.

**`inverse`** is logical. fftwtools' `inverse = 0`/`1` works unchanged
because `0` and `1` coerce; any other number is an error rather than
"non-zero means inverse".

**`norm`** is §6.3. The default is SciPy's `"backward"` (unscaled forward,
`1/N` inverse), so that `fft_c2c(fft_c2c(x), inverse = TRUE)` returns
`x`. fftwtools and `stats::fft()` scale neither direction; that is
`norm = "none"`, and it is the only `norm` under which an inverse here
and an inverse there agree without a factor.

### 5.2 Coming from fftwtools

Real input to `fft_c2c()` yields the full Hermitian spectrum, as
`fftw(real)` and `fftw_r2c(real, HermConj = 1)` do; `fft_r2c()` yields
the non-redundant half, as `HermConj = 0` does. Every row below returns
the same values for the same input, with `norm = "none"` wherever
fftwtools would run an inverse.

| fftwtools | zufft |
| --- | --- |
| `fftw(x)` (real or complex) | `fft_c2c(x)` |
| `fftw(x, inverse = 1)` | `fft_c2c(x, inverse = TRUE, norm = "none")` |
| `fftw(x, HermConj = 0)` (real) | `fft_r2c(x)` |
| `fftw(X, inverse = 1, HermConj = 0, n = n)` | `fft_c2r(X, n = n, norm = "none")` |
| `fftw_r2c(x)` / `fftw_r2c(x, HermConj = 0)` | `fft_c2c(x)` / `fft_r2c(x)` |
| `fftw_c2r(X, HermConj = 0, n = n)` | `fft_c2r(X, n = n, norm = "none")` |
| `fftw_c2r(X)` (full spectrum) | `Re(fft_c2c(X, inverse = TRUE, norm = "none"))` |
| `fftw_c2c(x, inverse = i)` | `fft_c2c(x, inverse = i, norm = "none")` |
| `mvfftw(x)`, `mvfftw_c2c(x)` | `fft_c2c(x, axes = 1)` |
| `mvfftw_r2c(x, HermConj = 0)` | `fft_r2c(x, axes = 1)` |
| `mvfftw_c2r(X, HermConj = 0, n = n)` | `fft_c2r(X, n = n, axes = 1, norm = "none")` |
| `fftw2d(x)`, `fftw_c2c_2d(x)`, `fftw3d(x)`, `fftw_c2c_xd(x)` | `fft_c2c(x)` |
| `fftw_r2c_2d(x, HermConj = 0)`, `fftw_r2c_3d(x, HermConj = 0)` | `fft_r2c(x)` (FFTW is row-major, so fftwtools halves R's first axis, as zufft's default does since D17; checked against fftwtools 0.9-11) |
| `mvfftw(..., fftplanopt = 1)` | nothing to do: plans are cached |
| (none) | `workers`, `norm`, `n` padding, `axes`, DCT/DST, helpers |

What a migrating package gains: no `SystemRequirements`, no GPL, every
length in O(n log n), threads, and `fft_c2r()` that never
destroys its input. What it loses: nothing in the table above. The
vignette carries this table and a worked example per row.

### 5.3 `stats` compatibility

`fft_stats(z, inverse = FALSE)` and `mvfft_stats(z, inverse = FALSE)` have
`stats::fft()` and `mvfft()`'s signatures, argument checks, result shapes,
attributes and unnormalised inverse, including returning inputs of length
0 and 1 unchanged as `fourier.c` does. Values agree to rounding, not bit
for bit (§10). A package moves by replacing `fft(` with
`zufft::fft_stats(` and adding the `Imports` entry; it gains every length
in O(n log n), and `fft_stats()` on a real vector uses
the real transform internally. These are thin wrappers over
`fft_c2c(..., norm = "none")`.

### 5.4 Coming from scipy.fft

| SciPy | zufft |
| --- | --- |
| `fft(x, n, axis)` | `fft_c2c(x, n = n, axes = axis + 1)` |
| `ifft` | `fft_c2c(..., inverse = TRUE)` |
| `fft2`, `fftn(x, s, axes)` | `fft_c2c(x, n = s, axes = axes + 1)` |
| `rfft`, `rfft2`, `rfftn` | `fft_r2c()` |
| `irfft`, `irfft2`, `irfftn` | `fft_c2r()` |
| `dct`, `dctn` | `fft_dct()` |
| `idct`, `idctn` | `fft_dct(..., inverse = TRUE)` |
| `dst`, `dstn`, `idst`, `idstn` | `fft_dst()` |
| `fftfreq`, `rfftfreq`, `fftshift`, `ifftshift` | `fft_freq()`, `fft_rfreq()`, `fft_shift()`, `fft_ishift()` |
| `next_fast_len`, `prev_fast_len` | `fft_next_len()`, `fft_prev_len()` |
| `get_workers`, `set_workers` (context) | `fft_workers()`, `with_fft_workers()` |
| `hfft`, `ihfft`, `fht`, backends, `overwrite_x`, `plan` | not offered |

SciPy's default `axis = -1` is the last axis; zufft's default is all
axes, so a 1-D SciPy call on a matrix is `axes = length(dim(x))` here. An
array moved between R and NumPy by `reticulate` keeps its shape, so axis
`k` in NumPy (0-based) is axis `k + 1` in R.

## 6. Semantics

### 6.1 Input and output types

- Double, integer and logical inputs are real; integer and logical are
  coerced to double. Complex inputs are complex. Anything else is
  `zufft_invalid_argument`.
- `fft_c2c()` on real input does what `pyduccfft.cxx`'s `c2c_sym_internal`
  does: a real-to-complex transform, then the Hermitian half filled in by
  conjugation, in C. This halves the work and is what makes
  `fft_c2c(<double>)` agree with `scipy.fft.fft(<float64>)` and with
  `fftw(<double>)`.
- `fft_r2c()` halves the last axis listed in `axes`, or the first
  dimension when `axes = NULL` (D17), to `n %/% 2 + 1`;
  `fft_c2r()` takes that shape and restores `n`, by default
  `2 * (m - 1)` on that axis, as SciPy does; an odd original length must
  be given, as in fftwtools.
- `fft_dct()` and `fft_dst()` on complex input transform the real and
  imaginary parts separately. For parity with the selected SciPy commit,
  explicit `orthogonalize` is ignored for complex input and its effective
  value is `norm == "ortho"`; SciPy's `realtransforms.py` omits that
  argument on its two component calls. This is documented and covered by
  a regression test. If SciPy changes it, zufft changes only with a
  re-vendoring decision.
- Results keep `dim`; `dimnames` survive on axes that were not
  transformed and are dropped on axes that were; `names` are dropped.
- Inputs are never modified. SciPy's `overwrite_x` and `plan` arguments
  are not offered.

### 6.2 Lengths

- `n` crops or zero-pads each transformed axis before the transform, as
  SciPy does. A length below 1 (or below 2 for DCT-I) is
  `zufft_length_error`, as SciPy raises `ValueError`.
- Lengths are `R_xlen_t` in R and `size_t` in ducc0, and no `int` sits
  between them, so long vectors should work; v0.1.0 does not promise them
  because the §10 release gate has not run (§2). R array extents remain limited by
  the integer `dim` attribute even when their product is a long-vector
  length; a plain vector's extent comes from `XLENGTH()`. Numeric length
  arguments above 2^53 are rejected because R cannot represent them
  exactly.
- `fft_next_len(n, real)` is ducc0's `good_size_complex` (factors 2, 3, 5,
  7, 11) or `good_size_real` (2, 3, 5); `fft_prev_len()` is the same
  search downwards, ported from `pyduccfft.cxx`, which keeps it outside
  ducc0. In the drafting session `good_size_complex` gave 1024 for 1009
  and 1 000 000 for 999 983, as `scipy.fft.next_fast_len` does.

### 6.3 Normalisation

`norm` has SciPy's meaning: `"backward"` scales the inverse by `1/N`,
`"forward"` the forward transform, `"ortho"` both by `1/sqrt(N)`, where
`N` is the product of the transformed lengths (for DCT-I `2(n - 1)`, for
DST-I `2(n + 1)`, otherwise `2n`, per axis). `"none"` scales neither
direction: it is FFTW's convention, fftwtools' and `stats::fft()`'s, and
for forward transforms it is identical to `"backward"`. The scale is
computed as `pyduccfft.cxx` computes it, in `long double` and then
rounded to `double`, and passed to ducc0 as its `fct` argument; for
`"none"` the factor is exactly 1 and ducc0 skips the multiplication.
`orthogonalize = NULL` means `norm == "ortho"`, as in SciPy. `inverse =
TRUE` swaps DCT and DST types II and III and the direction of the
normalisation, as SciPy's `_r2r` does; under `"none"` only the type swap
happens.

### 6.4 Non-finite values

zufft does not inspect values. `NA`, `NaN` and infinities propagate
through the arithmetic in an unspecified pattern; `NA` becomes `NaN` in
the output, not `NA_real_`. `stats::fft()` behaves the same way
(unverified in detail).

### 6.5 Threads

- `workers = NULL` takes `fft_workers()`, initially `1`, which is SciPy's
  default and fftwtools' only mode. A positive value asks for that many
  threads; `-1` means all available cores and `-k` all but `k - 1`, as in
  SciPy; zero is an error. Requests are capped at the available cores
  and, when `_R_CHECK_LIMIT_CORES_` is set, at 2 (CRAN's policy: never
  more than two simultaneously).
- `with_fft_workers(n, code)` and `local_fft_workers(n)` set the default
  for a block or a frame and restore the old value, in the `withr` style
  (implemented without depending on `withr`).
- What threads can do, from `fftnd_impl.h`: `general_nd` splits the
  1-D lines of a multi-dimensional transform statically across threads;
  `thread_count` returns 1 when the array has fewer than 32 768 elements
  or when `nthreads == 1`, and never exceeds the number of lines. A
  contiguous 1-D vector takes a shortcut (`exec_simple`) that runs the
  plan on one thread, except that a 1-D complex transform of length at
  least 131 072 whose length factors as `f1 × f2` with `f1 >= 16` is
  reshaped to 2-D (Bailey's four-step) and transformed with both SIMD and
  threads. These are the shapes §11 measures. **Measured (Stage 8):** the
  claim in the first draft that a 1-D real transform never uses threads is
  wrong; `exec_simple` hands `nthreads` to the 1-D plan, whose passes run
  in parallel, so with two threads 1-D transforms from about 65 536 points
  speed up 1.3–2× (complex and real), while below a few thousand points the
  thread hand-off costs more than it saves (1 024 points: 12.4 → 13.6 µs).
- ducc0 is built with `DUCC0_CUSTOM_LOWLEVEL_THREADING`, and zufft
  supplies the pool. Upstream's default pool was rejected for three
  measured reasons: it is created on the first transform with one worker
  per hardware thread minus one whatever `nthreads` is requested (on the
  two-core drafting machine a single-threaded call started a worker
  thread); its size comes from `DUCC0_NUM_THREADS` or `OMP_NUM_THREADS`,
  read once; and it pins threads (`pthread_setaffinity_np`). zufft does
  not read those variables and never pins threads.
- zufft's pool starts no thread until a call asks for more than one,
  grows to the largest request, and never shrinks during a session. A
  process-wide entry gate serializes transform calls in v0.1.0. This makes
  pool growth, plan-cache use, and package unload deterministic and makes
  C-table calls safe from arbitrary caller threads, at the cost of no
  parallelism between independent top-level transforms. Internal workers
  still execute one transform in parallel. Removing this gate requires a
  dedicated concurrency design and stress tests.
- Fork safety is explicit rather than inferred from a process-id check.
  On POSIX, once the pool exists zufft registers `pthread_atfork` handlers:
  the prepare handler takes the entry gate and quiesces the pool, the parent
  releases it and rebuilds lazily, and the child marks the inherited pool
  abandoned and rebuilds lazily without touching mutexes owned by vanished
  threads. Stage 0 stress-tests `parallel::mclapply()` both before and after
  pool creation. If this cannot be made reliable on a supported POSIX leg,
  persistent multithreading is disabled on that leg; a process-id check by
  itself is not accepted as fork safety.
- `R_unload_zufft` takes the entry gate and joins every worker before the
  shared library can be unloaded. Calls through a cached C table after the
  provider unloads remain invalid, as with any `R_GetCCallable` API.
- **As built (Stage 6, `src/zff_pool.cpp`).** The pool is a FIFO of tasks
  served by `std::thread` workers waiting on one condition variable; ducc0
  submits `nthreads - 1` tasks per parallel region and runs the rest on the
  calling thread. Workers set ducc0's `in_parallel_region`, so nested
  regions run serially, as in ducc0's own pool. `pthread_atfork` handlers
  cannot be unregistered, and `devtools::load_all()` unloads and reloads
  the shared object, so a fork after a reload would jump into unmapped
  code. When the handlers are registered (the first threaded call), the
  shared object therefore pins itself in memory with `dlopen(...,
  RTLD_NODELETE)`; after an unload the handlers find no pool and do
  nothing. The child abandons the inherited pool object, because its
  threads do not exist and its queue lock was taken by the prepare
  handler; it keeps the pointer in a static slot so the memory stays
  reachable. At process exit on POSIX an `atexit` handler (registered
  after the pinning) joins the workers; not on Windows, where a DLL's
  `atexit` handlers run under the loader lock and joining threads there
  deadlocked every process exit in CI; so no thread outlives the process's
  teardown; valgrind on pedrobtz/zufft#21 flagged both, the abandoned pool
  as "definitely lost" and running threads as "possibly lost". Forked
  children leave by `_exit()`, which skips static destructors and exit
  handlers, so valgrind also reports memory in them that only the parent's
  vanished worker stacks, or ducc0's plan cache through the interior
  pointers of its aligned buffers, refer to. Those are artefacts of the
  fork, not leaks, and the fork test skips under valgrind (detected by its
  `LD_PRELOAD`); the other legs, sanitizers included, run it.
- A transform is not interruptible. Pool threads never call R.

## 7. The C table and the `LinkingTo` header

**Decision.** zufft is a provider through a registered C table, with a C
header in `inst/include/zufft.h` for consumers that declare
`LinkingTo: zufft` and `Imports: zufft`. It does not export ducc0's
headers through `LinkingTo`.

**Why not header-only ducc0 through `LinkingTo`:**

1. ducc0's FFT is templates in headers, but `threading.cc`, `mav.cc` and
   `string_utils.cc` must be compiled. Every consumer would compile them
   again and get its own thread pool and its own plan cache.
2. It forces C++17 and ducc0's types on the consumer. zutsne is C++, but
   a C consumer could not use it at all.
3. Each consumer would carry its own copy at its own commit, and its own
   compile flags, so §1's compatibility statement would hold only for
   zufft.
4. Each consumer would pay the compile time (§12.2) again.
5. The table's cost is one indirect call per transform, which is
   invisible against the transform itself.

A static archive was rejected for the reasons zufast's design gives: it
needs a `configure` script in every consumer, and the family uses it only
for C libraries that cannot be retargeted.

```c
/* inst/include/zufft.h */
typedef struct {
  int              ndim;
  const size_t    *shape;   /* extents */
  const ptrdiff_t *stride;  /* logical elements; NULL = column-major dense */
} zufft_layout;

typedef enum {
  ZUFFT_OK = 0,
  ZUFFT_EINVAL = 1,
  ZUFFT_ESHAPE = 2,
  ZUFFT_EOVERFLOW = 3,
  ZUFFT_ENOMEM = 4,
  ZUFFT_ETHREAD = 5,
  ZUFFT_EENGINE = 6,
  ZUFFT_EINTERNAL = 7
} zufft_status;

typedef struct {
  size_t struct_size;
  unsigned int abi_version;  /* exactly 1 for this layout */
  unsigned int flags;        /* reserved feature bits; zero in v1 */
  /* Complex buffers contain pairs of doubles in re, im order. */
  int (*c2c)(const zufft_layout *lin, const double *in,
             const zufft_layout *lout, double *out,
             int naxes, const int *axes, int forward,
             double fct, int nthreads);
  int (*r2c)(const zufft_layout *lin, const double *in,
             const zufft_layout *lout, double *out,
             int naxes, const int *axes, int forward,
             double fct, int nthreads);
  int (*c2r)(const zufft_layout *lin, const double *in,
             const zufft_layout *lout, double *out,
             int naxes, const int *axes, int forward,
             double fct, int nthreads);
  int (*dct)(const zufft_layout *lin, const double *in,
             const zufft_layout *lout, double *out,
             int naxes, const int *axes, int type,
             double fct, int ortho, int nthreads);
  int (*dst)(const zufft_layout *lin, const double *in,
             const zufft_layout *lout, double *out,
             int naxes, const int *axes, int type,
             double fct, int ortho, int nthreads);
  size_t (*good_size)(size_t n, int real);
  const char *(*message)(void);  /* this thread's last failure */
  /* … appended over time … */
} zufft_api;

/* zufft registers a getter function, not a data pointer, as
   R_RegisterCCallable("zufft", "zufft_api_v1", getter). */
static inline const zufft_api *zufft_api_get(void);
```

- `R_RegisterCCallable` stores a `DL_FUNC`, so the registered symbol is a
  function returning `const zufft_api *`; casting a table's data address to
  `DL_FUNC` is not permitted. `zufft_api_get()` resolves that function with
  `R_GetCCallable`, calls it, then verifies `abi_version` and `struct_size`.
  Resolution uses R and must happen on the R thread during consumer
  initialization. Cached table members themselves never call R.
- Axes are 0-based in C. They must be unique and in range. Shapes must be
  nonzero, address calculations must not overflow `ptrdiff_t`, and writable
  layouts must not overlap themselves. Negative strides are not supported in
  v1. For real buffers, a stride unit is one double; for complex buffers it
  is one real/imag pair. NULL data, shapes, axes and inconsistent input/output
  shapes return a stable status code rather than reaching ducc0 assertions.
- `fct` is the caller's scale (1 for FFTW's unnormalised convention); the
  header provides a typed normalization enum and an overflow-checked helper
  that computes §6.3's factor in `long double` before conversion to `double`.
- `c2c` may run in place when `in == out` with identical layouts, which
  is what FIt-SNE's 1-D pair does; `r2c` and `c2r` must not overlap, and
  `c2r` leaves its input unchanged (FFTW's destroys it).
- `nthreads` is as `workers` in §6.5, with `0` meaning the current
  `fft_workers()` value, held in an atomic so pool threads and consumer
  threads can read it without R.
- Return codes are the stable `zufft_status` values above. After a failure,
  `message()` returns a pointer to this caller thread's diagnostic; the
  caller must copy it before the next zufft call on that thread. A successful
  call clears the diagnostic. Members never call R and are callable from any
  thread; section 6.5 defines v1's serialization.
- The table follows `zuxml`'s versioning rules: members are appended,
  `struct_size` lets a consumer check that a member exists, and a layout
  change bumps the registered name to `zufft_api_v2`.
- **As built (Stage 7).** `src/zff_api.cpp` holds the table; each member
  converts the layout, resolves `nthreads` (0 is the session's
  `fft_workers()`, mirrored in an atomic; negative counts back from the
  cores; capped at the cores and at 2 under `_R_CHECK_LIMIT_CORES_`) and
  calls the shim function the R glue uses. The shim rejects a writable
  layout that reaches an element twice, input and output byte ranges that
  overlap (except an identical in-place `c2c`, `dct` or `dst`), and any
  view whose last byte is not addressable with `ptrdiff_t`. Defining
  `ZUFFT_NO_R` before including `zufft.h` leaves out `zufft_api_get()` and
  R's headers, for code built without R (zufft's fuzz target).

## 8. The vendored library and its licence

"Just vendor ducc0, carefully" means: exactly the files SciPy's SPDX
filter keeps, from exactly the commit SciPy pins, with a script that can
prove it, and a licence trail CRAN can read.

- **What.** 17 of SciPy's 19 files, into `src/ducc0/` with SciPy's paths:
  `fft/fft.h`, `fft/fft1d_impl.h`, `fft/fftnd_impl.h`,
  `fft/fft_inst_inc.h`, `infra/aligned_array.h`, `infra/error_handling.h`,
  `infra/mav.h`, `infra/mav.cc`, `infra/misc_utils.h`, `infra/simd.h`,
  `infra/string_utils.h`, `infra/string_utils.cc`, `infra/threading.h`,
  `infra/threading.cc`, `infra/useful_macros.h`, `math/cmplx.h`,
  `math/unity_roots.h`. Left out: `bindings/pybind_utils.h` (Python) and
  `math/pswf_rokhlin.h` (nothing in the FFT includes it). The include
  graph was checked with `g++ -MM`.
- **From where.** From ducc0 at the commit SciPy's
  `tools/vendoring/vendor_duccfft.sh` pins (`64f42ba` today), with the same
  SPDX filter. `tools/vendor/vendor-ducc` then checks byte-identity with
  SciPy's `subprojects/duccfft` at a named SciPy commit, and **fails if any
  file lacks the dual-licence SPDX line or is not in the list above**. It
  also copies SciPy's `subprojects/duccfft/LICENSE.md` (the BSD-3 text) to
  `src/ducc0/LICENSE.md`, records both commits in
  `tools/vendor/manifest.tsv`, each file's SHA-256 in
  `tools/vendor/checksums.sha256`, and writes the commits into
  `src/zff_version.h`, from which `zufft_info()` reports them.
  `tools/vendor/verify` checks the tree offline (exactly the listed files,
  each checksum, each SPDX line, the version header), and CI runs it on
  every pull request through r-actions' `vendor.yml`, which also fails a
  pull request that changes `src/ducc0/` without updating both manifest
  files; `tools/vendor/verify-selftest` shows in CI that the verifier
  rejects an unlisted file and an edited one. (Stage 1, 2026-10-13: these
  paths replace the `tools/vendor-ducc` and `src/ducc0/VERSION` of the
  first draft, to match r-actions' defaults.) The
  meson version string (`0.41.1`) is not used as an identity: the pinned
  commit postdates that tag and differs from it in six of the files.
- **Licence.** Each file is "BSD-3-Clause OR GPL-2.0-or-later"; zufft
  elects BSD-3-Clause, which is compatible with its own MIT licence and
  imposes nothing on packages that import zufft. The full ducc0
  repository is GPL-2.0-or-later (its `LICENSE`, `pyproject.toml`
  classifier and README: "All source code in this package is released
  under the terms of the GNU General Public License v2 or later. Some
  files (those constituting the FFT component and its internal
  dependencies) are also licensed under the 3-clause BSD license"), so
  nothing outside the SPDX-filtered subset may ever be copied in, and
  §2's "Never" list follows from this. The notice in `fft1d_impl.h` for
  "the odd-sized DCT-IV transforms" (copyright Matteo Frigo and MIT, the
  FFTW authors) sits above the same dual SPDX line; that upstream may
  relicense that code under BSD is upstream's statement and was not
  examined further. `infra/threading.cc` also carries "Copyright 2015 The
  TensorFlow Authors" on two helper templates (a y-combinator) inside a
  block compiled only under `DUCC0_HIERARCHICAL_SUBMISSION`, which zufft
  never defines (found in Stage 1).
- **In the package.** `DESCRIPTION` lists Martin Reinecke as `ctb`, Peter Bell
  as `ctb` and `cph`, and the Max-Planck-Society, Matteo Frigo, MIT and
  the TensorFlow Authors as `cph` in `Authors@R`, as the CRAN policy
  prefers for copied code; a `Copyright:` field points to
  `inst/COPYRIGHTS`, which carries the BSD-3 text with every notice found
  in the bundled files. Code ported from SciPy's `pyduccfft.cxx` (Stage 5)
  adds its holder when it lands. The package `License` stays `MIT + file
  LICENSE`.
- **Patches.** Two, in `tools/vendor/patches/`, applied by the vendor
  tool after the comparison with SciPy and recorded with their checksums in
  the manifest. `0002-dcst-scratch-buffer-data.patch` (Stage 4) passes the
  scratch buffer as `buf.data()` instead of `&buf[0]` in the allocating
  `exec()` overloads of `T_dcst23` and `T_dcst4`: for a plan with no
  scratch (a length-1 DST-II, for example) the buffer is empty, and
  `&buf[0]` binds a reference to a null pointer, which the clang and gcc
  UBSan legs reported and CRAN's UBSan flavors would too.
  `0001-error-handling-no-gnu-va-args.patch` replaces the GNU
  `, ##__VA_ARGS__` in `MR_fail` and `MR_assert` with plain `__VA_ARGS__`.
  clang `-pedantic`, which CRAN's debian-clang flavor uses for C++, reports
  the GNU form as a significant warning, so R CMD check gives a WARNING
  (found by the clang23 leg in Stage 1); every call site passes at least
  one argument, so the expansion is unchanged, and a pragma would draw R's
  NOTE about diagnostic-suppressing pragmas. A re-vendor must re-apply it
  or show it is no longer needed. Besides the patch, zufft supplies
  `src/ducc0_custom_lowlevel_threading.h` (`Mutex`, `LockGuard`,
  `UniqueLock`, `CondVar` as the standard library's) and its pool
  (`set_active_pool()`, `get_active_pool()`, and
  `available_hardware_threads()`, which `threading.cc` defines only in its
  two built-in modes). The header must also
  declare `in_parallel_region`: at `64f42ba`, `threading.cc` refers to it
  outside the threading-mode blocks, so custom mode fails to compile
  without it. The drafting session confirmed both the failure and the
  workaround (`inline thread_local bool in_parallel_region`), and results
  in custom mode were bit-identical to the default mode.
- **Defines.** `DUCC0_CUSTOM_LOWLEVEL_THREADING`. Not `DUCC0_NO_FFT_CACHE`:
  the cache is mutex-guarded and SciPy keeps it, and it is one of the two
  structural advantages over fftwtools' plan-per-call (§11). Not
  `DUCC0_NO_SIMD`. R adds `-DNDEBUG` itself; ducc0's checks use its own
  `MR_assert`, which throws and is unaffected.
- **Instantiation.** One translation unit per transform family
  (`c2c`; `r2c` and `c2r`; `dct` and `dst`) includes `fft.h` and
  `fftnd_impl.h` and explicitly instantiates only that family's functions
  for `double`, so `make -j` can compile them in parallel. ducc0's
  `fft_inst_inc.h` instantiates every transform at once (Hartley and
  `convolve_axis` included), so it cannot be split that way; it stays
  vendored but unused (Stage 1). R compiles only files directly in `src/`,
  so each vendored `.cc` is built through a one-line wrapper
  (`src/zff_ducc_*.cpp`) instead of an `OBJECTS` list.
- **Updates.** zufft re-vendors when SciPy re-vendors, to the same
  commit, after the full test suite, regenerated SciPy fixtures (§10) and
  a benchmark run (§11).

## 9. Errors

Every condition inherits `zufft_error`: `zufft_invalid_argument` (types,
axes, `norm`, `type`, `workers`), `zufft_length_error` (a transformed
length below the minimum, or an output beyond R's vector limits),
`zufft_engine_error` (a ducc0 exception, with its message),
`zufft_thread_error` (the pool could not start a thread),
`zufft_internal_error`.

## 10. Testing

- **SciPy fixtures.** `tools/make-scipy-reference.py` runs offline in a
  clean virtual environment with a released SciPy whose fft backend is
  ducc0. (The first draft asked for a SciPy built from commit `ecee36d`;
  with bit-identity withdrawn (D14) the tolerance below is the criterion,
  so Stage 8 used the SciPy 1.18.1 wheel and records it in
  `tests/testthat/fixtures/scipy/MANIFEST`.) It covers every transform and type, every `norm`,
  `orthogonalize`, lengths 1–64 and selected composite, prime and large
  lengths, 2-D and 3-D arrays over each ordered axis subset, crop and pad,
  odd and even `c2r` lengths, and validation failures. It stores inputs and
  outputs as little-endian doubles in `tests/testthat/fixtures/scipy/`
  (budget 1 MB; Stage 8: 2040 cases, 1.00 MB), with the SciPy, NumPy and
  Python versions and the platform in a manifest. All 2040 cases agree
  within the tolerance. SciPy reaches a ducc0 assertion (`RuntimeError`)
  for a DCT-I of length 1, where zufft raises `zufft_length_error` first.
- **Numerical criterion.** Every CI leg requires
  `max(Mod(actual - expected)) <= 32 * .Machine$double.eps *
  max(1, log2(N)) * max(1, max(Mod(expected)))`, where `N` is the effective
  transformed size from §6.3. Any change to that formula is a design
  change, not a test tweak. There is no bit-exact job (D14); the
  observation that ducc0 `64f42ba` and SciPy 1.18.1 agreed bit for bit in
  the drafting session is recorded as a curiosity, not a requirement.
- **fftwtools as oracle.** `fftwtools` is in `Suggests`; when it is
  installed (the CI legs install libfftw3 for it), every row of §5.2's
  table is executed on both sides and compared within the tolerance,
  including `norm = "none"` inverses, `HermConj` both ways and odd
  `c2r` lengths. On CRAN the tests skip if fftwtools is absent.
- **`stats::fft()` as oracle.** `fft_c2c()` and `fft_stats()` agree with
  `stats::fft()` and `mvfft()` within that tolerance for lengths 1–1024,
  large composite lengths and random arrays. It is no oracle for large
  prime lengths: its O(n²) pass misses the tolerance at n = 65 537 (error
  1.2e-8 against a bound of 7.5e-9 on a pure tone, where zufft's error is
  2.9e-11; measured in Stage 3), so primes are tested on pure tones, whose
  spectrum is exact; `fft_stats()` reproduces their result structure and
  attributes exactly, and their help-page examples.
- **Direct DFT.** For `n <= 64`, every transform against an O(n²)
  evaluation in R of the defining sum.
- **Identities.** Inverse round trips for every transform and `norm`
  (for `"none"`, up to the factor `N`); Parseval (`sum(abs(x)^2) ==
  sum(abs(X)^2) / N` under `"backward"` and `"none"`, equality under
  `"ortho"`); linearity; the shift theorem; Hermitian symmetry of
  `fft_c2c()` on real input; DCT-II and DCT-III as an inverse pair; DCT-II
  equal to an FFT of the even extension.
- **Threads.** Results with `workers = 1` and `workers = 2` were expected
  to be identical, since ducc0 splits independent 1-D transforms; a
  difference is reported, not hidden. **Reported (Stage 6):** on hardware
  with fused multiply-add they can differ in the last bit. ducc0 runs lines
  in SIMD batches plus a scalar tail, the batch boundaries depend on how
  the lines are split between threads, and with contraction allowed
  (§12.3) the vector and scalar paths round differently. With contraction
  off every comparison was bit-identical on an arm64 Mac, at a cost of 1–4%
  in speed (`fft_r2c()` 2048² 14.7 → 15.2 ms, `fft_c2c()` 2^20 11.7 →
  12.2 ms). The tests assert bit-identity on builds without FMA (CRAN's
  x86-64 SSE2 builds) and the §10 tolerance otherwise; repeated calls with
  the same thread count are always bit-identical. **Decided after Stage 10
  (D18):** contraction is off, so results are bit-identical whatever the
  thread count in every build that cannot contract (clang builds, which
  includes CRAN's macOS arm64 binaries, and every target without FMA,
  which includes CRAN's x86-64 builds). `zufft_info()$fp_contract`
  reports it; the tests assert bit-identity when it is `"off"` and the
  tolerance for a GCC build targeting FMA hardware, which R's `Makevars`
  cannot stop from contracting. Other
  thread tests: concurrent C-table callers; repeated pool
  creation and package unload; and forked children before and after pool
  creation on every POSIX CI leg.
- **C table.** A fixture package performs FIt-SNE's 2-D convolution
  through `r2c`, a Hadamard product and `c2r`, and compares it with a
  direct convolution. It also verifies getter resolution, `struct_size`,
  status constants, malformed layouts, overflow rejection, exact in-place
  `c2c`, forbidden overlap, and thread-local diagnostics.
- **Long vectors.** A job that transforms more than 2^31 elements runs
  as a manual release gate on a runner with enough memory (about 50 GB for
  a real input, output and workspace). If that gate is unavailable, long
  vectors move out of v0.1.0 rather than shipping as an unverified claim.
  **Outcome (Stage 8):** no such runner was available, so §2 moved long
  vectors to "later" and §14 no longer requires the gate.
- **Native safety.** Stage 0 and release candidates run the shim and C-table
  tests under AddressSanitizer and UndefinedBehaviorSanitizer, and at least
  one supported compiler builds and tests with LTO. Valgrind covers the R
  boundary on Linux. The zero-copy complex path, if enabled, must pass all
  three configurations.
- **Build flags.** A CI leg runs `R CMD check --as-cran` and fails on the
  "non-portable flag(s)" NOTE (§12.3), so that no flag can be added to
  `Makevars` without a design change.
- A libFuzzer target (`tools/fuzz/fuzz_layout.cpp`, run by r-actions'
  `fuzz.yml` under ASan and UBSan) for shapes, strides, axes and types
  through the C table. The first draft named `zufuzz` targets; zufuzz is
  still an empty skeleton, so Stage 7 used the r-actions harness instead.
  CRAN suite under 15 s.

## 11. Performance targets

Performance is goal 2 of §1, so it is measured from Stage 1, not at the
end. `tools/run-benchmarks` uses `bench::mark()` (median of enough
iterations for a stable estimate, warm plan cache; the first call of each
shape is timed separately as "cold") on the same machine, same session,
against `stats::fft()`, `fftwtools` and, where installed, `fftw`. The
system FFTW's configuration (`fftw_version`, SIMD codelets) and zufft's
`zufft_info()` are recorded with every run, because the system FFTW picks
AVX2 codelets at run time while CRAN-portable zufft is SSE2 on x86-64
(§12.3). Results go in `bench/RESULTS.md` with the hardware, and this
section is updated with the measured numbers.

**Stage 8 Linux runs (2026-10-13, `benchmarks` workflow on
pedrobtz/zufft#23, GitHub `ubuntu-latest`, 4 threads).** The portable
build (SSE2, two doubles per vector, as CRAN builds it) is within 1.5× of
fftwtools everywhere, worst 1.26× (1-D complex 100 000); the complex primes
come in at 1.12× (100 003) and 1.09× (1 000 003), inside the 1.2× prime
target this time (Stage 3's run missed it at 1.23×, so the target is met
on one run and missed on another: shared-runner noise around a near tie).
The opt-in native build (`CXX17FLAGS += -march=native`, AVX2 and FMA,
four doubles per vector) is a median 1.27× faster than the portable one at
one thread, up to 1.76× on 1-D lengths near 10 000 and 1.68× on the
16 384 × 64 column case, and no faster on the largest multi-dimensional
cases, which are memory-bound; against fftwtools its worst ratio is
0.93×. Both builds are in `bench/RESULTS.md`.

**Stage 8 full grid (2026-10-13).** The macOS section of
`bench/RESULTS.md` now has `workers = 1` and `2` for every case. With two
threads zufft is 2.9× to 10× faster than fftwtools on the
multi-dimensional and column-wise cases (128³ complex: 9.2 ms against
89.3 ms) and every single-threaded figure below still holds.

**Measured (Stage 3, 2026-10-13, `workers = 1`).** On an Apple M-series
arm64 laptop with Homebrew's FFTW 3 for fftwtools 0.9-11 (full table in
`bench/RESULTS.md`), zufft is faster than fftwtools on 32 of the 33 grid
points; the exception is the complex prime 1 000 003 at 1.02×. The
smallest ratios are the multi-dimensional complex cases (0.19 for 128³,
0.22 for 512²), where fftwtools' plan-per-call costs most. On a GitHub
`ubuntu-latest` x86-64 runner (Ubuntu's FFTW, `benchmarks` workflow on
pedrobtz/zufft#18) zufft is faster on 27 of 33 points; the slower ones are
single 1-D complex transforms: 65 536 (1.44×), 100 000 (1.19×), 1 000 000
(1.02×) and the primes 100 003 (1.11×) and 1 000 003 (1.23×). That is the
gap this section predicted: CRAN-portable zufft is SSE2 on x86-64 while
the system FFTW selects AVX2 codelets at run time, and a single 1-D
transform below the four-step threshold runs scalar in ducc0. Per-call R overhead is
about 5 µs, so `stats::fft()` (no argument handling) stays faster below a
few thousand points.

**Grid.** 1-D complex and real, lengths 2^10, 2^16, 2^20, 2^22; `3^7 ×
5^3`, `1e5`, `1e6`; primes 10 007, 100 003, 1 000 003. Column-wise: 2^10
× 1024 and 2^14 × 64 (`mvfftw` shapes). 2-D real and complex: 512², 2048²
(FIt-SNE's shape). 3-D complex: 128³. Each with `workers = 1`, and the
2-D and column-wise cases also with `workers = 2`.

**Targets (`workers = 1` unless stated):**

| Case | Target | macOS arm64 (Stage 3) | Linux x86-64 runner (Stage 3) |
| --- | --- | --- | --- |
| Every grid point vs fftwtools' nearest equivalent (`HermConj = 0`, `norm = "none"`) | zufft within 1.5× | met: worst 1.02× | met: worst 1.44× |
| Column-wise and 2-D real transforms vs `mvfftw_r2c()`, `fftw_r2c_2d()` with `HermConj = 1` | zufft faster (fftwtools fills the conjugate half in R) | met: 0.46–0.68× | met: 0.54–0.83× |
| Primes 100 003 and 1 000 003 vs fftwtools | zufft faster or within 1.2× (both are O(n log n): Bluestein vs FFTW's generic algorithms) | met: 0.69–1.02× | **missed** in Stage 3 (complex 1 000 003 at 1.23×), met in Stage 8 (1.12× and 1.09×) |
| 2048 × 2048 real 2-D, `workers = 2` vs `workers = 1` | at least 1.6× | met with `axes = 2:1`: 1.87× (Stage 8 grid); **missed** with the default axes: 1.49× (Stage 6) | see `bench/RESULTS.md` |
| `fft_r2c()` on 2^20 real vs `stats::fft()` | at least 2× | met: 6.5× | met: 8.0× |
| `fft_c2c()` on prime 100 003 vs `stats::fft()` | at least 100× | met: 651× | met: 624× |

**The axis order matters in R.** In R's column-major arrays the contiguous
axis is the first. `fft_r2c()` of a 2048 × 2048 matrix took 26.5 ms
halving the last axis and 14.5 ms halving the first on the arm64 laptop,
and two threads sped up the first by 1.49× and the second by 1.82×. Since
D17 the default halves the first dimension, so the fast case is the
default; the 1.49× applies only when a caller lists the axes in order.

The misses are reported, not relaxed. It is within the 1.5× bound that
governs every grid point, it is a single 1-D complex transform on a shared
runner, and it is the case option (b) below addresses; Stage 8's full run
re-measures it.

**Where to expect a gap, and what to do about it.** The weakest cases
are single 1-D transforms below the four-step threshold (§6.5): ducc0
runs them scalar, FFTW's codelets are SIMD, and ducc0's README concedes
the 1-D comparison. fftwtools gives some of that back by planning on
every call; whether the net stays within 1.5× is the first measurement
Stage 1 makes. If it does not, the options in order are: (a) check that
the plan cache is hit and the shim adds no copy; (b) the opt-in native
build (§12.3) to confirm the gap is SIMD width; (c) the run-time dispatch
build of open question 3. A missed target is reported in this section,
not hidden by relaxing it.

## 12. Build, portability and CRAN

### 12.1 Threads on Windows: the go/no-go

SciPy builds ducc0 on MinGW-w64 with `DUCC0_NO_LOWLEVEL_THREADING`
(`scipy/fft/_duccfft/meson.build`: "mingw-w64 does not implement
pthread_pfork, needed by ducc_fft"), citing freezes with MinGW GCC's
threading (`mreineck/pocketfft` issue 1). CRAN's Windows binaries are
built with Rtools' MinGW-w64 GCC. zufft's own pool does not need
`pthread_atfork`, but it uses `std::thread`, `std::mutex` and
`std::condition_variable` from the same toolchain. Before the pool was
written, a stress test had to show that these primitives run many short
threaded regions on the Windows leg, repeatedly, without a hang. Had it
failed, zufft would build with `DUCC0_NO_LOWLEVEL_THREADING` on Windows
only and ignore `workers` above 1 there with a one-time warning.
fftwtools has no threads anywhere, so goal 2 does not depend on this
outcome.

**Outcome (Stage 2, 2026-10-13): go.** `src/zff_stress.cpp` builds pools
of `std::thread` workers that wait on a `std::condition_variable`, runs
short parallel regions through each, and tears the pool down: 200 pools
× 200 regions × 4 threads per process. The `portability` workflow ran 20
separate processes per OS on pedrobtz/zufft#17 with no hang and the
expected checksum every time:

| Runner | Runs | Min | Mean | Max |
| --- | --- | --- | --- | --- |
| windows-latest (Rtools 4.5, MinGW-w64 GCC) | 20 | 1.97 s | 2.03 s | 2.10 s |
| ubuntu-latest | 20 | 1.05 s | 1.08 s | 1.12 s |
| macos-latest | 20 | 0.61 s | 0.82 s | 0.92 s |

zufft therefore keeps threads on Windows, and `Makevars.win` equals
`Makevars`. The workflow stays in CI, so a toolchain change that brings
the hang back fails a pull request. SciPy's problem was ducc0's own pool,
which needs `pthread_atfork`; zufft's pool (Stage 6) uses `pthread_atfork`
only on POSIX (§6.5).

### 12.2 Everywhere

- C++17 for the vendored code and the shim (`CXX_STD = CXX17`,
  `SystemRequirements: C++17`), C99 for the glue; no system libraries, no
  `configure`.
- Hidden symbols (R3) need more than `-fvisibility=hidden`: in the
  drafting build the shared object still exported 65 symbols, all
  libstdc++ template instantiations and type information. A linker
  version script exporting only `R_init_zufft` removed them on Linux.
  The equivalents are `-exported_symbols_list` on macOS and a `.def` file
  on Windows. The question was whether the gain is worth a per-platform
  linker flag; if not, `$(CXX_VISIBILITY)` plus `attribute_visible` on
  `R_init_zufft` is accepted as "hidden enough".
  **Stage 1 outcome (2026-10-13):** `$(CXX_VISIBILITY)` and
  `$(C_VISIBILITY)` alone are used. With Apple clang 21 on macOS arm64 the
  installed shared object exports only `R_init_zufft`. On Linux the
  `build-flags` job lists the exported symbols in its log: 58 on
  ubuntu-latest with GCC, `R_init_zufft` and 57 libstdc++ template
  instantiations (`std::vector`, `std::function`, `std::shared_ptr`
  members). They are accepted, because a version script needs a
  platform-specific linker flag that portable `Makevars` cannot select
  without `configure`.
- SIMD is chosen at compile time from the compiler's macros
  (`infra/simd.h`): `__AVX512F__` gives 8 doubles per vector, `__AVX__`
  4, `__SSE2__` 2, `__ARM_NEON` 2, SVE its register width, otherwise
  scalar. GCC 12 or later with libstdc++ and not on Apple platforms uses
  `<experimental/simd>` instead of ducc0's own wrappers, at the same
  widths. Under CRAN's default flags that is SSE2 on x86-64 and NEON on
  arm64 (macOS arm64 included). No run-time dispatch and no `-m` flags in
  v0.1.0 (§12.3). `zufft_info()` reports the width and backend so a user
  can see what they got.
- Compile time and size, measured in Stage 1 with Apple clang 21 at
  R's `-O2` on an arm64 Mac: 2.9 s (`c2c`), 4.0 s (`r2c`/`c2r`) and 3.8 s
  (`dct`/`dst`) for the instantiation units, under 1 s for each other
  unit; a clean `R CMD INSTALL` takes 16 s. The shared object is 1.1 MB
  unstripped and the installed package 1.2 MB, above the 1 MB the first
  draft expected; R CMD check does not flag it.
- R's `Rcomplex` is a union of a `{ double r, i; }` struct and a C99
  complex in current R headers. `std::complex<double>` guarantees adjacent
  real and imaginary scalar access for a genuine `std::complex` array, but
  that does not by itself make an `Rcomplex` array a live
  `std::complex<double>` array or waive C++ aliasing and lifetime rules.
  There were therefore two accepted implementations: a zero-copy path only
  on compiler/platform combinations for which the representation and
  aliasing strategy are explicitly justified and exercised under LTO and
  sanitizers, or a portable marshal path that assigns each component into
  genuine `std::complex<double>` storage and copies results back; layout
  equality alone was not treated as proof.

  **Outcome (Stage 2, 2026-10-13): zero-copy on GCC and clang, marshal
  elsewhere.** The argument: the standard makes `std::complex<double>`
  array-compatible with `double[2]`; R's `Rcomplex` is a union of `{double
  r, i}` and a C99 `double _Complex`; libstdc++ stores
  `std::complex<double>` as a `double _Complex` and libc++ as two doubles,
  so the in-place view matches a member of the union on both standard
  libraries CRAN uses. The view is created only in the C++ shim
  (`src/zff_transform.cpp`), and the C glue never touches the same memory
  through another type during a call: crop is a strided view, and zero
  padding copies raw bytes with `memcpy`. The evidence, all green on
  pedrobtz/zufft#17: UBSan with clang and gcc, ASan with clang and gcc,
  LTO, valgrind and gctorture, each running a complex transform checked
  against `stats::fft()`. The marshal path is compiled when
  `ZFF_COMPLEX_MARSHAL` is defined or the compiler is neither GCC nor
  clang; a CI job builds it that way and runs the whole suite, so the
  fallback cannot rot. `zufft_info()$complex_path` reports which one a
  build uses.

### 12.3 Makevars

The goal is every optimisation ducc0's own build applies that CRAN
accepts, and nothing CRAN flags. The constraints, all verified against
R 4.6.1's `tools:::.check_packages` and `etc/Makeconf`:

- Under `--as-cran`, R scans the install log for flags and emits a NOTE
  "Compilation used the following non-portable flag(s)" for any `-m*`
  flag other than `-m32`, `-m64`, `-msse2`, `-mfpmath=sse`,
  `-mstackrealign` and `-mtune=*`; for `-ffast-math`,
  `-funsafe-math-optimizations`, `-fassociative-math` and
  `-freciprocal-math`; and for any `-W*` flag not in a short allow-list.
  `-Wno-*` or `-fno-diagnostics-show-option` escalate it to a WARNING.
  Flags not in those patterns, such as `-ffp-contract=fast`,
  `-fno-math-errno`, `-fvisibility=hidden` and `-O3`, pass the scan.
- **Separately, R checks `Makevars` itself** ("checking compilation flags
  in Makevars", `tools:::.check_make_vars`), and that check is a
  **WARNING**. It expands the `PKG_*FLAGS` variables without R's
  `Makeconf` and rejects every token matching `-O*`, `-W*`, `-w`,
  `-ansi`, `-pedantic`, `-f*`, `-m*`, `-std*`, `-g` and a few others.
  So no `-f` flag at all may be written into `PKG_CXXFLAGS`;
  `$(CXX_VISIBILITY)` passes only because it is a macro from `Makeconf`
  that the check does not expand. The first draft of this section missed
  this check; Stage 1 found it with R 4.6.1 (`-ffp-contract=fast
  -fno-math-errno` drew the WARNING).
- R's own flags come last: `ALL_CXXFLAGS = $(PKG_CXXFLAGS) $(CXXPICFLAGS)
  $(SHLIB_CXXFLAGS) $(CXXFLAGS) $(CXX_DEFS)`. An `-O3` in `PKG_CXXFLAGS`
  is therefore overridden by the site's `-O2`, and *Writing R
  Extensions* reserves the optimisation level to the user. zufft does not
  set one.
- `PKG_CPPFLAGS` is for `-I`, `-D` and, "where supported", `-pthread`;
  `PKG_CXXFLAGS` is for compiler flags; `Makevars` must be portable
  across `make` implementations (no GNU extensions, no targets) unless
  `SystemRequirements: GNU make` is declared. zufft avoids the
  declaration: three instantiation units are ordinary sources and need
  no pattern rules.
- R's `CXX17STD` is `-std=gnu++17`, so GCC's default `-ffp-contract=fast`
  is already in force with GCC; Clang (macOS) defaults to `on`
  (within a statement only).

ducc0's own C++ build (`CMakeLists-C++.txt`, Release) adds
`-ffp-contract=fast -fexcess-precision=fast -fno-math-errno
-fno-signed-zeros -fno-trapping-math -fassociative-math
-freciprocal-math` and `-march=native`, and links with LTO; the Python
build adds `-O3 -ffast-math` and `-march=native` under
`DUCC0_OPTIMIZATION=native`. The C++ file's comment on `-ffast-math`
is that "it breaks the code, and influences other software that depend on
ducc by changing the rounding mode"; in an R shared library that other
software is R itself, which settles it independently of CRAN's NOTE.

The resulting file (Stage 1):

```make
# src/Makevars
CXX_STD = CXX17

# -I. finds the vendored ducc0/ tree and the custom threading header;
# custom threading lets zufft own the pool (§6.5); -pthread where
# std::thread needs it (WRE §1.2.1 allows it in PKG_CPPFLAGS).
PKG_CPPFLAGS = -I. -DDUCC0_CUSTOM_LOWLEVEL_THREADING -pthread

# Hidden symbols, the way R's own Makeconf spells them; ZUFFT_CXXFLAGS is
# the opt-in native-build hook, empty unless the user sets it.
PKG_CXXFLAGS = $(CXX_VISIBILITY) $(ZUFFT_CXXFLAGS)
PKG_CFLAGS = $(C_VISIBILITY)
PKG_LIBS = -pthread
```

- **Contraction is now off (D18, after Stage 10).** The bullet below
  records why it was kept through Stage 10; switching it off cost 1–4% and
  made results independent of the thread count (§10). The pragma in
  `src/zff_fp_contract.h` now reads `#pragma clang fp contract(off)`;
  `Makevars` is unchanged.
- **Kept from ducc0 until D18: fused multiply-add contraction**, the one flag that
  matters for speed on hardware with FMA (every arm64 machine, and any
  x86-64 build with a user `-march`). It is also the main reason
  bit-for-bit equality with a build on another platform cannot be
  promised (D14). It cannot be a flag, so it is requested in the source:
  GCC already contracts across statements under R's `-std=gnu++17` (its
  default outside ISO mode is `-ffp-contract=fast`), and for clang each
  instantiation unit includes `src/zff_fp_contract.h` first, which issues
  `#pragma clang fp contract(fast)`. Stage 1 confirmed with Apple clang 21
  that the pragma reaches template code instantiated later in the file (a
  two-statement multiply-add compiled to one `fmadd`). It is not a
  diagnostic pragma, so R's pragma check does not apply.
- **Dropped from ducc0 because of the `Makevars` WARNING:**
  `-fno-math-errno`; it affects only the `sqrt` and trigonometric calls
  made while building a plan, not the transform loops.
  `-fvisibility-inlines-hidden` was not needed (the macOS build exports
  only `R_init_zufft` without it). `-fexcess-precision=fast` is x87-only
  and GCC-only.
- **Dropped from ducc0, with the reason:** `-ffast-math`,
  `-fassociative-math`, `-freciprocal-math` (CRAN NOTE; ducc0's own
  warning; process-wide floating-point state). `-fno-signed-zeros` and
  `-fno-trapping-math` (not NOTEd, but they change IEEE semantics for a
  gain nobody has measured for the FFT; Stage 1 may measure them and add
  them with a benchmark number in this section). `-O3` (overridden by R,
  reserved to the user). `-march=native` (CRAN NOTE; a binary built on
  the CRAN farm must run on every user's CPU).
- **Opt-in native build (revised after 0.1.0 readiness).** `PKG_CXXFLAGS`
  ends with `$(ZUFFT_CXXFLAGS)`, which `make` reads from the environment
  and which is empty unless the user sets it: `Sys.setenv(ZUFFT_CXXFLAGS =
  "-march=native")` before `install.packages("zufft", type = "source")`.
  It reaches only zufft, unlike `~/.R/Makevars`, and needs no `configure`.
  With the variable unset, R CMD check's "compilation flags in Makevars"
  and "compilation flags used" checks both pass, because the macro expands
  to nothing (verified with R 4.6.1); a `portability` CI job builds with it
  set on Linux, Windows and macOS, checks the flag reaches every C++
  compile and the vector width grows on x86-64, and checks the results.
  The README explains it, with the measured gain from §11. The first draft
  rejected reading an environment variable because `~/.R/Makevars` exists;
  the variable is preferred now because it is scoped to zufft.
- **`Makevars.win`** is the same file plus whatever §12.1 decides
  (`-DDUCC0_NO_LOWLEVEL_THREADING` if the go/no-go had failed; it did
  not, so the two files are identical). `-pthread` builds without a
  warning on every leg: Apple clang, Rtools' GCC on Windows, and GCC and
  clang on Linux (Stage 1 and 2 CI).
- **Checked in CI.** The r-actions check fails on the `Makevars` WARNING
  on every leg. The `build-flags` workflow runs `R CMD check --as-cran` on
  Linux and macOS and `tools/check-build-log` fails it on the
  non-portable-flags NOTE or any compiled-code NOTE (§10), so this file
  cannot drift.

**Run-time SIMD dispatch** (open question 3) is the only way to give
CRAN's x86-64 binaries AVX2 without a NOTE and without SIGILL on older
CPUs: compile the three instantiation units a second time with
`__attribute__((target("avx2,fma")))` or `#pragma GCC target` inside a
namespace, and pick at load time with `__builtin_cpu_supports`. It
doubles the compile time and the object size, needs GNU make for
per-object flags or pragma-based builds whose macro behaviour differs
between GCC and Clang, and helps only the shapes that are vectorised at
all (many lines, or long 1-D complex). It is not in v0.1.0; §11's numbers
decide whether it is worth a design.

## 13. Roadmap

| Stage | Title | Size |
| --- | --- | --- |
| 0 | Identity; vendor script and SPDX gate; Makevars as §12.3; custom threading; §12.1; symbol hiding; complex path; compile time and size | M |
| 1 | `c2c`, `r2c`, `c2r` over axes; `n`; `norm` with `"none"`; marshalling; first benchmark against fftwtools on the §11 grid | M |
| 2 | DCT and DST I–IV, inverses, `orthogonalize` | S |
| 3 | Lengths, frequencies, shifts; `fft_stats()`, `mvfft_stats()`; `fft_workers()` and its context helpers | S |
| 4 | The pool, `workers`, fork safety, thread tests; threaded benchmarks | M |
| 5 | The C table, `zufft.h`, the FIt-SNE-shaped fixture | S |
| 6 | SciPy fixtures, fftwtools oracle, identities, fuzzing, full benchmark run and `bench/RESULTS.md` | M |
| 7 | Documentation (reference, "Migrating from fftwtools" vignette, README with numbers) and release 0.1.0 | S |

## 14. Acceptance criteria for v0.1.0

1. `R CMD check --as-cran` clean on every CI leg, Windows included, with
   §12.1's outcome recorded, using at most two cores, and no
   "non-portable flag(s)" NOTE.
2. The SciPy fixtures and the fftwtools oracle pass within §10's
   tolerance on every leg.
3. `fft_stats()` and `mvfft_stats()` reproduce `stats::fft()` and
   `mvfft()`'s result structure exactly and their values within
   tolerance, including their help-page examples.
4. The §11 benchmark has run on at least one x86-64 Linux and one arm64
   macOS machine and every target is either met or reported as missed in
   §11 with the measured ratio.
5. A fixture package consumes the C table for a 2-D real convolution.
6. `tools/vendor/vendor-ducc` reproduces `src/ducc0/` byte for byte from the
   recorded commits, and the SPDX gate passes.
7. The sanitizer and LTO jobs pass. (The long-vector gate could not run,
   so the long-vector promise was removed from v0.1.0 in Stage 8.)
8. `DESCRIPTION`, `inst/COPYRIGHTS` and the vignette are in place as §8
   and §5.2 describe.

## 15. Decisions

| # | Question | Decision |
| --- | --- | --- |
| D1 | Home | standalone; `zufast` forbids C++ and compiled providers |
| D2 | Library | ducc0 FFT, SciPy's subset at SciPy's pinned commit |
| D3 | Not chosen | FFTW (GPL, system library); full ducc0 (GPL-2+); C++ pocketfft (SciPy's former engine; ducc0 is its successor) |
| D4 | Licence | BSD-3 option for vendored files; MIT for zufft's code; `ctb`/`cph` and `inst/COPYRIGHTS` |
| D5 | Glue | C, through a `noexcept` C++ shim |
| D6 | Threads | zufft's own lazy pool; default one worker |
| D7 | Provider | versioned C table plus a C header; no ducc0 headers |
| D8 | Precision | double only |
| D9 | Names | `fft_` prefix with fftwtools' `_c2c`/`_r2c`/`_c2r` suffixes; compatibility as `fft_stats()` |
| D10 | Axes | 1-based in R; NumPy axis `k` is R axis `k + 1`; `axes = 1` is column-wise |
| D11 | Info function | `zufft_info()`, the package name (R1) |
| D12 | Normalisation | SciPy's three plus `"none"`; default `"backward"` |
| D13 | Argument order | `x, inverse, n, axes, norm, …`; `fft_c2r(x, n)` |
| D14 | Bit-for-bit parity | withdrawn; tolerance only, so §12.3's flags are allowed |
| D15 | Build flags | no `-f`/`-m`/`-O` flag in `Makevars` (R warns); contraction off by a clang pragma (D18); native build through the opt-in `ZUFFT_CXXFLAGS` environment variable |
| D16 | Primary comparator | fftwtools, on §11's grid, within 1.5× |
| D17 | Real-transform default axes | `axes = NULL` halves the first dimension (R's contiguous axis); explicit `axes` halve the last listed, as SciPy |
| D18 | Contraction | off, so results are bit-identical whatever `workers` is; `zufft_info()$fp_contract` reports builds that still contract |

## 16. Open questions

1. **The name.** `zufft` or `zuducc`? Recommended: `zufft`; it names the
   job, and ducc0's other parts will never be in it.
2. **Masking.** Export `fft()` and `mvfft()` themselves, masking `stats`
   when attached, instead of `fft_stats()` and `mvfft_stats()`?
   Recommended: no; masking a `stats` function surprises every script
   that attaches zufft, and the one-token migration still works.
3. **Run-time SIMD dispatch on x86-64.** Build the instantiation units
   twice (SSE2 and AVX2+FMA) and choose at load time, as NumPy does?
   Recommended: decide from §11's numbers after Stage 1; if the opt-in
   native build is more than 1.3× faster than the portable one on the
   column-wise and 2-D cases, write the design; otherwise document the
   opt-in and stop.
4. **Track SciPy or ducc0?** Re-vendor only when SciPy does, or follow
   ducc0's releases? Recommended: SciPy; its review of each bump is a
   second check, and the fixtures are generated from it.
5. **Upstream fix.** Report the `in_parallel_region` gap in custom
   threading mode to ducc0? Recommended: yes, with the one-line fix;
   zufft's header keeps the workaround until a vendored commit has it.
6. **Single precision.** Add `float` members to the table now, for
   consumers such as an image pipeline? Recommended: only when one asks;
   it doubles the instantiation compile time.
7. **ducc0 headers for C++ consumers.** Offer them through `LinkingTo` for
   a consumer that needs inlined tiny transforms in an inner loop?
   Recommended: not in v0.1.0, for §7's reasons; revisit if such a
   consumer appears.
8. **`-fno-signed-zeros -fno-trapping-math`.** Add them if Stage 1
   measures a gain? Recommended: only with a number in §12.3 and a check
   that the fixtures still pass.

9. **Default axis order of the real transforms.** *Decided (D17):* with
   `axes = NULL` the real transforms halve the first dimension, aligned
   with R's column-major layout (and with fftwtools); an explicit `axes`
   still halves the last axis listed, as SciPy does.

10. **Contraction or thread-count independence.** *Decided (D18):*
   contraction off; results do not depend on `workers` (§10). The cost is
   1–4% on FMA hardware and nothing on CRAN's x86-64 builds.

## 17. What this RFC does not decide

- Whether `zutsne` takes the C table or another FFT; RFC 0028 decides
  that, and this RFC only makes the table fit FIt-SNE's three shapes.
- Whether `gsignal`, `pracma` or other users of `stats::fft()` or
  `fftwtools` switch.
- A non-uniform FFT for the family: ducc0's is GPL-only, so it would need
  another library and its own RFC.

## 18. Changes in the 2026-10-13 revision

- Goals restated: fftwtools replacement first, performance parity second,
  API third; the `zu*` family role is kept but no longer leads (§1, §3).
- fftwtools' API and C implementation read and recorded (§3.1); a
  migration table (§5.2) and a vignette added to scope.
- API: `inverse` moved to second position and `n` before `axes`;
  `norm = "none"` added; `with_fft_workers()` and `local_fft_workers()`
  added; fftwtools' `0`/`1` for `inverse` accepted (§5, D12, D13).
- Bit-for-bit promise withdrawn and the locked reference build removed
  from §10 (D14); the fftwtools oracle added.
- `Makevars` specified line by line against R's flag scan and `Makeconf`
  ordering, with ducc0's own flags as the starting point (§12.3, D15).
- ducc0's threading and vectorisation behaviour per shape recorded from
  `fftnd_impl.h` (§6.5) and used to set and explain the benchmark grid and
  targets (§11, D16).
- Licence trail made explicit: SPDX gate in CI, `Authors@R` roles,
  `Copyright:` field (§8, D4).

Review prepared with assistance from generative AI.
