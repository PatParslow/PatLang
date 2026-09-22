Feature: cooperative yielding via fiber_yield (Phase 14 of the full-language expansion)

  Scoped deliberately to the cooperative half of concurrency (fibers),
  checked before writing code: `self_hosting/examples/fiber_demo.patlang`'s
  own header states fibers are "implemented on real OS threads under the
  hood... but never actually running concurrently -- a mutex+condvar pair
  ensures only one fiber's thread is ever unparked at a time... distinct
  from parallel_map, which IS real parallelism." That means letting a
  block-model program call fiber_yield needs no refcount-thread-safety
  design at all -- there is no real parallelism to race. Phase 8's own
  debugger (bi_debug_run) already proved fiber_yield works at this
  engine's level, from the OUTSIDE; this phase lets a block-model SOURCE
  PROGRAM call it from the INSIDE, as an ordinary mid-block instruction
  (never ends the block, the same category as Print and Emit).

  Real OS-thread parallelism (thread_spawn, parallel_map) is explicitly
  NOT covered here -- that's where a genuine refcount-thread-safety design
  question would apply, and Box (this engine's own refcounted mechanism)
  is native-x64-only, so it can't even be exercised under the self-hosted
  interpreter this phase is scoped to. Deferred to whenever native codegen
  for the full language (Phase 19) makes it testable, named here rather
  than silently skipped.

  Scenario: a block-model program can pause itself mid-execution via fiber_yield, resumable from outside
    Given a block-model program that yields its own progress value on each of several jump-chained steps
    When an outside driver wraps running it in a fiber and resumes it one step at a time
    Then each resume returns the correct, changing progress value in order

  Scenario: after the program finishes, the fiber reports its own completion correctly
    Given the same program, resumed past its last yield
    When the final resume runs
    Then the program's own remaining work completes (its own final print still happens) and the fiber is no longer alive
