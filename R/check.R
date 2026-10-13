# Argument checks shared by the transforms (design §5.1, §6).

# Whole numbers that R represents exactly (|x| <= 2^53).
is_whole <- function(x) {
  is.numeric(x) &&
    !anyNA(x) &&
    all(is.finite(x)) &&
    all(x == trunc(x)) &&
    all(abs(x) <= 2^53)
}

# Extents of x: dim(x), or the length of a plain vector (a double, so that
# long vectors survive).
array_dims <- function(x) {
  d <- dim(x)
  if (is.null(d)) as.double(length(x)) else as.double(d)
}

# x as a double or complex array, keeping dim and dimnames.
as_numeric_input <- function(x, call) {
  if (is.double(x) || is.complex(x)) {
    return(x)
  }
  if (is.integer(x) || is.logical(x)) {
    storage.mode(x) <- "double"
    return(x)
  }
  zufft_abort(
    "`x` must be a double, integer, logical or complex vector or array.",
    "zufft_invalid_argument",
    call
  )
}

# 1-based axes in, validated; NULL means every dimension.
check_axes <- function(axes, nd, call) {
  if (is.null(axes)) {
    return(seq_len(nd))
  }
  if (!is_whole(axes) || length(axes) == 0L) {
    zufft_abort(
      "`axes` must be a non-empty vector of whole numbers.",
      "zufft_invalid_argument",
      call
    )
  }
  if (any(axes < 1 | axes > nd)) {
    zufft_abort(
      sprintf("`axes` must lie in 1..%d, the dimensions of `x`.", nd),
      "zufft_invalid_argument",
      call
    )
  }
  if (anyDuplicated(axes)) {
    zufft_abort(
      "`axes` must not repeat an axis.",
      "zufft_invalid_argument",
      call
    )
  }
  as.integer(axes)
}

# Per-axis lengths: NULL means `default`; otherwise one positive whole
# number per transformed axis, no recycling.
check_n <- function(n, naxes, default, call) {
  if (is.null(n)) {
    return(as.double(default))
  }
  if (!is_whole(n)) {
    zufft_abort(
      "`n` must contain whole numbers.",
      "zufft_invalid_argument",
      call
    )
  }
  if (length(n) != naxes) {
    zufft_abort(
      sprintf(
        "`n` must have one value per transformed axis (%d), not %d.",
        naxes,
        length(n)
      ),
      "zufft_invalid_argument",
      call
    )
  }
  as.double(n)
}

check_lengths <- function(len, min, call) {
  if (any(len < min)) {
    zufft_abort(
      sprintf("Every transformed length must be at least %d.", min),
      "zufft_length_error",
      call
    )
  }
  invisible(len)
}

norm_values <- c("backward", "ortho", "forward", "none")

check_norm <- function(norm, call) {
  if (identical(norm, norm_values)) {
    return("backward")
  }
  if (!is.character(norm) || length(norm) != 1L || !norm %in% norm_values) {
    zufft_abort(
      '`norm` must be one of "backward", "ortho", "forward" or "none".',
      "zufft_invalid_argument",
      call
    )
  }
  norm
}

# SciPy's inorm for a direction: 0 none, 1 ortho, 2 scale by 1/N.
inorm_of <- function(norm, forward) {
  switch(
    norm,
    none = 0L,
    ortho = 1L,
    backward = if (forward) 0L else 2L,
    forward = if (forward) 2L else 0L
  )
}

check_inverse <- function(inverse, call) {
  if (is.numeric(inverse) && length(inverse) == 1L && inverse %in% c(0, 1)) {
    inverse <- as.logical(inverse)
  }
  if (!is.logical(inverse) || length(inverse) != 1L || is.na(inverse)) {
    zufft_abort(
      "`inverse` must be TRUE or FALSE (or 0 or 1).",
      "zufft_invalid_argument",
      call
    )
  }
  inverse
}

# Result attributes: dim when x had one, dimnames kept on the axes that
# were not transformed.
set_result_attributes <- function(out, x, out_dims, axes) {
  if (is.null(dim(x))) {
    return(out)
  }
  dim(out) <- out_dims
  dn <- dimnames(x)
  if (!is.null(dn)) {
    dn[axes] <- list(NULL)
    if (!all(vapply(dn, is.null, logical(1)))) dimnames(out) <- dn
  }
  out
}
