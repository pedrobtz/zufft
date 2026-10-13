// libFuzzer target for zufft's C table (design §7, §10): arbitrary
// layouts, shapes, strides, axes, types and buffer offsets go through every
// member. The table must return a status, never crash, read or write out
// of bounds, or overflow. Built by r-actions' fuzz.yml with ASan and UBSan
// from src/zff_*.cpp, without R.
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#define ZUFFT_NO_R
#include "zufft.h"

extern "C" const zufft_api *zff_api_v1(void);

namespace {

struct reader {
  const uint8_t *p;
  size_t n;
  uint8_t byte() {
    if (n == 0) return 0;
    --n;
    return *p++;
  }
};

constexpr size_t kBuf = 4096; /* doubles per buffer */

}  // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  static const zufft_api *api = zff_api_v1();
  reader r{data, size};
  const int op = r.byte() % 6;
  const int ndim = 1 + r.byte() % 3;

  size_t shape_in[3], shape_out[3];
  ptrdiff_t stride_in[3], stride_out[3];
  size_t count_in = 1, count_out = 1;
  for (int i = 0; i < ndim; ++i) {
    shape_in[i] = r.byte() % 9;  /* 0 is an error case */
    shape_out[i] = (r.byte() & 1) ? shape_in[i] : r.byte() % 9;
    stride_in[i] = ptrdiff_t(r.byte() % 40) - 2; /* negatives are errors */
    stride_out[i] = ptrdiff_t(r.byte() % 40) - 2;
    count_in *= shape_in[i] ? shape_in[i] : 1;
    count_out *= shape_out[i] ? shape_out[i] : 1;
  }
  const bool dense_in = r.byte() & 1, dense_out = r.byte() & 1;
  zufft_layout lin = {ndim, shape_in, dense_in ? nullptr : stride_in};
  zufft_layout lout = {ndim, shape_out, dense_out ? nullptr : stride_out};

  int naxes = 1 + r.byte() % 3;
  int axes[3];
  for (int i = 0; i < naxes; ++i) axes[i] = int(r.byte() % 5) - 1;

  /* Buffers large enough for any in-bounds layout this generator makes:
   * 8^3 elements of 2 doubles with strides < 40 stay under kBuf only when
   * dense, so strided cases rely on the table's own extent checks being
   * correct; the buffers are sized to the worst valid extent. */
  size_t reach_in = 1, reach_out = 1;
  for (int i = 0; i < ndim; ++i) {
    const size_t si = dense_in ? 0 : size_t(stride_in[i] < 0 ? 0 : stride_in[i]);
    const size_t so = dense_out ? 0 : size_t(stride_out[i] < 0 ? 0 : stride_out[i]);
    reach_in += (shape_in[i] ? shape_in[i] - 1 : 0) * si;
    reach_out += (shape_out[i] ? shape_out[i] - 1 : 0) * so;
  }
  if (dense_in) reach_in = count_in;
  if (dense_out) reach_out = count_out;
  const size_t need = 2 * (reach_in > reach_out ? reach_in : reach_out) + 16;
  std::vector<double> in(need > kBuf ? need : kBuf), out(need > kBuf ? need : kBuf);
  for (size_t i = 0; i < in.size(); ++i) in[i] = double(int(i % 17) - 8);

  const int type = int(r.byte() % 6);
  const int forward = r.byte() & 1, ortho = r.byte() & 1;
  const int nthreads = int(r.byte() % 4) - 1;
  const bool inplace = (r.byte() % 4) == 0;
  double *o = inplace ? in.data() : out.data();

  switch (op) {
    case 0: api->c2c(&lin, in.data(), &lout, o, naxes, axes, forward, 1.0, nthreads); break;
    case 1: api->r2c(&lin, in.data(), &lout, o, naxes, axes, forward, 1.0, nthreads); break;
    case 2: api->c2r(&lin, in.data(), &lout, o, naxes, axes, forward, 1.0, nthreads); break;
    case 3: api->dct(&lin, in.data(), &lout, o, naxes, axes, type, 1.0, ortho, nthreads); break;
    case 4: api->dst(&lin, in.data(), &lout, o, naxes, axes, type, 1.0, ortho, nthreads); break;
    default: api->good_size(size_t(r.byte()) << (r.byte() % 56), r.byte() & 1); break;
  }
  (void) api->message();
  return 0;
}
