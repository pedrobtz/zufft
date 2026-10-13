# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## What this is

zufft is an R package for fast Fourier, cosine and sine transforms. It
is meant to replace `fftwtools` without FFTW: it bundles the
BSD-licensed FFT subset of ducc0, the same files and commit SciPy
vendors, so it needs no system library and carries no GPL code. The R
API follows `scipy.fft` conventions (axes, `norm`, transform types) with
names a fftwtools user recognises (`fft_c2c()`, `fft_r2c()`,
`fft_c2r()`). It is also a provider: a registered C table lets other
packages, first `zutsne`, call the transforms from C. Zero hard runtime
dependencies.

[.agents/design.md](https://pedrobtz.github.io/zufft/.agents/design.md)
is the specification and outranks this file.
[.agents/roadmap.md](https://pedrobtz.github.io/zufft/.agents/roadmap.md)
is the stage plan with exit criteria.

## Current state

Verified 2026-10-13: package identity only (Stage 0). Nothing of ducc0
is vendored and no transform exists yet. Stage 1 vendors ducc0 and sets
up the build.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as “6 of 7”.

- **One parent issue per target version**, titled with the bare version:
  [v0.1.0 (#2)](https://github.com/pedrobtz/zufft/issues/2).
- **One sub-issue per roadmap stage**, titled as the roadmap titles it,
  for example `Stage 3 — Fourier transforms`, and linking to that
  section.
- **Every tracking issue carries the `stage` label**, so it can be told
  apart from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in
  the body of the stage’s pull request. Never close a stage whose exit
  criteria are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages
  are done, not what a stage requires. Adding, removing or renaming a
  stage means editing the roadmap and the sub-issues in the same change.
- Close the parent issue when CRAN accepts the version and it is tagged.
  Submission is tracked in [CRAN-submission
  (#14)](https://github.com/pedrobtz/zufft/issues/14).

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first
CRAN release. Set `Version: 0.1.0` and the matching `NEWS.md` heading
when the package enters `Pre-flight`. Bump to `0.1.0.9000` only after
CRAN accepts it.

Until the first release the R API may change freely. The C table in
`inst/include/zufft.h` is different: `zutsne` will consume it, and a
layout change breaks it even before 0.1.0, so the table follows the
append-only rules of design §7.

## Commands

Run from the package root.

``` sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
Rscript -e 'devtools::build_readme()'            # README.Rmd -> README.md
air format .                                     # format R sources
```

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`,
  randomised input through
  [`withr::local_seed()`](https://withr.r-lib.org/reference/with_seed.html).
  Tests write only under
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "zufft_invalid_argument")` and the other
  classes of design §9.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of
  the definition of done.
- **Oracles before hand-written cases.** `scipy.fft` fixtures,
  `fftwtools` (in `Suggests`, skipped when absent),
  [`stats::fft()`](https://rdrr.io/r/stats/fft.html) and a direct O(n²)
  DFT (design §10).
- **Keep the suite inside the CRAN time budget** of 15 s.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors,
0 warnings and 0 notes. The one allowed note is “New submission” before
the first release. `devtools::test(shuffle = TRUE)` green. CI green on
every leg. A user-facing change also needs a test, roxygen documentation
and a `NEWS.md` entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD
  check runs `--as-cran` on the CRAN-like runners and containers, and it
  replaces win-builder, the macOS builder and R-hub. `cran-comments.md`
  lists the CI legs as its test environments.
- **The pretest is automated and does not read `cran-comments.md`.** Fix
  a NOTE instead of justifying it.
- **After acceptance,** tag `0.1.0`, publish the GitHub release, bump to
  `0.1.0.9000`, and close the version’s parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by
  hand.
- Edit `README.Rmd`, not the generated `README.md`.
- Keep prose simple and short. One idea per sentence. en-GB spelling.
- Wrap roxygen text at 80 characters and run `air format .` on R
  sources.
- Use `lower_snake_case`; internal native symbols use the `zff_` prefix,
  the public C API the `zufft_` prefix.
- Keep hard runtime dependencies at zero.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned to `@v1`:
`r-cmd-check.yml` (quick on pull requests, full on `main`, full on a
pull request with the `full-ci` label), `coverage.yml` and the pkgdown
workflow.

## Commits and pull requests

Short, imperative, sentence-case commit subjects. Keep each commit
focused. A pull request explains the user-visible outcome and the
rationale, links related issues, lists the checks that were run and the
tests that were skipped, and flags platform-sensitive or vendored
changes. Performance claims need evidence.
