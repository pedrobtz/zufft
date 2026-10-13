/* Explicit instantiation of ducc0's discrete cosine and sine transforms for
 * double (design §8). */
#include "zff_fp_contract.h"
#include "ducc0/fft/fft.h"
#include "ducc0/fft/fftnd_impl.h"

namespace ducc0 {
namespace detail_fft {

template void dct(const cfmav<double> &in, const vfmav<double> &out,
                  const shape_t &axes, int type, double fct, bool ortho,
                  size_t nthreads);
template void dst(const cfmav<double> &in, const vfmav<double> &out,
                  const shape_t &axes, int type, double fct, bool ortho,
                  size_t nthreads);

}  // namespace detail_fft
}  // namespace ducc0
