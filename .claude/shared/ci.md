<!-- Synced from pedrobtz/packages:claude/shared/ci.md. Do not edit it here:
change it there, and the sync opens a pull request in every package. -->

# Continuous integration

Workflows come from `pedrobtz/r-actions`. Call those reusable workflows instead
of writing bespoke ones, and pin a released tag rather than `main`. Pin a
workflow that holds a write token, such as `coverage.yml` or
`cran-release.yml`, to a commit, with the tag in a comment. The `R-CMD-check`
workflow must call `r-cmd-check.yml`, because a hand-rolled one does not count
as the pre-submission check. The package's `CLAUDE.md` lists the shared
workflows it calls and any of its own.

## What a change runs

The shared workflows' `changes` gate looks at the files a pull request
changes, compared with its merge base:

- **Documentation and housekeeping only** skips every check; only coverage
  and the pkgdown site run. That covers top-level Markdown (`README.md`,
  `NEWS.md`, `cran-comments.md`), Markdown under dot directories,
  `_pkgdown.yml`, `CRAN-SUBMISSION`, `.gitignore`, issue and pull request
  templates, and any workflow file other than the calling workflow's own.
- **`DESCRIPTION` or `README.Rmd` as well**, and nothing else, adds one R CMD
  check on Ubuntu R-release.
- **Any other file** runs everything.

So put a README or `DESCRIPTION` touch-up in its own pull request. Once a pull
request changes code, every later push to it runs every workflow.

A package's own workflows gate the same way by calling `changes.yml` rather
than carrying a `paths-ignore` list.

## Labels

A label on a pull request can ask for more checking, or for less:

| Label | Effect on that pull request's runs |
|---|---|
| `full-ci` | the full profile; overrides the two labels below |
| `ci:minimal` | one quick R CMD check, every other gated job skipped |
| `skip-ci:<workflow>` | that workflow's jobs skipped, for example `skip-ci:fuzz` or `skip-ci:valgrind` |

Labels change pull request runs only. The push to the default branch after
merge carries none, so whatever a label skipped still runs there. Apply a
label at creation (`gh pr create --label ci:minimal`) for it to count from the
first run; one added later starts a new run. Use `ci:minimal` or a `skip-ci`
label for a change the checks cannot see, such as CI configuration or
repository housekeeping, never to get code past a failing check.

## Quick by default, full by exception

The full profile is slow. gctorture at step 20 alone has taken 36 to 107
minutes on sibling packages. Waiting on it between roadmap stages was the
main thing slowing roadmaps down, so:

- **Pull requests run the quick profile** (`profile: auto` in the callers).
  It should finish in under five minutes. If it doesn't, raise gctorture's
  `quick-step` or trim `quick-containers` in the caller workflows; never cut
  the full profile.
- **A `full` roadmap stage takes the `full-ci` label** and merges only on a
  green full run. The roadmap gives the reason in the stage's `**CI.**`
  line, for example first compiled code, a `PROTECT` or finalizer change, a
  vendored library, or a Windows-only path.
- **Don't wait on the full run a merge starts** on the default branch, and
  cancel older full runs it supersedes. A failure that only the full set
  shows goes on the `Full CI` stage issue as a comment with the run link,
  and is fixed there. A failure the quick profile also shows is fixed now.
- **`Full CI` and `v0.1.0 readiness` wait** for a green full run on their
  merge commit, and the release commit always needs one.
- Locally, run `gctorture(TRUE)` on the code a C change touches when it is
  cheap; the full run is the authority.
