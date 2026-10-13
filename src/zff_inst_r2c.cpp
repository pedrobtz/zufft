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

/* Fills the second half of the last transformed axis of `out` from the
 * first by conjugate symmetry, as SciPy's c2c_sym_internal does. */
void zff_hermitian_fill(const ducc0::vfmav<std::complex<double>> &out,
                        const ducc0::fmav_info::shape_t &axes,
                        std::size_t nthreads) {
  using ducc0::detail_fft::hermiteHelper;
  using cplx = std::complex<double>;
  hermiteHelper(0, 0, 0, 0, ducc0::cfmav<cplx>(out), out, axes,
                [](const cplx &c, cplx &, cplx &c1) { c1 = std::conj(c); },
                nthreads);
}
