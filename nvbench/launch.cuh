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

#include <nvbench/cuda_stream.cuh>

namespace nvbench
{

struct launch
{
  // move-only
  launch()               = default;
  launch(const launch &) = delete;
  launch(launch &&)      = default;
  launch &operator=(const launch &) = delete;
  launch &operator=(launch &&) = default;

  __forceinline__ const nvbench::cuda_stream &get_stream() const
  {
    return m_stream;
  };

private:
  nvbench::cuda_stream m_stream;
};

} // namespace nvbench
