/* zufft's C++ shim over ducc0 (design §4). No C++ type or exception crosses
 * into C: every entry point is extern "C" and noexcept, and catches every
 * exception into a status code and a thread-local message. R's API is never
 * called here. Stage 1 holds only the error plumbing and the build facts;
 * the transform entry points arrive in Stage 3. */
#include <cstring>
#include <exception>
#include <new>
#include <stdexcept>
#include <system_error>

#include "ducc0/infra/simd.h"
#include "zff_shim.h"

namespace {

constexpr std::size_t message_size = 512;
thread_local char last_message[message_size] = "";

}  // namespace

/* Records a failure for this thread; used by the transform entry points. */
void zff_set_message(const char *msg) noexcept {
  std::strncpy(last_message, msg ? msg : "", message_size - 1);
  last_message[message_size - 1] = '\0';
}

void zff_clear_message() noexcept { last_message[0] = '\0'; }

/* Maps the exception in flight to a status code and records its message. */
int zff_status_from_exception() noexcept {
  try {
    throw;
  } catch (const std::bad_alloc &) {
    zff_set_message("out of memory");
    return ZFF_ENOMEM;
  } catch (const std::system_error &e) {
    zff_set_message(e.what());
    return ZFF_ETHREAD;
  } catch (const std::exception &e) {
    zff_set_message(e.what());
    return ZFF_EENGINE;
  } catch (...) {
    zff_set_message("unknown C++ exception");
    return ZFF_EINTERNAL;
  }
}

extern "C" const char *zff_message(void) { return last_message; }

extern "C" int zff_simd_width(void) {
  return static_cast<int>(ducc0::native_simd<double>::size());
}

extern "C" const char *zff_simd_backend(void) {
#if defined(DUCC0_NO_SIMD)
  return "none";
#elif defined(DUCC0_HOMEGROWN_SIMD)
  return "ducc0";
#else
  return "std::experimental::simd";
#endif
}

/* Whether the target has fused multiply-add instructions, so that the
 * contraction requested in zff_fp_contract.h (design §12.3) can use them. */
extern "C" int zff_fma(void) {
#if defined(__FMA__) || defined(__ARM_FEATURE_FMA) || defined(__FP_FAST_FMA)
  return 1;
#else
  return 0;
#endif
}

extern "C" const char *zff_threading_mode(void) {
#if defined(DUCC0_NO_LOWLEVEL_THREADING)
  return "none";
#elif defined(DUCC0_CUSTOM_LOWLEVEL_THREADING)
  return "zufft";
#else
  return "ducc0";
#endif
}

/* Test hook: maps a thrown exception of each kind to its status, so every
 * zufft_status value can be produced by a test (design §10). */
extern "C" int zff_status_probe(int what) {
  try {
    switch (what) {
      case 4: throw std::bad_alloc();
      case 5: throw std::system_error(std::make_error_code(std::errc::resource_unavailable_try_again));
      case 6: throw std::runtime_error("engine failure (probe)");
      case 7: throw 42;
      default: zff_clear_message(); return ZFF_OK;
    }
  } catch (...) {
    return zff_status_from_exception();
  }
}
