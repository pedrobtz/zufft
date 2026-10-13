/* Explicit instantiation of ducc0's real-to-complex and complex-to-real
 * transforms for double (design §8). */
#include "zff_fp_contract.h"
#include "ducc0/fft/fft.h"
#include "ducc0/fft/fftnd_impl.h"

namespace ducc0 {
namespace detail_fft {

template void r2c(const cfmav<double> &in, const vfmav<complex<double>> &out,
                  const shape_t &axes, bool forward, double fct,
                  size_t nthreads);
template void c2r(const cfmav<complex<double>> &in, const vfmav<double> &out,
                  const shape_t &axes, bool forward, double fct,
                  size_t nthreads);

}  // namespace detail_fft
}  // namespace ducc0
