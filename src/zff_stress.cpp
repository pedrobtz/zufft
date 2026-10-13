/* Thread stress test for the Windows go/no-go of design §12.1.
 *
 * Builds small pools of std::thread workers that wait on a
 * std::condition_variable, runs many short parallel regions through each,
 * and tears the pool down, over and over. That is the pattern zufft's own
 * pool (Stage 6) will use, on the same toolchain primitives. A hang here on
 * Rtools' MinGW-w64 is what SciPy reports for ducc0's pool; this test is how
 * zufft finds out before relying on threads there. Never calls R. */
#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

#include "zff_shim.h"

int zff_status_from_exception() noexcept;

namespace {

class stress_pool {
 public:
  explicit stress_pool(std::size_t nworkers) {
    threads_.reserve(nworkers);
    for (std::size_t i = 0; i < nworkers; ++i)
      threads_.emplace_back([this, i] { loop(i + 1); });
  }

  ~stress_pool() {
    {
      std::lock_guard<std::mutex> lock(mut_);
      stop_ = true;
    }
    work_.notify_all();
    for (auto &t : threads_) t.join();
  }

  stress_pool(const stress_pool &) = delete;
  stress_pool &operator=(const stress_pool &) = delete;

  /* Runs f(id) on every worker and on the caller (id 0), then waits. */
  void run(const std::function<void(std::size_t)> &f) {
    {
      std::lock_guard<std::mutex> lock(mut_);
      job_ = &f;
      pending_ = threads_.size();
      ++generation_;
    }
    work_.notify_all();
    f(0);
    std::unique_lock<std::mutex> lock(mut_);
    done_.wait(lock, [this] { return pending_ == 0; });
    job_ = nullptr;
  }

 private:
  void loop(std::size_t id) {
    std::size_t seen = 0;
    for (;;) {
      const std::function<void(std::size_t)> *f;
      {
        std::unique_lock<std::mutex> lock(mut_);
        work_.wait(lock, [&] { return stop_ || generation_ != seen; });
        if (stop_) return;
        seen = generation_;
        f = job_;
      }
      (*f)(id);
      std::lock_guard<std::mutex> lock(mut_);
      if (--pending_ == 0) done_.notify_one();
    }
  }

  std::vector<std::thread> threads_;
  std::mutex mut_;
  std::condition_variable work_, done_;
  const std::function<void(std::size_t)> *job_ = nullptr;
  std::size_t generation_ = 0, pending_ = 0;
  bool stop_ = false;
};

}  // namespace

extern "C" int zff_thread_stress(int nthreads, int pools, int regions,
                                 double *checksum) {
  try {
    const std::size_t n = nthreads < 1 ? 1 : std::size_t(nthreads);
    std::atomic<unsigned long long> sum{0};
    const std::function<void(std::size_t)> add = [&sum](std::size_t id) {
      sum.fetch_add(id + 1, std::memory_order_relaxed);
    };
    for (int p = 0; p < pools; ++p) {
      stress_pool pool(n - 1);
      for (int r = 0; r < regions; ++r) pool.run(add);
    }
    const unsigned long long want =
        (unsigned long long)pools * regions * (n * (n + 1) / 2);
    *checksum = double(sum.load());
    return sum.load() == want ? ZFF_OK : ZFF_EINTERNAL;
  } catch (...) {
    return zff_status_from_exception();
  }
}
