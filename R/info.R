#' Information about the zufft build
#'
#' Reports which ducc0 source zufft was built from and how: the vendored
#' commit and the SciPy commit that pins it, the SIMD backend and vector
#' width the compiler selected, whether the target has fused multiply-add
#' instructions, the threading mode, and the thread pool.
#'
#' @return A named list:
#'   \describe{
#'     \item{`ducc0_commit`}{ducc0 commit of the vendored FFT subset.}
#'     \item{`scipy_commit`}{SciPy commit whose vendoring script pins it.}
#'     \item{`simd_backend`}{`"ducc0"`, `"std::experimental::simd"` or
#'       `"none"`.}
#'     \item{`simd_width`}{Doubles per SIMD vector, `1` without SIMD.}
#'     \item{`fma`}{`TRUE` if the target has fused multiply-add.}
#'     \item{`threading`}{`"zufft"` when zufft supplies the thread pool,
#'       `"none"` when threads are compiled out.}
#'     \item{`pool_size`}{Threads the pool can use now, the caller
#'       included.}
#'     \item{`hardware_threads`}{Threads the hardware offers.}
#'     \item{`complex_path`}{How complex vectors reach ducc0.}
#'   }
#' @export
#' @examples
#' zufft_info()$simd_width
zufft_info <- function() {
  .Call(zff_info)
}
