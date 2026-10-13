# Conditions (design §9). Every zufft condition inherits `zufft_error`.

zufft_abort <- function(message, class, call = NULL) {
  cnd <- structure(
    class = c(class, "zufft_error", "error", "condition"),
    list(message = message, call = call)
  )
  stop(cnd)
}

# Called from C (zff_raise) with a shim status code and its message.
zff_signal_status <- function(status, message) {
  class <- switch(
    as.character(status),
    "1" = ,
    "2" = "zufft_invalid_argument",
    "3" = "zufft_length_error",
    "4" = ,
    "6" = "zufft_engine_error",
    "5" = "zufft_thread_error",
    "zufft_internal_error"
  )
  zufft_abort(message, class)
}
