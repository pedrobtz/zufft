# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

Verified 2026-10-13: Stage 1. The ducc0 FFT subset is vendored in
`src/ducc0/` and compiles; `zufft_info()` is the only export. No transform
is exposed yet, and the thread pool is a single-threaded placeholder until
Stage 6.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, titled with the bare version:
  [v0.1.0 (#2)](https://github.com/pedrobtz/zufft/issues/2).
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for
  example `Stage 3 — Fourier transforms`, and linking to that section.
- **Every tracking issue carries the `stage` label**, so it can be told apart
  from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the
  body of the stage's pull request. Never close a stage whose exit criteria
  are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages are
  done, not what a stage requires. Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change.
- Close the parent issue when CRAN accepts the version and it is tagged.
  Submission is tracked in
  [CRAN-submission (#14)](https://github.com/pedrobtz/zufft/issues/14).

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN
release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the
package enters `Pre-flight`. Bump to `0.1.0.9000` only after CRAN accepts it.

Until the first release the R API may change freely. The C table in
`inst/include/zufft.h` is different: `zutsne` will consume it, and a layout
change breaks it even before 0.1.0, so the table follows the append-only rules
of design §7.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
Rscript -e 'devtools::build_readme()'            # README.Rmd -> README.md
air format .                                     # format R sources
tools/vendor/verify                              # vendored tree vs manifest
```

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised
  input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "zufft_invalid_argument")` and the other classes
  of design §9.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the
  definition of done.
- **Oracles before hand-written cases.** `scipy.fft` fixtures, `fftwtools`
  (in `Suggests`, skipped when absent), `stats::fft()` and a direct O(n²) DFT
  (design §10).
- **Keep the suite inside the CRAN time budget** of 15 s.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0
warnings and 0 notes. The one allowed note is "New submission" before the first
release. `devtools::test(shuffle = TRUE)` green. CI green on every leg. A
user-facing change also needs a test, roxygen documentation and a `NEWS.md`
entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs
  `--as-cran` on the CRAN-like runners and containers, and it replaces
  win-builder, the macOS builder and R-hub. `cran-comments.md` lists the CI
  legs as its test environments.
- **The pretest is automated and does not read `cran-comments.md`.** Fix a
  NOTE instead of justifying it.
- **After acceptance,** tag `0.1.0`, publish the GitHub release, bump to
  `0.1.0.9000`, and close the version's parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- Edit `README.Rmd`, not the generated `README.md`.
- Keep prose simple and short. One idea per sentence. en-GB spelling.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`; internal native symbols use the `zff_` prefix, the
  public C API the `zufft_` prefix.
- Keep hard runtime dependencies at zero.

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
  `src/ducc0/`. zufft's adaptations live beside it: the custom threading
  header, the `.cc` wrappers and the instantiation units.
- **No `-f`, `-m` or `-O` flag in `Makevars`.** R CMD check warns about them
  ("checking compilation flags in Makevars"). Fused multiply-add contraction
  comes from `src/zff_fp_contract.h`, included first in each instantiation
  unit. `tools/check-build-log` fails CI on non-portable flags and on any
  compiled-code NOTE (abort, exit, stdio).
- Every holder named in the bundled files is in `Authors@R` and
  `inst/COPYRIGHTS`; a re-vendor must re-check that list.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned to `@v1`: `r-cmd-check.yml`
(quick on pull requests, full on `main`, full on a pull request with the
`full-ci` label), `coverage.yml`, `vendor.yml` and the pkgdown workflow.
`build-flags.yaml` is local: it fails on the NOTEs r-actions lets through.

## Commits and pull requests

Short, imperative, sentence-case commit subjects. Keep each commit focused. A
pull request explains the user-visible outcome and the rationale, links
related issues, lists the checks that were run and the tests that were
skipped, and flags platform-sensitive or vendored changes. Performance claims
need evidence.
