## Test environments

All through the R CMD check workflows of pedrobtz/r-actions, run with
`--as-cran`:

* macOS (latest), R release
* Windows (latest), R release
* Ubuntu (latest), R release and R oldrel-1
* R-hub containers matching CRAN's r-devel Linux flavours: clang 23 with
  `-std=gnu23 -pedantic` (libc++), Ubuntu clang (libstdc++) and GCC 16
* UBSan with clang and GCC, ASan with clang and GCC, valgrind, LTO,
  gctorture, rchk, and the rcnst and read-only-library checks

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for CRAN

* zufft bundles the FFT component of ducc0 in src/ducc0, exactly the files
  that SciPy vendors, which are licensed "BSD-3-Clause OR GPL-2.0-or-later".
  zufft uses them under BSD-3-Clause. Every copyright holder named in them is
  listed in Authors@R and inst/COPYRIGHTS. Two small patches (in the source
  repository's tools/vendor/patches) remove a GNU macro extension that clang
  -pedantic reports and a reference bound to a null pointer that UBSan
  reports.
* src/Makevars (not Makevars.win) ends PKG_CXXFLAGS with $(ZUFFT_CXXFLAGS), an opt-in hook for
  users who want a build for their own CPU (for example
  ZUFFT_CXXFLAGS=-march=native). It is empty unless a user sets it, so CRAN's
  builds use only R's own flags and $(CXX_VISIBILITY).
* The package uses at most two threads when _R_CHECK_LIMIT_CORES_ is set,
  and one by default.

## Method references

There is no single published reference for the code in this package. The
bundled 'ducc0' FFT is an evolution of 'pocketfft', whose algorithms derive
from Paul Swarztrauber's FFTPACK; 'ducc0' itself is documented at
<https://github.com/mreineck/ducc>.
