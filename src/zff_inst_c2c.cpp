/* Explicit instantiation of ducc0's complex-to-complex transform for double
 * (design §8). One translation unit per transform family so `make -j` can
 * compile them in parallel; ducc0's fft_inst_inc.h instantiates every
 * transform at once, so the lines are written out here instead. */
#include "zff_fp_contract.h"
#include "ducc0/fft/fft.h"
#include "ducc0/fft/fftnd_impl.h"

namespace ducc0 {
namespace detail_fft {

template void c2c(const cfmav<complex<double>> &in,
                  const vfmav<complex<double>> &out, const shape_t &axes,
                  bool forward, double fct, size_t nthreads);

}  // namespace detail_fft
}  // namespace ducc0
