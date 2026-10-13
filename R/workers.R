# Threads per call (design §6.5). The default lives here until Stage 5
# exports fft_workers().

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
