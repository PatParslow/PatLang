Feature: parallel_map over real threads (GitHub issue #176, threads half)

  `parallel_map(items, "fn")` calls the declared one-parameter function `fn` on
  every item across real OS threads and evaluates to the list of results, in
  item order. The real host looks `fn` up among the interpreter's own declared
  functions, so a block-model function is invisible to it. Block-model wraps
  each item as `[program, block name, item]` and has the real host map
  `bi_pmap_entry`, a declared function of the interpreter itself, which re-enters
  `bi_run_from` on the named block. The interpreter intercepts the `parallel_map`
  CallHost because it alone holds the running program.

  Limits, stated plainly. Workers share only the immutable program and their own
  item: a worker starts with empty `__globals` and its changes to globals are not
  written back. A worker that uses a Box is unsupported -- the refcounted heap is
  ambient, non-thread-safe state, which is exactly the refcount-thread-safety
  question Phase 14 deferred. `thread_spawn` is not covered here. Interpreter
  only: native and WASM reject the host name.

  Scenario: parallel_map over integers, strings and an empty list matches the real engine
    Given a function mapping square over five integers, measure over three strings, and square over an empty list
    When it runs through bm_lower_program/bi_run
    Then it prints the three results exactly as pat --ir-run does for the identical source
