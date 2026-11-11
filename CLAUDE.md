# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for zufft.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/native-code.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

zufft is an R package for fast Fourier, cosine and sine transforms. It is
meant to replace `fftwtools` without FFTW: it bundles the BSD-licensed FFT
subset of ducc0, the same files and commit SciPy vendors, so it needs no
system library and carries no GPL code. The R API follows `scipy.fft`
conventions (axes, `norm`, transform types) with names a fftwtools user
recognises (`fft_c2c()`, `fft_r2c()`, `fft_c2r()`). It is also a provider: a
registered C table lets other packages, first `zutsne`, call the transforms
from C. Zero hard runtime dependencies.

[.agents/design.md](.agents/design.md) is the specification and outranks this
file. [.agents/roadmap.md](.agents/roadmap.md) is the stage plan with exit
criteria.

## Current state

Verified 2026-11-04: 0.1.0 is on CRAN, published 2026-10-22 and tagged
`0.1.0`; `main` is `0.1.0.9000`. The next version is tracked in
[v0.1.1 (#37)](https://github.com/pedrobtz/zufft/issues/37).
Design questions 9 and 10 are decided: the real transforms halve the first
dimension by default, and fused multiply-add contraction is off so results
do not depend on `workers`.
Benchmarks against fftwtools are in `bench/RESULTS.md`.

## Versions and dependents

The C table in `inst/include/zufft.h` is consumed by `zutsne`, and a layout
change breaks it even before a release, so the table follows the append-only
rules of design §7.

zufft has no `cran-release.yaml` yet, so `CRAN-SUBMISSION` is still
git-ignored and a release is tagged by hand with `pkg-post-cran`, not as
`.claude/shared/workflow.md` describes.

## Commands

Beyond the shared `devtools` commands:

```sh
Rscript -e 'devtools::build_readme()'            # README.Rmd -> README.md
tools/vendor/verify                              # vendored tree vs manifest
tools/run-benchmarks --quick                     # design §11 grid, short
```

`tools/run-benchmarks` needs zufft installed, plus `bench` and, for the
comparison, `fftwtools` (system FFTW). The `benchmark` label on a pull
request runs the full grid on a Linux runner.

## Testing

- Condition classes are those of design §9, for example
  `expect_error(..., class = "zufft_invalid_argument")`.
- **Oracles before hand-written cases.** `scipy.fft` fixtures, `fftwtools`
  (in `Suggests`, skipped when absent), `stats::fft()` and a direct O(n²) DFT
  (design §10).
- The CRAN time budget for the suite is 15 s.

## Editing rules

- en-GB spelling.
- Internal native symbols use the `zff_` prefix, the public C API the
  `zufft_` prefix.

## Invariants that are easy to break

- **Complex memory is touched only through std::complex in C++.** The
  zero-copy path (design §12.2) is justified on that condition. C glue may
  pass `COMPLEX(x)` as a pointer, crop by strides, and copy bytes with
  `memcpy`, but must not read or write complex elements as doubles while a
  shim call can see them. `ZFF_COMPLEX_MARSHAL` builds the copying fallback;
  CI keeps it passing.
- **Every shim entry point holds the entry gate (`call_gate`) around its
  ducc0 calls.** It serialises top-level transforms and grows the pool;
  ducc0's plan cache and the fork handlers rely on it.
- **Never unregister or bypass the fork handlers.** `zff_pool.cpp` pins the
  shared object with `RTLD_NODELETE` because `pthread_atfork` handlers
  outlive an unload (`devtools::load_all()` reloads).
- **`inst/include/zufft.h` is a public ABI.** Append members only, keep the
  status values, and keep it compiling standalone as C99 and C++17
  (`tools/check-header`); `zutsne` will depend on it before 0.1.0.
- **Nothing in the shim or on a pool thread calls R.** Errors cross as a
  status code and a thread-local message; `zff_raise()` in the C glue turns
  them into classed R conditions.

## Vendored native code

`src/ducc0/` is the FFT component of ducc0, exactly the 17 files SciPy
vendors in `subprojects/duccfft` (dual "BSD-3-Clause OR GPL-2.0-or-later";
zufft elects BSD-3). The rest of ducc0 is GPL-only: never copy anything else
in.

- **Update only through the tool:** `tools/vendor/vendor-ducc [SCIPY_COMMIT]`
  takes the ducc0 commit SciPy pins, checks every file against SciPy's copy
  and the SPDX line, and rewrites `src/ducc0/`, `tools/vendor/manifest.tsv`,
  `tools/vendor/checksums.sha256` and `src/zff_version.h`. Re-vendor only
  when SciPy does (design §8).
- `tools/vendor/verify` is the offline check CI runs; never edit a file in
  `src/ducc0/`. Changes to vendored files go in `tools/vendor/patches/`,
  each with its reason; there are two, for clang `-pedantic` (CRAN's
  debian-clang flavor) and for a UBSan finding in the DCT/DST plans.
  zufft's adaptations live beside it: the custom threading header, the `.cc`
  wrappers and the instantiation units.
- **`$(ZUFFT_CXXFLAGS)` in `PKG_CXXFLAGS` is the opt-in native-build hook.**
  It must stay empty by default (never give it a value in `Makevars`), so
  CRAN sees only R's flags; the `portability` workflow's native job builds
  with it set.
- **No `-f`, `-m` or `-O` flag in `Makevars`.** R CMD check warns about them
  ("checking compilation flags in Makevars"). Fused multiply-add contraction
  is switched off by `src/zff_fp_contract.h`, included first in each
  instantiation unit. `tools/check-build-log` fails CI on non-portable flags
  and on any compiled-code NOTE (abort, exit, stdio).
- Every holder named in the bundled files is in `Authors@R` and
  `inst/COPYRIGHTS`; a re-vendor must re-check that list.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned to `@v1`: `r-cmd-check.yml`
(quick on pull requests, full on a pull request with the `full-ci` label,
and full on every push to `main`, a deviation from `.claude/shared/ci.md`,
whose callers run quick there), `coverage.yml`, `vendor.yml` and the pkgdown
workflow.
`build-flags.yaml` is local: it fails on the NOTEs r-actions lets through.
The coverage badge is committed to `gh-pages` (`badges/coverage.svg`), because
the `main` ruleset takes no direct pushes; the pkgdown deploy must not
force-push or clean that branch.
