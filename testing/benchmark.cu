#include <nvbench/benchmark.cuh>

#include <nvbench/callable.cuh>
#include <nvbench/named_values.cuh>
#include <nvbench/state.cuh>
#include <nvbench/type_list.cuh>
#include <nvbench/type_strings.cuh>
#include <nvbench/types.cuh>

#include "test_asserts.cuh"

#include <fmt/format.h>

#include <algorithm>
#include <utility>
#include <variant>
#include <vector>

template <typename T>
std::vector<T> sort(std::vector<T> &&vec)
{
  std::sort(vec.begin(), vec.end());
  return std::move(vec);
}

void no_op_generator(nvbench::state &state)
{
  fmt::memory_buffer params;
  fmt::format_to(params, "Params:");
  const auto &axis_values = state.get_axis_values();
  for (const auto &name : sort(axis_values.get_names()))
  {
    std::visit(
      [&params, &name](const auto &value) {
        fmt::format_to(params, " {}: {}", name, value);
      },
      axis_values.get_value(name));
  }

  // Marking as skipped to signal that this state is run:
  state.skip(fmt::to_string(std::move(params)));
}
NVBENCH_DEFINE_CALLABLE(no_op_generator, no_op_callable);

template <typename Integer, typename Float, typename Other>
void template_no_op_generator(nvbench::state &state,
                              nvbench::type_list<Integer, Float, Other>)
{
  ASSERT(nvbench::type_strings<Integer>::input_string() ==
         state.get_string("Integer"));
  ASSERT(nvbench::type_strings<Float>::input_string() ==
         state.get_string("Float"));
  ASSERT(nvbench::type_strings<Other>::input_string() ==
         state.get_string("Other"));

  // Enum params using non-templated version:
  no_op_generator(state);
}
NVBENCH_DEFINE_CALLABLE_TEMPLATE(template_no_op_generator,
                                 template_no_op_callable);

using int_list = nvbench::type_list<nvbench::int8_t,
                                    nvbench::int16_t,
                                    nvbench::int32_t,
                                    nvbench::int64_t>;

using float_list = nvbench::type_list<nvbench::float32_t, nvbench::float64_t>;

using misc_list = nvbench::type_list<bool, void>;

using lots_of_types_bench =
  nvbench::benchmark<template_no_op_callable,
                     nvbench::type_list<int_list, float_list, misc_list>>;

using no_types_bench = nvbench::benchmark<no_op_callable>;

void test_type_axes()
{
  lots_of_types_bench bench;
  bench.set_type_axes_names({"Integer", "Float", "Other"});

  fmt::memory_buffer buffer;
  const auto &axes = bench.get_axes().get_axes();
  for (const auto &axis : axes)
  {
    fmt::format_to(buffer, "Axis: {}\n", axis->get_name());
    const auto num_values = axis->get_size();
    for (std::size_t i = 0; i < num_values; ++i)
    {
      auto input_string = axis->get_input_string(i);
      auto description  = axis->get_description(i);
      fmt::format_to(buffer,
                     " - {}{}\n",
                     input_string,
                     description.empty() ? ""
                                         : fmt::format(" ({})", description));
    }
  }

  const std::string ref =
    R"expected(Axis: Integer
 - I8 (int8_t)
 - I16 (int16_t)
 - I32 (int32_t)
 - I64 (int64_t)
Axis: Float
 - F32 (float)
 - F64 (double)
Axis: Other
 - bool
 - void
)expected";

  const std::string test = fmt::to_string(buffer);
  ASSERT_MSG(test == ref,
             fmt::format("Expected:\n\"{}\"\n\nActual:\n\"{}\"", ref, test));
}

void test_type_configs()
{
  lots_of_types_bench bench;
  bench.set_type_axes_names({"Integer", "Float", "Other"});

  ASSERT(bench.num_type_configs == 16);

  std::size_t idx = 0;
  fmt::memory_buffer buffer;
  nvbench::tl::foreach<lots_of_types_bench::type_configs>(
    [&idx, &buffer]([[maybe_unused]] auto type_wrapper) {
      using Conf    = typename decltype(type_wrapper)::type;
      using Integer = nvbench::tl::get<0, Conf>;
      using Float   = nvbench::tl::get<1, Conf>;
      using Other   = nvbench::tl::get<2, Conf>;
      fmt::format_to(buffer,
                     "type_configs[{:2d}] = <{:>3}, {:>3}, {:>4}>\n",
                     idx++,
                     nvbench::type_strings<Integer>::input_string(),
                     nvbench::type_strings<Float>::input_string(),
                     nvbench::type_strings<Other>::input_string());
    });

  const std::string ref = R"type_config_ref(type_configs[ 0] = < I8, F32, bool>
type_configs[ 1] = < I8, F32, void>
type_configs[ 2] = < I8, F64, bool>
type_configs[ 3] = < I8, F64, void>
type_configs[ 4] = <I16, F32, bool>
type_configs[ 5] = <I16, F32, void>
type_configs[ 6] = <I16, F64, bool>
type_configs[ 7] = <I16, F64, void>
type_configs[ 8] = <I32, F32, bool>
type_configs[ 9] = <I32, F32, void>
type_configs[10] = <I32, F64, bool>
type_configs[11] = <I32, F64, void>
type_configs[12] = <I64, F32, bool>
type_configs[13] = <I64, F32, void>
type_configs[14] = <I64, F64, bool>
type_configs[15] = <I64, F64, void>
)type_config_ref";

  const std::string test = fmt::to_string(buffer);
  ASSERT_MSG(test == ref,
             fmt::format("Expected:\n\"{}\"\n\nActual:\n\"{}\"", ref, test));
}

void test_float64_axes()
{
  no_types_bench bench;
  bench.add_float64_axis("F64 Axis", {0., .1, .25, .5, 1.});
  ASSERT(bench.get_axes().get_axes().size() == 1);
  const auto &axis = bench.get_axes().get_float64_axis("F64 Axis");
  ASSERT(axis.get_size() == 5);
  ASSERT(axis.get_value(0) == 0.);
  ASSERT(axis.get_value(1) == .1);
  ASSERT(axis.get_value(2) == .25);
  ASSERT(axis.get_value(3) == .5);
  ASSERT(axis.get_value(4) == 1.);
}

void test_int64_axes()
{
  no_types_bench bench;
  bench.add_int64_axis("I64 Axis", {10, 11, 12, 13, 14});
  ASSERT(bench.get_axes().get_axes().size() == 1);
  ASSERT(bench.get_axes().get_axes()[0] != nullptr);
  const auto &axis = bench.get_axes().get_int64_axis("I64 Axis");
  ASSERT(axis.get_size() == 5);
  ASSERT(axis.get_value(0) == 10);
  ASSERT(axis.get_value(1) == 11);
  ASSERT(axis.get_value(2) == 12);
  ASSERT(axis.get_value(3) == 13);
  ASSERT(axis.get_value(4) == 14);
}

void test_int64_power_of_two_axes()
{
  no_types_bench bench;
  bench.add_int64_power_of_two_axis("I64 POT Axis", {1, 2, 3, 4, 5});
  ASSERT(bench.get_axes().get_axes().size() == 1);
  ASSERT(bench.get_axes().get_axes()[0] != nullptr);
  const auto &axis = bench.get_axes().get_int64_axis("I64 POT Axis");
  ASSERT(axis.get_size() == 5);
  ASSERT(axis.get_value(0) == 2);
  ASSERT(axis.get_value(1) == 4);
  ASSERT(axis.get_value(2) == 8);
  ASSERT(axis.get_value(3) == 16);
  ASSERT(axis.get_value(4) == 32);
}

void test_string_axes()
{
  no_types_bench bench;
  bench.add_string_axis("Strings", {"string a", "string b", "string c"});
  ASSERT(bench.get_axes().get_axes().size() == 1);
  ASSERT(bench.get_axes().get_axes()[0] != nullptr);
  const auto &axis = bench.get_axes().get_string_axis("Strings");
  ASSERT(axis.get_size() == 3);
  ASSERT(axis.get_value(0) == "string a");
  ASSERT(axis.get_value(1) == "string b");
  ASSERT(axis.get_value(2) == "string c");
}

void test_run()
{
  // More exhaustive testing is in runner.cu. This just tests that the
  // runner is called.
  no_types_bench bench;
  ASSERT(bench.get_states().empty());
  bench.run();
  ASSERT(bench.get_states().size() == 1);
}

int main()
{
  test_type_axes();
  test_type_configs();
  test_float64_axes();
  test_int64_axes();
  test_int64_power_of_two_axes();
  test_string_axes();
  test_run();
}