# Queries

* `--list`, `-l`
  * List all devices and benchmarks without running them.

* `--help`, `-h`
  * Print usage information and exit.

* `--help-axes`, `--help-axis`
  * Print axis specification documentation and exit.

# Output

* `--csv <filename/stream>`
  * Write CSV output to a file, or "stdout" / "stderr".

* `--json <filename/stream>`
  * Write JSON output to a file, or "stdout" / "stderr".

* `--markdown <filename/stream>`, `--md <filename/stream>`
  * Write markdown output to a file, or "stdout" / "stderr".
  * Markdown is written to "stdout" by default.

* `--quiet`, `-q`
  * Suppress output.

* `--color`
  * Use color in output (markdown + stdout only).

# Benchmark / Axis Specification

* `--benchmark <benchmark name/index>`, `-b <benchmark name/index>`
  * Execute a specific benchmark.
  * Argument is a benchmark name or index, taken from `--list`.
  * If not specified, all benchmarks will run.
  * `--benchmark` may be specified multiple times to run several benchmarks.
  * The same benchmark may be specified multiple times with different
    configurations.

* `--axis <axis specification>`, `-a <axis specification>`
  * Override an axis specification.
  * See `--help-axis`
    for [details on axis specifications](./cli_help_axis.md).
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

# Benchmark Properties

* `--devices <device ids>`, `--device <device ids>`, `-d <device ids>`
  * Limit execution to one or more devices.
  * `<device ids>` is a single id, or a comma separated list.
  * Device ids can be obtained from `--list`.
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

* `--min-samples <count>`
  * Gather at least `<count>` samples per measurement.
  * Default is 10 samples.
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

* `--min-time <seconds>`
  * Accumulate at least `<seconds>` of execution time per measurement.
  * Default is 0.5 seconds.
  * If both GPU and CPU times are gathered, this applies to GPU time only.
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

* `--max-noise <value>`
  * Gather samples until the error in the measurement drops below `<value>`.
  * Noise is specified as the percent relative standard deviation.
  * Default is 0.5% (`--max-noise 0.5`)
  * Only applies to Cold measurements.
  * If both GPU and CPU times are gathered, this applies to GPU noise only.
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

* `--skip-time <seconds>`
  * Skip a measurement when a warmup run executes in less than `<seconds>`.
  * Default is -1 seconds (disabled).
  * Intended for testing / debugging only.
  * Very fast kernels (<5us) often require an extremely large number of samples
    to converge `max-noise`. This option allows them to be skipped to save time
    during testing.
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.

* `--timeout <seconds>`
  * Measurements will timeout after `<seconds>` have elapsed.
  * Default is 15 seconds.
  * `<seconds>` is walltime, not accumulated sample time.
  * If a measurement times out, the default markdown log will print a warning to
    report any outstanding termination criteria (min samples, min time, max
    noise).
  * Applies to the most recent `--benchmark`, or all benchmarks if specified
    before any `--benchmark` arguments.
