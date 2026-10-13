/* zufft's thread pool for ducc0's custom threading mode (design §6.5).
 *
 * - No thread starts until a transform asks for more than one; the pool
 *   then grows to the largest request and never shrinks. Threads are never
 *   pinned, and DUCC0_NUM_THREADS / OMP_NUM_THREADS are not read.
 * - A process-wide entry gate serialises top-level transforms, so pool
 *   growth, ducc0's plan cache and unloading are deterministic, and the C
 *   table is safe from any caller thread. Workers still run one transform
 *   in parallel.
 * - Fork safety on POSIX: once the pool exists, pthread_atfork handlers take
 *   the gate and the queue lock before fork(); the parent releases them;
 *   the child abandons the inherited pool (its threads do not exist there)
 *   without touching its mutexes and rebuilds lazily. Handlers cannot be
 *   unregistered, so the shared object pins itself in memory with
 *   RTLD_NODELETE when it registers them; after R unloads the package they
 *   find no pool and do nothing.
 * - R_unload_zufft (zufft.c) calls zff_pool_shutdown(), which takes the
 *   gate and joins every worker.
 * Nothing here calls R. */
#include <algorithm>
#include <cstdlib>
#include <atomic>
#include <condition_variable>
#include <cstddef>
#include <deque>
#include <functional>
#include <mutex>
#include <string>
#include <system_error>
#include <thread>
#include <utility>
#include <vector>

#if !defined(_WIN32) && __has_include(<pthread.h>) && __has_include(<dlfcn.h>)
#define ZFF_HAVE_ATFORK 1
#include <dlfcn.h>
#include <pthread.h>
#endif

#include "ducc0/infra/threading.h"
#include "zff_shim.h"

void zff_set_message(const char *msg) noexcept;

namespace ducc0 {
namespace detail_threading {

namespace {

/* The pool: a FIFO of tasks served by workers that wait on a condition
 * variable. ducc0 submits nthreads - 1 tasks per parallel region and runs
 * the remaining share on the calling thread. */
class zff_pool : public thread_pool {
 public:
  ~zff_pool() override { shutdown(); }

  size_t nthreads() const override { return nworkers_.load(); }

  size_t adjust_nthreads(size_t n) const override {
    if (in_parallel_region) return 1;
    const size_t avail = nworkers_.load() + 1;
    return n == 0 ? avail : std::min(avail, n);
  }

  void submit(std::function<void()> work) override {
    {
      std::lock_guard<std::mutex> lock(mut_);
      queue_.push_back(std::move(work));
    }
    cv_.notify_one();
  }

  /* Grows to n workers; throws std::system_error if a thread cannot start
   * (the threads already started stay). Called with the gate held. */
  void grow(size_t n) {
    while (threads_.size() < n) {
      threads_.emplace_back([this] { loop(); });
      nworkers_.store(threads_.size());
    }
  }

  void shutdown() {
    {
      std::lock_guard<std::mutex> lock(mut_);
      stop_ = true;
    }
    cv_.notify_all();
    for (auto &t : threads_)
      if (t.joinable()) t.join();
    threads_.clear();
    nworkers_.store(0);
  }

  std::mutex &queue_mutex() { return mut_; }

 private:
  void loop() {
    in_parallel_region = true;
    for (;;) {
      std::function<void()> task;
      {
        std::unique_lock<std::mutex> lock(mut_);
        cv_.wait(lock, [this] { return stop_ || !queue_.empty(); });
        if (queue_.empty()) return; /* stop_ and nothing left */
        task = std::move(queue_.front());
        queue_.pop_front();
      }
      task(); /* ducc0's tasks catch their own exceptions */
    }
  }

  std::vector<std::thread> threads_;
  std::atomic<size_t> nworkers_{0};
  std::deque<std::function<void()>> queue_;
  std::mutex mut_;
  std::condition_variable cv_;
  bool stop_ = false;
};

/* Process-wide state. The pool is created on first use and replaced in a
 * forked child; the old object is then kept in `abandoned` (never freed:
 * its threads do not exist there and its queue lock is held), so that it
 * stays reachable rather than leaked. */
std::mutex gate;
zff_pool *pool = nullptr;
zff_pool *abandoned[16];
int n_abandoned = 0;
thread_local thread_pool *active_pool = nullptr;

zff_pool &the_pool() {
  if (!pool) pool = new zff_pool();
  return *pool;
}

/* At process exit (POSIX only, see zff_pool_enter), join the workers so
 * none outlives the process's own teardown (and valgrind sees no thread
 * left running). Skipped if another
 * thread holds the gate, rather than deadlocking the exit. */
void join_at_exit() {
  if (!gate.try_lock()) return;
  if (pool) {
    pool->shutdown();
    delete pool;
    pool = nullptr;
  }
  gate.unlock();
}

std::once_flag exit_once;

void register_exit_hook() {
  std::call_once(exit_once, [] { std::atexit(join_at_exit); });
}

#ifdef ZFF_HAVE_ATFORK
std::once_flag atfork_once;

void atfork_prepare() {
  gate.lock();
  if (pool) pool->queue_mutex().lock();
}

void atfork_parent() {
  if (pool) pool->queue_mutex().unlock();
  gate.unlock();
}

/* Only the forking thread exists in the child. It owns the gate and the
 * queue lock; the workers, and anything they held, are gone. */
void atfork_child() {
  if (pool && n_abandoned < 16) abandoned[n_abandoned++] = pool;
  pool = nullptr;
  gate.unlock();
}

void register_atfork() {
  std::call_once(atfork_once, [] {
    /* Pin this shared object so the handlers stay mapped if R unloads it. */
    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(&atfork_prepare), &info) && info.dli_fname)
      dlopen(info.dli_fname, RTLD_NOW | RTLD_NODELETE);
    pthread_atfork(atfork_prepare, atfork_parent, atfork_child);
    register_exit_hook();
  });
}
#endif

}  // namespace

size_t available_hardware_threads() {
  return std::max<size_t>(1, std::thread::hardware_concurrency());
}

thread_pool *set_active_pool(thread_pool *new_pool) {
  return std::exchange(active_pool, new_pool);
}

thread_pool *get_active_pool() {
  return active_pool ? active_pool : &the_pool();
}

}  // namespace detail_threading
}  // namespace ducc0

namespace dt = ducc0::detail_threading;

/* Enters a top-level transform that will use up to `nthreads` threads:
 * takes the gate and grows the pool. On failure the gate is released, the
 * message set, and ZFF_ETHREAD returned. */
extern "C" int zff_pool_enter(int nthreads) {
  dt::gate.lock();
  if (nthreads <= 1) return ZFF_OK;
  try {
#ifdef ZFF_HAVE_ATFORK
    dt::register_atfork(); /* pins the shared object, then the exit hook */
#endif
    /* No exit hook on Windows: a DLL's atexit handlers run in
     * DLL_PROCESS_DETACH under the loader lock, and joining threads there
     * deadlocks the process exit (seen on pedrobtz/zufft#21). */
    dt::the_pool().grow(size_t(nthreads) - 1);
    return ZFF_OK;
  } catch (const std::system_error &e) {
    std::string msg = std::string("could not start a thread: ") + e.what();
    zff_set_message(msg.c_str());
  } catch (...) {
    zff_set_message("could not start a thread");
  }
  dt::gate.unlock();
  return ZFF_ETHREAD;
}

extern "C" void zff_pool_leave(void) { dt::gate.unlock(); }

/* Joins every worker; called from R_unload_zufft. */
extern "C" void zff_pool_shutdown(void) {
  std::lock_guard<std::mutex> lock(dt::gate);
  if (dt::pool) {
    dt::pool->shutdown();
    delete dt::pool;
    dt::pool = nullptr;
  }
}

extern "C" size_t zff_pool_size(void) {
  return dt::pool ? dt::pool->nthreads() + 1 : 1;
}

extern "C" size_t zff_hardware_threads(void) {
  return dt::available_hardware_threads();
}

namespace {
std::atomic<int> default_workers{1};
}

extern "C" void zff_set_default_workers(int n) { default_workers.store(n); }

extern "C" int zff_default_workers(void) { return default_workers.load(); }
