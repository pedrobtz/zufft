/* Fast transform lengths (design §6.2).
 *
 * zff_good_size() is ducc0's good_size_complex() / good_size_real(): the
 * smallest n' >= n whose factors are all in {2, 3, 5, 7, 11} (complex) or
 * {2, 3, 5} (real). zff_prev_good_size() is the same search downwards. It
 * lives outside ducc0, in SciPy's scipy/fft/_duccfft/pyduccfft.cxx
 * (prev_good_size_cmplx, prev_good_size_real), from which the two functions
 * below are ported unchanged apart from names; that file is BSD-3 licensed
 * like the rest of SciPy's duccfft (inst/COPYRIGHTS). */
#include <cstddef>

#include "ducc0/fft/fft.h"
#include "zff_shim.h"

namespace {

/* Largest composite of 2, 3, 5, 7 and 11 that is <= n. */
std::size_t prev_good_size_cmplx(std::size_t n) {
  if (n <= 12) return n;

  std::size_t bestfound = 1;
  for (std::size_t f11 = 1; f11 <= n; f11 *= 11)
    for (std::size_t f117 = f11; f117 <= n; f117 *= 7)
      for (std::size_t f1175 = f117; f1175 <= n; f1175 *= 5) {
        std::size_t x = f1175;
        while (x * 2 <= n) x *= 2;
        if (x > bestfound) bestfound = x;
        while (true) {
          if (x * 3 <= n)
            x *= 3;
          else if (x % 2 == 0)
            x /= 2;
          else
            break;

          if (x > bestfound) bestfound = x;
        }
      }
  return bestfound;
}

/* Largest composite of 2, 3 and 5 that is <= n. */
std::size_t prev_good_size_real(std::size_t n) {
  if (n <= 6) return n;

  std::size_t bestfound = 1;
  for (std::size_t f5 = 1; f5 <= n; f5 *= 5) {
    std::size_t x = f5;
    while (x * 2 <= n) x *= 2;
    if (x > bestfound) bestfound = x;
    while (true) {
      if (x * 3 <= n)
        x *= 3;
      else if (x % 2 == 0)
        x /= 2;
      else
        break;

      if (x > bestfound) bestfound = x;
    }
  }
  return bestfound;
}

}  // namespace

extern "C" size_t zff_good_size(size_t n, int real) {
  return real ? ducc0::good_size_real(n) : ducc0::good_size_complex(n);
}

extern "C" size_t zff_prev_good_size(size_t n, int real) {
  return real ? prev_good_size_real(n) : prev_good_size_cmplx(n);
}
