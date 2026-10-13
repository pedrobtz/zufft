/* zufft's thread pool for ducc0's custom threading mode (design §6.5).
 *
 * Stage 1 placeholder: a pool with no worker threads that runs submitted
 * work on the calling thread, so every transform is single-threaded. Stage 6
 * replaces it with the lazy pool the design specifies. */
#include <algorithm>
#include <atomic>
#include <cstddef>
#include <functional>
#include <thread>
#include <utility>

#include "ducc0/infra/threading.h"
#include "zff_shim.h"

namespace ducc0 {
namespace detail_threading {

namespace {

class zff_serial_pool : public thread_pool {
 public:
  size_t nthreads() const override { return 0; }
  size_t adjust_nthreads(size_t) const override { return 1; }
  void submit(std::function<void()> work) override { work(); }
};

zff_serial_pool &serial_pool() {
  static zff_serial_pool pool;
  return pool;
}

thread_local thread_pool *active_pool = nullptr;

}  // namespace

size_t available_hardware_threads() {
  return std::max<size_t>(1, std::thread::hardware_concurrency());
}

thread_pool *set_active_pool(thread_pool *new_pool) {
  return std::exchange(active_pool, new_pool);
}

thread_pool *get_active_pool() {
  return active_pool ? active_pool : &serial_pool();
}

}  // namespace detail_threading
}  // namespace ducc0

extern "C" size_t zff_pool_size(void) {
  return ducc0::detail_threading::get_active_pool()->nthreads() + 1;
}

extern "C" size_t zff_hardware_threads(void) {
  return ducc0::detail_threading::available_hardware_threads();
}

namespace {
std::atomic<int> default_workers{1};
}

extern "C" void zff_set_default_workers(int n) { default_workers.store(n); }

extern "C" int zff_default_workers(void) { return default_workers.load(); }
