/*
 *  Copyright 2021 NVIDIA Corporation
 *
 *  Licensed under the Apache License, Version 2.0 with the LLVM exception
 *  (the "License"); you may not use this file except in compliance with
 *  the License.
 *
 *  You may obtain a copy of the License at
 *
 *      http://llvm.org/foundation/relicensing/LICENSE.txt
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

#pragma once

#include <nvbench/blocking_kernel.cuh>
#include <nvbench/cpu_timer.cuh>
#include <nvbench/cuda_call.cuh>
#include <nvbench/cuda_timer.cuh>
#include <nvbench/device_info.cuh>
#include <nvbench/exec_tag.cuh>
#include <nvbench/launch.cuh>

#include <nvbench/detail/kernel_launcher_timer_wrapper.cuh>
#include <nvbench/detail/l2flush.cuh>
#include <nvbench/detail/statistics.cuh>

#include <cuda_runtime.h>

#include <algorithm>
#include <utility>
#include <vector>

namespace nvbench
{

struct state;

namespace detail
{

// non-templated code goes here:
struct measure_cold_base
{
  explicit measure_cold_base(nvbench::state &exec_state);
  measure_cold_base(const measure_cold_base &) = delete;
  measure_cold_base(measure_cold_base &&)      = delete;
  measure_cold_base &operator=(const measure_cold_base &) = delete;
  measure_cold_base &operator=(measure_cold_base &&) = delete;

protected:
  template <bool use_blocking_kernel>
  struct kernel_launch_timer;

  void check();

  void initialize()
  {
    m_total_cuda_time = 0.;
    m_total_cpu_time  = 0.;
    m_cuda_noise      = 0.;
    m_cpu_noise       = 0.;
    m_total_samples   = 0;
    m_cuda_times.clear();
    m_cpu_times.clear();
    m_max_time_exceeded = false;
  }

  void generate_summaries();

  void check_skip_time(nvbench::float64_t warmup_time);

  __forceinline__ void flush_device_l2()
  {
    m_l2flush.flush(m_launch.get_stream());
  }

  __forceinline__ void sync_stream() const
  {
    NVBENCH_CUDA_CALL(cudaStreamSynchronize(m_launch.get_stream()));
  }

  void block_stream();

  __forceinline__ void unblock_stream() { m_blocker.unblock(); }

  nvbench::state &m_state;

  nvbench::launch m_launch;
  nvbench::cuda_timer m_cuda_timer;
  nvbench::cpu_timer m_cpu_timer;
  nvbench::cpu_timer m_timeout_timer;
  nvbench::detail::l2flush m_l2flush;
  nvbench::blocking_kernel m_blocker;

  nvbench::int64_t m_min_samples{};
  nvbench::float64_t m_max_noise{}; // rel stdev
  nvbench::float64_t m_min_time{};

  nvbench::float64_t m_skip_time{};
  nvbench::float64_t m_timeout{};

  nvbench::int64_t m_total_samples{};
  nvbench::float64_t m_total_cuda_time{};
  nvbench::float64_t m_total_cpu_time{};
  nvbench::float64_t m_cuda_noise{}; // rel stdev
  nvbench::float64_t m_cpu_noise{};  // rel stdev

  std::vector<nvbench::float64_t> m_cuda_times;
  std::vector<nvbench::float64_t> m_cpu_times;

  bool m_max_time_exceeded{};
};

template <bool use_blocking_kernel>
struct measure_cold_base::kernel_launch_timer
{
  kernel_launch_timer(measure_cold_base &measure)
      : m_measure{measure}
  {}

  __forceinline__ void start()
  {
    m_measure.flush_device_l2();
    m_measure.sync_stream();
    if constexpr (use_blocking_kernel)
    {
      m_measure.block_stream();
    }
    m_measure.m_cuda_timer.start(m_measure.m_launch.get_stream());
    if constexpr (!use_blocking_kernel)
    {
      m_measure.m_cpu_timer.start();
    }
  }

  __forceinline__ void stop()
  {
    m_measure.m_cuda_timer.stop(m_measure.m_launch.get_stream());
    if constexpr (use_blocking_kernel)
    {
      m_measure.m_cpu_timer.start();
      m_measure.unblock_stream();
    }
    m_measure.sync_stream();
    m_measure.m_cpu_timer.stop();
  }

private:
  measure_cold_base &m_measure;
};

template <typename KernelLauncher, bool use_blocking_kernel>
struct measure_cold : public measure_cold_base
{
  measure_cold(nvbench::state &state, KernelLauncher &kernel_launcher)
      : measure_cold_base(state)
      , m_kernel_launcher{kernel_launcher}
  {}

  void operator()()
  {
    this->check();
    this->initialize();
    this->run_warmup();
    this->run_trials();
    this->generate_summaries();
  }

private:
  // Run the kernel once, measuring the GPU time. If under skip_time, skip the
  // measurement.
  void run_warmup()
  {
    kernel_launch_timer<use_blocking_kernel> timer(*this);
    this->launch_kernel(timer);
    this->check_skip_time(m_cuda_timer.get_duration());
  }

  void run_trials()
  {
    m_timeout_timer.start();
    kernel_launch_timer<use_blocking_kernel> timer(*this);

    do
    {
      this->launch_kernel(timer);

      const auto cur_cuda_time = m_cuda_timer.get_duration();
      const auto cur_cpu_time  = m_cpu_timer.get_duration();
      m_cuda_times.push_back(cur_cuda_time);
      m_cpu_times.push_back(cur_cpu_time);
      m_total_cuda_time += cur_cuda_time;
      m_total_cpu_time += cur_cpu_time;
      ++m_total_samples;

      // Only consider the cuda noise in the convergence criteria.
      m_cuda_noise = nvbench::detail::compute_noise(m_cuda_times,
                                                    m_total_cuda_time);

      m_timeout_timer.stop();
      const auto total_time = m_timeout_timer.get_duration();

      if (m_total_cuda_time > m_min_time &&  // Min time okay
          m_total_samples > m_min_samples && // Min samples okay
          m_cuda_noise < m_max_noise)        // Noise okay
      {
        break;
      }

      if (total_time > m_timeout) // Max time exceeded, stop iterating.
      {
        m_max_time_exceeded = true;
        break;
      }
    } while (true);
    m_cpu_noise = nvbench::detail::compute_noise(m_cpu_times, m_total_cpu_time);
  }

  template <typename TimerT>
  __forceinline__ void launch_kernel(TimerT &timer)
  {
    m_kernel_launcher(m_launch, timer);
  }

  KernelLauncher &m_kernel_launcher;
};

} // namespace detail
} // namespace nvbench
