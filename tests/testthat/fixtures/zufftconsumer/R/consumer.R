conv2d <- function(x, k) .Call(zc_conv2d, x, k)
inplace_pair <- function(z) .Call(zc_inplace_pair, z)
contract <- function() .Call(zc_contract)
concurrent <- function(nthreads, reps) {
  .Call(zc_concurrent, as.integer(nthreads), as.integer(reps))
}
api_size <- function() .Call(zc_api_size)
