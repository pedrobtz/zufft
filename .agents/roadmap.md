# zufft: roadmap

Status: draft 2026-10-13. Implements [design.md](design.md) (RFC 0026,
revised 2026-10-13).
Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#2)](https://github.com/pedrobtz/zufft/issues/2), with one
sub-issue per stage;
[CRAN-submission (#14)](https://github.com/pedrobtz/zufft/issues/14).

Where the package stands today (verified 2026-10-13): a `usethis` skeleton.
`DESCRIPTION` has placeholder Title, Description and author; `License: MIT +
file LICENSE` with "zufft authors" as holder; `src/zufft.c` is an empty
translation unit; one placeholder test; `R-CMD-check`, `coverage` and
`pkgdown` workflows already call `pedrobtz/r-actions` at `@v1`;
`.Rbuildignore` already excludes `.agents`. Nothing of ducc0 is vendored and
nothing has been built under R.

The design's §13 table had eight stages. This roadmap splits its Stage 0
into three (identity, vendoring and build, portability spikes) so that each
is one pull request, and adds the documentation and readiness stages the
portfolio requires. Stage numbers below are the roadmap's, not the design's.

## Stages

| Stage | Title | Issue | Pull request | Done |
| --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | [#3](https://github.com/pedrobtz/zufft/issues/3) | [#15](https://github.com/pedrobtz/zufft/pull/15) | 2026-10-13 |
| 1 | [Vendored ducc0 and the build](#stage-1--vendored-ducc0-and-the-build) | [#4](https://github.com/pedrobtz/zufft/issues/4) | [#16](https://github.com/pedrobtz/zufft/pull/16) | 2026-10-13 |
| 2 | [Portability spikes](#stage-2--portability-spikes) | [#5](https://github.com/pedrobtz/zufft/issues/5) | [#17](https://github.com/pedrobtz/zufft/pull/17) | 2026-10-13 |
| 3 | [Fourier transforms](#stage-3--fourier-transforms) | [#6](https://github.com/pedrobtz/zufft/issues/6) | [#18](https://github.com/pedrobtz/zufft/pull/18) | 2026-10-13 |
| 4 | [Cosine and sine transforms](#stage-4--cosine-and-sine-transforms) | [#7](https://github.com/pedrobtz/zufft/issues/7) | | |
| 5 | [Helpers and stats compatibility](#stage-5--helpers-and-stats-compatibility) | [#8](https://github.com/pedrobtz/zufft/issues/8) | | |
| 6 | [Thread pool](#stage-6--thread-pool) | [#9](https://github.com/pedrobtz/zufft/issues/9) | | |
| 7 | [C table](#stage-7--c-table) | [#10](https://github.com/pedrobtz/zufft/issues/10) | | |
| 8 | [Conformance and benchmarks](#stage-8--conformance-and-benchmarks) | [#11](https://github.com/pedrobtz/zufft/issues/11) | | |
| 9 | [Documentation](#stage-9--documentation) | [#12](https://github.com/pedrobtz/zufft/issues/12) | | |
| 10 | [v0.1.0 readiness](#stage-10--v010-readiness) | [#13](https://github.com/pedrobtz/zufft/issues/13) | | |

## Stage 0 — Package identity

**Issue.** [#3](https://github.com/pedrobtz/zufft/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** The repository says what zufft is and who wrote it, and a reader
can orient from `CLAUDE.md` without the design.

**Work.**
- `DESCRIPTION`: Title "Fast Fourier, Cosine and Sine Transforms with
  ducc0" (or close), a Description that names the fftwtools-without-FFTW
  purpose and the BSD-licensed ducc0 subset, `Authors@R` with Pedro Baltazar
  as `aut`, `cre` and `cph`, `Depends: R (>= 4.1)`, `Language: en-GB`,
  `URL` and `BugReports`. The ducc0 `ctb`/`cph` entries and the
  `Copyright:` field arrive with the code in Stage 1.
- `LICENSE` and `LICENSE.md`: the real copyright holder and year.
- `CLAUDE.md` from `templates/package-CLAUDE.md` in `pedrobtz/packages`,
  pointing at `.agents/design.md` as the specification and at this roadmap
  and its parent issue for stage tracking.
- `README.Rmd` (and the knitted `README.md`) with the purpose, the three
  goals of design §1, installation, and a "not yet usable" notice dated.
- `NEWS.md` kept at "development version"; placeholder test removed in
  favour of a `zufft_info()` smoke test once Stage 1 lands (leave the
  placeholder until then so `R CMD check` has a test).
- Confirm the `stage` label exists and that `.Rbuildignore` covers
  `.agents`, `README.Rmd`, `bench`, `tools` and `cran-comments.md`.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs with no NOTE other than "New
  submission".
- `DESCRIPTION` has no placeholder text; `desc::desc_normalize()` leaves it
  unchanged.
- `CLAUDE.md` exists with the template's two header lines verbatim and no
  `{placeholder}` left.
- `README.md` is generated from `README.Rmd` and renders on GitHub.

**Design.** §3.3 (family table), §15 D1, D9, D11; open question 1 (the
name) is settled by merging this stage with `Package: zufft`.

## Stage 1 — Vendored ducc0 and the build

**Issue.** [#4](https://github.com/pedrobtz/zufft/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** The 17-file ducc0 subset compiles inside the package on every CI
leg with the `Makevars` of design §12.3, its provenance and licence are
machine-checked, and `zufft_info()` reports what was built. No transform is
exposed yet.

**Work.**
- `tools/vendor/vendor-ducc`: fetches ducc0 at the commit SciPy's
  `tools/vendoring/vendor_duccfft.sh` pins, keeps only the 17 listed files,
  fails if any file lacks the "BSD-3-Clause OR GPL-2.0-or-later" SPDX line
  or is not in the list, checks byte-identity with SciPy's
  `subprojects/duccfft` at a named SciPy commit, writes
  `tools/vendor/manifest.tsv` (both commits),
  `tools/vendor/checksums.sha256` (per-file SHA-256) and
  `src/zff_version.h`; `tools/vendor/verify` checks the tree offline.
- `src/ducc0/` populated by the script; `src/ducc0_custom_lowlevel_threading.h`
  with the standard-library `Mutex`, `LockGuard`, `UniqueLock`, `CondVar`
  and the `in_parallel_region` workaround; a single-threaded placeholder
  `set_active_pool()`/`get_active_pool()` until Stage 6.
- Three instantiation translation units (`c2c`; `r2c` and `c2r`; `dct` and
  `dst`) for `double`, and the `extern "C"` shim skeleton
  (`src/zff_shim.cpp`) with the status enum and thread-local message of §7
  but no transform entry points yet.
- `src/Makevars` and `src/Makevars.win` as design §12.3 (`CXX_STD =
  CXX17`, `PKG_CPPFLAGS` with `-DDUCC0_CUSTOM_LOWLEVEL_THREADING` and
  `-pthread`, `PKG_CXXFLAGS = $(CXX_VISIBILITY)`, `PKG_LIBS = -pthread`),
  with fused multiply-add contraction requested by a clang pragma in the
  instantiation units; whether `-pthread` is needed or harmful on each leg
  is recorded in the pull request and §12.3.
- `zufft_info()` returning ducc0 commit, SciPy commit, SIMD backend and
  width, FMA contraction, threading mode, pool size, complex path
  (reported as "undecided" until Stage 2).
- `DESCRIPTION`: `SystemRequirements: C++17`, `ctb` for Martin Reinecke,
  `ctb`/`cph` for Peter Bell, `cph` for the Max-Planck-Society, `Copyright:
  see inst/COPYRIGHTS`; `inst/COPYRIGHTS` with the BSD-3 text and the
  Frigo/MIT notice.
- A CI job that re-runs the SPDX gate on every pull request, and a CI step
  that fails on the "non-portable flag(s)" NOTE in the `--as-cran` log.
- Compile time per unit and installed size recorded in design §12.2.

**Exit criteria.**
- `R CMD check --as-cran` passes on all r-actions legs, Windows included,
  with no "non-portable flag(s)" NOTE and no compiler warnings on the GCC
  and clang container legs.
- `tools/vendor/vendor-ducc` run twice in a row leaves `src/ducc0/` unchanged
  (`git status` clean); the SPDX gate fails when a file with a GPL-only
  header is placed in `src/ducc0/` (tested in CI with a throwaway file).
- `zufft_info()` reports the two commits that `tools/vendor/manifest.tsv` holds
  and a SIMD width of 2 on the x86-64 and arm64 legs.
- The installed shared object exports only `R_init_zufft` on Linux, or the
  pull request records why `$(CXX_VISIBILITY)` alone was accepted (§12.2).
- `inst/COPYRIGHTS` and `DESCRIPTION` carry every holder named in the
  vendored headers.

**Design.** §8, §12.2, §12.3, §15 D2–D4, D15; open questions 4 and 5
(track SciPy; report `in_parallel_region` upstream) are acted on here.

**Deviations (2026-10-13).**
- The vendoring files live under `tools/vendor/` with a manifest, a
  checksum list and a generated `src/zff_version.h`, instead of
  `tools/vendor-ducc` and `src/ducc0/VERSION`, to match the defaults of
  r-actions' `vendor.yml`.
- R CMD check warns ("checking compilation flags in Makevars") about every
  `-f` flag in `PKG_CXXFLAGS`, which design §12.3 had missed. Makevars
  therefore carries no `-ffp-contract=fast`, `-fno-math-errno` or
  `-fvisibility-inlines-hidden`; contraction comes from GCC's default and
  a clang pragma. Design §12.3 and D15 are updated.
- One patch to a vendored file, against design §8's "no patches":
  ducc0's `MR_fail`/`MR_assert` use the GNU `, ##__VA_ARGS__`, which clang
  `-pedantic` (CRAN's debian-clang C++ flags) reports as a significant
  warning. `tools/vendor/patches/0001-error-handling-no-gnu-va-args.patch`
  replaces it; the vendor tool applies it and `verify` checks it.
- The `in_parallel_region` report to ducc0 (open question 5) is not filed
  from this stage: ducc0's tracker is on the Max-Planck GitLab and filing
  is an outward-facing action left to the maintainer. The workaround is in
  `src/ducc0_custom_lowlevel_threading.h`, and the pull request body
  carries the text of the report.

## Stage 2 — Portability spikes

**Issue.** [#5](https://github.com/pedrobtz/zufft/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** The two go/no-go questions the design puts before feature work
are answered with evidence and written into `design.md`: threads on
Windows, and the `Rcomplex` path.

**Work.**
- A stress test (hidden, under `tests/testthat/` and guarded by an
  environment variable so the CRAN suite stays short) that creates
  `std::thread` workers with `std::mutex` and `std::condition_variable`
  through the shim, runs thousands of short parallel regions, and joins
  them; run in a loop on the Windows leg (§12.1).
- Two implementations of the complex boundary (§12.2): a zero-copy path
  that views `Rcomplex` storage as `std::complex<double>`, and a marshal
  path that copies into genuine `std::complex<double>` storage. Both
  exercised by a scratch `c2c` call under AddressSanitizer,
  UndefinedBehaviorSanitizer and LTO on the Linux legs.
- r-actions sanitizer and LTO jobs wired into the workflow (full profile
  only).
- `design.md` §12.1 and §12.2 updated with the outcome: threads on Windows
  on or off; which compilers get the zero-copy path and on what argument;
  `zufft_info()` reports the chosen complex path.

**Exit criteria.**
- The Windows stress loop completes without a hang on at least 20
  consecutive runs, or `Makevars.win` carries
  `-DDUCC0_NO_LOWLEVEL_THREADING` and §12.1 records the failure.
- Sanitizer and LTO jobs are green on the chosen complex path.
- `design.md` has no "Stage 0 settles" or "unverified" wording left in
  §12.1 and §12.2 about these two questions.

**Design.** §12.1, §12.2.

## Stage 3 — Fourier transforms

**Issue.** [#6](https://github.com/pedrobtz/zufft/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** `fft_c2c()`, `fft_r2c()` and `fft_c2r()` work on vectors and
arrays over any axes with `n`, `norm` (all four values) and the error
classes of §9, single-threaded, and the first benchmark against fftwtools
is recorded.

**Work.**
- C glue (`src/zff_*.c`): argument marshalling, output allocation with
  `R_xlen_t` lengths, crop and zero-pad into the output buffer, overflow
  checks on shape products and byte counts, `dimnames` handling.
- Shim entry points for `c2c`, `r2c`, `c2r`; `fft_c2c()` on real input via
  `r2c` plus the Hermitian fill in C; the `norm` factor computed in `long
  double` as `pyduccfft.cxx` does, `fct = 1` for `"none"`.
- R functions with the §5.1 signatures and argument order; `inverse`
  accepting `0`/`1`; `workers` validated (positive, or `-k`) but only `1`
  executed until Stage 6 (any other value runs single-threaded with no
  warning, documented as such in `NEWS.md` until the pool lands).
- Condition classes `zufft_error`, `zufft_invalid_argument`,
  `zufft_length_error`, `zufft_engine_error`, `zufft_internal_error`.
- Tests: direct O(n²) DFT for `n <= 64`, `stats::fft()` and `mvfft()`
  oracle within the §10 tolerance for lengths 1–1024 and random arrays,
  inverse round trips for every `norm`, Hermitian symmetry on real input,
  odd and even `c2r`, `dimnames`, every error class.
- `tools/run-benchmarks` with the §11 grid for the three transforms,
  `fftwtools` in `Suggests`, first results for `workers = 1` on one x86-64
  Linux and one arm64 macOS machine in `bench/RESULTS.md`; design §11
  updated with the ratios, met or missed.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs; the CRAN suite runs under 15 s.
- Every §5.2 row that involves only `c2c`, `r2c`, `c2r` passes against
  fftwtools when it is installed (skipped otherwise).
- `bench/RESULTS.md` exists with the single-threaded grid, and §11 states
  the measured ratio against fftwtools for every grid point.
- No `int` sits between `R_xlen_t` and `size_t` in the glue (checked by
  review; a 2^31 + 1 length test is deferred to the Stage 8 gate).

**Design.** §4, §5.1, §5.2, §6.1–6.4, §9, §11, §15 D5, D12, D13, D16.

## Stage 4 — Cosine and sine transforms

**Issue.** [#7](https://github.com/pedrobtz/zufft/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** `fft_dct()` and `fft_dst()` types I–IV, forward and inverse,
with `norm`, `orthogonalize` and SciPy's complex-input rule.

**Work.**
- Shim entry points for `dct` and `dst`; the per-axis `N` for `norm`
  (`2(n - 1)` for DCT-I, `2(n + 1)` for DST-I, `2n` otherwise); `inverse`
  swapping types II and III and the normalisation direction.
- `orthogonalize = NULL` meaning `norm == "ortho"`; complex input
  transformed as two real transforms with the §6.1 rule and its regression
  test.
- Minimum length checks (`zufft_length_error` below 1, below 2 for DCT-I).
- Tests: direct sums for `n <= 64`; DCT-II/DCT-III inverse pair; DCT-II
  equal to an FFT of the even extension; round trips for every type and
  `norm`.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs.
- Every DCT and DST type passes the direct-sum test and the round-trip
  test under all four `norm` values.
- The complex-input `orthogonalize` behaviour is covered by a test that
  fails if the explicit argument is honoured.

**Design.** §5.1, §6.1, §6.3.

## Stage 5 — Helpers and stats compatibility

**Issue.** [#8](https://github.com/pedrobtz/zufft/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** The rest of the R surface exists: length, frequency and shift
helpers, `fft_stats()` and `mvfft_stats()`, and the `workers` accessors.

**Work.**
- `fft_next_len()`, `fft_prev_len()` (ducc0's `good_size_complex` and
  `good_size_real`; the downward search ported from `pyduccfft.cxx`),
  `fft_freq()`, `fft_rfreq()`, `fft_shift()`, `fft_ishift()`.
- `fft_stats()` and `mvfft_stats()` as thin wrappers with `stats::fft()`'s
  and `mvfft()`'s argument checks, shapes, attributes, length-0 and
  length-1 behaviour, unnormalised inverse.
- `fft_workers()`, `with_fft_workers()`, `local_fft_workers()` storing the
  default in an atomic read by the C layer (still executing on one thread
  until Stage 6).
- Tests: `fft_next_len()` against the two values recorded in §6.2 and
  against `scipy.fft.next_fast_len` fixtures for 1–10 000; `fft_stats()`
  reproducing `stats::fft()`'s help-page examples structure-exactly;
  `with_fft_workers()` restoring the old value on error.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs.
- Every function in design §5.1 is exported, documented and tested.
- `fft_stats()` and `mvfft_stats()` pass `expect_identical()` on structure
  and the tolerance on values for `stats::fft()`'s examples.

**Design.** §5.1, §5.3, §6.2, §6.5 (accessors), §15 D9; open question 2
(masking) is settled as "no" by merging this stage.

## Stage 6 — Thread pool

**Issue.** [#9](https://github.com/pedrobtz/zufft/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** `workers > 1` runs ducc0's parallel regions on zufft's own lazy
pool, safely across forks and unload, within CRAN's two-core rule.

**Work.**
- The pool behind `DUCC0_CUSTOM_LOWLEVEL_THREADING`: no thread until a
  call asks for more than one, grows to the largest request, never shrinks,
  never pins; the process-wide entry gate; `-1` and `-k` semantics; caps at
  available cores and at 2 under `_R_CHECK_LIMIT_CORES_`.
- `pthread_atfork` handlers on POSIX as §6.5 specifies; `R_unload_zufft`
  joining every worker.
- `zufft_thread_error` when a thread cannot start.
- Tests: `workers = 1` versus `workers = 2` results identical on the §10
  shapes; repeated pool creation and `unloadNamespace()`;
  `parallel::mclapply()` before and after pool creation on every POSIX
  leg; the Windows outcome of Stage 2 respected (warning once if threads
  are off there).
- Threaded rows of the §11 grid added to `bench/RESULTS.md`; the
  2048 × 2048 `workers = 2` target measured.

**Exit criteria.**
- `R CMD check` passes on all r-actions legs with at most two cores in use.
- Fork tests pass on Linux and macOS legs; thread tests pass on Windows or
  are skipped with the recorded §12.1 reason.
- The `workers = 2` speed-up on the 2048 × 2048 real 2-D transform is
  recorded in §11, met or missed.
- No thread is started by a session that never asks for `workers > 1`
  (asserted by a test reading `zufft_info()$pool_size`).

**Design.** §6.5, §15 D6.

## Stage 7 — C table

**Issue.** [#10](https://github.com/pedrobtz/zufft/issues/10), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** Other packages can call zufft's transforms from C through
`LinkingTo: zufft`, as `zutsne` will.

**Work.**
- `inst/include/zufft.h` as §7: `zufft_layout`, `zufft_status`,
  `zufft_api` with `struct_size`, `abi_version = 1`, the five transform
  members, `good_size`, `message`, the normalisation enum and the
  overflow-checked scale helper, and `zufft_api_get()` resolving the
  registered getter function.
- Registration in `R_init_zufft`; layout validation (unique in-range axes,
  nonzero shapes, `ptrdiff_t` overflow, self-overlap, no negative
  strides), in-place `c2c`, non-overlap rule for `r2c`/`c2r`, thread-local
  diagnostics, `nthreads = 0` reading the atomic default.
- A fixture package under `tests/` (not installed) that performs FIt-SNE's
  2-D convolution through `r2c`, Hadamard product and `c2r`, plus the
  in-place 1-D `c2c` pair, and checks getter resolution, `struct_size`,
  status constants, malformed layouts, overflow rejection, forbidden
  overlap and diagnostics.
- `zufuzz` targets for shapes, strides and axes through the table (run in
  CI, not on CRAN).

**Exit criteria.**
- `R CMD check` passes on all r-actions legs, and the fixture package
  installs and passes against the checked zufft on each leg.
- The header compiles standalone as C99 and as C++17.
- Every `zufft_status` value is produced by at least one test.

**Design.** §7, §15 D7, D8.

## Stage 8 — Conformance and benchmarks

**Issue.** [#11](https://github.com/pedrobtz/zufft/issues/11), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** The compatibility statement of §1 is tested, not asserted: SciPy
fixtures, the fftwtools oracle, the identities, fuzzing, and the full
benchmark grid.

**Work.**
- `tools/make-scipy-reference.py` and the fixtures under
  `tests/testthat/fixtures/` (1 MB budget) with the manifest of §10,
  generated from a locked environment at SciPy commit `ecee36d`;
  regeneration fails if SciPy no longer vendors the recorded ducc0 commit.
- Fixture tests for every transform, type, `norm`, `orthogonalize`, axis
  subset, crop and pad, odd and even `c2r`, and validation failures,
  within the §10 tolerance.
- The full fftwtools oracle: every §5.2 row, both `HermConj` values,
  `norm = "none"` inverses.
- Parseval, linearity, shift theorem tests; Valgrind on the Linux leg;
  sanitizer and LTO jobs covering the shim and C-table tests.
- The complete `tools/run-benchmarks` grid with `workers = 1` and `2`,
  `fftw` where installed, FFTW configuration and `zufft_info()` recorded;
  `bench/RESULTS.md` and design §11 updated with every ratio.
- The manual long-vector release gate (a transform of more than 2^31
  elements) run once on a large runner, or the long-vector promise removed
  from design §2 and the long-vector tests dropped.

**Exit criteria.**
- All fixture tests pass within tolerance on every r-actions leg.
- The CRAN suite still runs under 15 s; the long tests are gated behind
  `NOT_CRAN` or an environment variable.
- Design §11 states, for each target, met or missed with the measured
  ratio; a missed target is listed in §11 and not relaxed.
- The long-vector gate has run, or §2 and §14 no longer claim long vectors.

**Design.** §10, §11, §14 items 2, 4, 6 and 7.

## Stage 9 — Documentation

**Issue.** [#12](https://github.com/pedrobtz/zufft/issues/12), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** A fftwtools or scipy.fft user can switch from the documentation
alone.

**Work.**
- Reference pages for every exported function, with the §5.1 argument
  semantics, cross-references between the transform families, and examples
  that run under 1 s each.
- Vignette "Migrating from fftwtools": the §5.2 table with a worked
  example per row, `norm = "none"` explained, `HermConj` mapped.
- Vignette or article "zufft for scipy.fft users": the §5.4 table, axis
  numbering, `reticulate` round trip.
- `README.Rmd`: purpose, installation, a short example, the benchmark
  headline numbers from `bench/RESULTS.md`, the opt-in native build with
  its measured gain, licence statement for the vendored code.
- `_pkgdown.yml` reference grouping (transforms, real transforms, helpers,
  threads, compatibility, package info); pkgdown site building in CI.

**Exit criteria.**
- `R CMD check` passes with no undocumented objects or usage mismatches
  on all legs.
- Both vignettes build in CI and their code runs.
- `README.md` is regenerated from `README.Rmd` and every number in it
  appears in `bench/RESULTS.md`.
- The pkgdown site deploys from the default branch.

**Design.** §2 (vignette in scope), §5.2, §5.4, §12.3 (opt-in build).

## Stage 10 — v0.1.0 readiness

**Issue.** [#13](https://github.com/pedrobtz/zufft/issues/13), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zufft/issues/2).

**Goal.** Only the submission itself is left.

**Work.**
- `Version: 0.1.0` and a `# zufft 0.1.0` heading in `NEWS.md` listing the
  user-facing surface.
- `cran-comments.md` listing the r-actions CI legs (macOS, Windows, Ubuntu
  release and oldrel-1, r-devel Debian clang and GCC containers) as the
  test environments; no win-builder, macOS builder or R-hub steps.
- The `pkg-cran-review` skill run, every finding resolved.
- `urlchecker::url_check()` and `spelling::spell_check_package()` clean
  (en-GB word list in `inst/WORDLIST`).
- Design §14 walked item by item with the evidence linked in the pull
  request.

**Exit criteria.**
- A full-profile r-actions run is green on the release commit.
- `R CMD check --as-cran` shows no NOTE other than "New submission" on any
  leg.
- Every §14 acceptance criterion is checked off in the pull request
  description with a link to its evidence.
- `CLAUDE.md` "Current state" is updated and dated.

**Design.** §14.

## After 0.1.0

- Hermitian (`hfft`, `ihfft`) and Hartley transforms: in the vendored
  subset already, no user has asked (design §2).
- Single precision in the C table: doubles instantiation compile time
  (design §16 question 6).
- `convolve_axis` resampling (design §2).
- Plan or workspace objects, only if profiling shows the ten-entry cache
  and the 2^20 size limit hurt (design §2).
- Run-time SIMD dispatch for x86-64 CRAN binaries: decided from the Stage 3
  and Stage 8 numbers (design §12.3, §16 question 3).
- Removing the process-wide entry gate for concurrent top-level
  transforms: needs its own concurrency design (design §6.5).
- `-fno-signed-zeros -fno-trapping-math`: only with a measured gain
  (design §16 question 8).
- ducc0 headers through `LinkingTo` for C++ consumers (design §16
  question 7).

## Open questions

- **Threads on Windows** (design §12.1) blocks the shape of Stage 6 and
  `Makevars.win`; Stage 2 answers it.
- **The `Rcomplex` path** (design §12.2) blocks Stage 3's complex glue;
  Stage 2 answers it.
- **Is `-pthread` right on every leg** (design §12.3) is settled inside
  Stage 1 by CI.
- **Whether single 1-D transforms land within 1.5× of fftwtools** (design
  §11) is Stage 3's first measurement; a miss does not block the stage but
  opens the run-time dispatch question for after 0.1.0.
- **The long-vector release gate** (design §10) needs a runner with about
  50 GB; if none is available by Stage 8, long vectors leave the 0.1.0
  scope.
