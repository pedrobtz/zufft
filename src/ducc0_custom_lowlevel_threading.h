/* zufft's threading primitives for ducc0's DUCC0_CUSTOM_LOWLEVEL_THREADING
 * mode (design §6.5, §8). ducc0's threading.h includes this file between
 * its own namespace blocks, after declaring thread_pool.
 *
 * Mutex, LockGuard, UniqueLock and CondVar are the standard library's.
 * in_parallel_region is declared here because ducc0's threading.cc (at
 * 64f42ba) refers to it outside its threading-mode blocks, so custom mode
 * does not compile without it. zufft's pool sets it on its worker threads,
 * as ducc0's own pool does. set_active_pool(), get_active_pool() and
 * available_hardware_threads() are defined in zff_pool.cpp. */
#ifndef ZFF_DUCC0_CUSTOM_LOWLEVEL_THREADING_H
#define ZFF_DUCC0_CUSTOM_LOWLEVEL_THREADING_H

#include <condition_variable>
#include <mutex>

namespace ducc0 {
namespace detail_threading {

using Mutex = std::mutex;
using UniqueLock = std::unique_lock<std::mutex>;
using LockGuard = std::lock_guard<std::mutex>;
using CondVar = std::condition_variable;

inline thread_local bool in_parallel_region = false;

}  // namespace detail_threading
}  // namespace ducc0

#endif
