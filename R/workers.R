# Threads per call (design §6.5).

zufft_state <- new.env(parent = emptyenv())
zufft_state$workers <- 1L
zufft_state$cores <- 1L

.onLoad <- function(libname, pkgname) {
  zufft_state$cores <- .Call(zff_info)$hardware_threads
}

limit_cores <- function() {
  v <- Sys.getenv("_R_CHECK_LIMIT_CORES_", "")
  nzchar(v) && !identical(tolower(v), "false")
}

# A positive count, or -k for all available cores but k - 1, as SciPy.
# Capped at the available cores, and at 2 under _R_CHECK_LIMIT_CORES_.
resolve_workers <- function(workers, call = NULL) {
  if (is.null(workers)) {
    workers <- zufft_state$workers
  }
  # Fast path: one thread needs no capping, and it is the common case.
  if (identical(workers, 1L) || identical(workers, 1)) {
    return(1L)
  }
  if (!is_whole(workers) || length(workers) != 1L || workers == 0) {
    zufft_abort(
      "`workers` must be a non-zero whole number.",
      "zufft_invalid_argument",
      call
    )
  }
  cores <- zufft_state$cores
  if (workers < 0) {
    workers <- cores + 1 + workers
    if (workers < 1) {
      zufft_abort(
        "`workers` asks for fewer than one thread.",
        "zufft_invalid_argument",
        call
      )
    }
  }
  workers <- min(workers, cores)
  if (limit_cores()) {
    workers <- min(workers, 2)
  }
  as.integer(workers)
}

#' Threads per transform
#'
#' `fft_workers()` gets or sets the number of threads a transform uses when
#' its `workers` argument is `NULL`. `with_fft_workers()` sets it while
#' `code` runs and `local_fft_workers()` until the calling function returns,
#' in the style of the withr package; both restore the old value. Together
#' they are SciPy's `get_workers()` and `set_workers()`.
#'
#' A positive value asks for that many threads; a negative one counts back
#' from the number of available cores, so `-1` means all of them. Requests
#' are capped at the available cores, and at 2 when `_R_CHECK_LIMIT_CORES_`
#' is set (as during `R CMD check`). The initial value is 1, as in SciPy.
#'
#' Threads help when a transform has many independent lines (the columns of
#' a matrix, a multi-dimensional array) and at least 32 768 elements; a
#' single 1-D real transform always runs on one thread. Results agree to
#' rounding whatever the number of threads, and are bit-identical on builds
#' without fused multiply-add, such as CRAN's x86-64 binaries.
#'
#' @param n A non-zero whole number. `NULL` (in `fft_workers()`) only reads
#'   the current value.
#' @param code Code to run with `n` threads.
#' @param .local_envir The environment whose exit restores the old value.
#' @return `fft_workers()` returns the current value when `n` is `NULL`, and
#'   otherwise the previous value, invisibly. `with_fft_workers()` returns
#'   the value of `code`; `local_fft_workers()` returns the previous value,
#'   invisibly.
#' @family threads
#' @export
#' @examples
#' fft_workers()
#' with_fft_workers(2, fft_c2c(matrix(rnorm(1e4), 100), axes = 1))
#' f <- function() {
#'   local_fft_workers(2)
#'   fft_workers()
#' }
#' f()
#' fft_workers()
fft_workers <- function(n = NULL) {
  if (is.null(n)) {
    return(zufft_state$workers)
  }
  if (
    !is_whole(n) || length(n) != 1L || n == 0 || abs(n) > .Machine$integer.max
  ) {
    zufft_abort(
      "`n` must be a non-zero whole number.",
      "zufft_invalid_argument",
      sys.call()
    )
  }
  old <- zufft_state$workers
  zufft_state$workers <- as.integer(n)
  .Call(zff_set_workers_call, as.integer(n))
  invisible(old)
}

#' @rdname fft_workers
#' @export
with_fft_workers <- function(n, code) {
  old <- fft_workers(n)
  on.exit(fft_workers(old), add = TRUE)
  force(code)
}

#' @rdname fft_workers
#' @export
local_fft_workers <- function(n, .local_envir = parent.frame()) {
  old <- fft_workers(n)
  restore <- as.call(list(fft_workers, old))
  do.call(base::on.exit, list(restore, TRUE, FALSE), envir = .local_envir)
  invisible(old)
}

# Joins the thread pool's workers now; the pool restarts on the next
# threaded call. Internal: forked children (parallel::mclapply) leave with
# _exit(), which runs no exit handler, so tests call this to finish them
# cleanly under valgrind.
zff_release_threads <- function() {
  invisible(.Call(zff_release_call))
}
