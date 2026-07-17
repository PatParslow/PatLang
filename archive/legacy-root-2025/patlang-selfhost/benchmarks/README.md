# Patlang Interpreter/VM Performance Baseline

## Benchmarking Setup

- **Script:** [`benchmark_core_execution.rb`](patlang-selfhost/benchmarks/benchmark_core_execution.rb)
- **Samples:** Arithmetic, control flow, function, and string demos from [`examples/`](examples/)
- **Metrics:** Execution time (seconds), memory usage (via `memory_profiler`)
- **Runner:** Intended to invoke the interpreter via a Ruby host bridge (see script for details)

## Results

- **Status:** Benchmark harness created and ready.
- **Blocker:** Interpreter runner script (`ruby-host/runtime/evaluator_old.rb`) not found at expected location. No execution metrics could be collected.
- **Next Steps:** Provide or update the interpreter runner to enable execution of `.pat` files for benchmarking.

## How to Run

1. Ensure Ruby and the `memory_profiler` gem are installed.
2. Place or update the interpreter runner at the expected path, or adjust the script to point to the correct runner.
3. Run:
   ```sh
   ruby patlang-selfhost/benchmarks/benchmark_core_execution.rb
   ```
4. Results will be written to `benchmark_results.md` and memory profile files.

## Acceptance Criteria Reference

- M4 milestone requires: "perf baseline ≤ 2x Ruby interpreter on samples"
- This setup enables collection of such metrics once the runner is available.