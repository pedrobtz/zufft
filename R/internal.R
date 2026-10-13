# Stage 2 spikes (design §12.1, §12.2). Internal; not part of the API.

# Unnormalised 1-D complex transform of a complex vector through the shim.
zff_scratch_c2c <- function(z, inverse = FALSE) {
  .Call(zff_scratch_c2c_call, as.complex(z), !inverse)
}

# Creates `pools` thread pools of `nthreads` threads in turn and runs
# `regions` parallel regions through each. Returns the checksum, which must
# equal pools * regions * nthreads * (nthreads + 1) / 2.
zff_thread_stress <- function(nthreads = 2L, pools = 10L, regions = 100L) {
  .Call(
    zff_stress_call,
    as.integer(nthreads),
    as.integer(pools),
    as.integer(regions)
  )
}
