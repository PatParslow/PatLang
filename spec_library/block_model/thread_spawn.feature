Feature: thread_spawn, thread_poll and thread_result from block-model source (GitHub issue #184)

  Follow-up to #176, which made the refcounted heap thread-safe and left
  thread_spawn from block-model source explicitly out of scope: block-model
  closures are lists (["__closure", block_name, [captured...]], #182), while
  the x64 runtime's own thread_spawn(closure) reads [code_addr][captured_count]
  [captured...] directly off a closure's raw memory -- no code address a
  block-model closure value has at all.

  Fixed without any new native asm: a tiny helper, written as ordinary
  block-model source ("bm_closure_entry(name, captured) = apply(name,
  captured)"), is spliced into a program's own statement list ONLY when it
  calls thread_spawn (unconditional injection would force bm_nc_call_roots's
  "any CallDynamic anywhere makes every declared function a call root" rule
  onto every native compile, not just ones using it). thread_spawn(closure)
  then builds a REAL native closure (an ordinary MakeClosure) pointed at this
  helper, with the closure's own block_name and captured list as two of its
  three captured values -- the third is a fresh, empty globals list, because
  every block-model function, this helper included, carries an implicit
  trailing __globals parameter (Fork B's own universal convention) that the
  thread trampoline's push count must account for. thread_result(id) unwraps
  the [value, globals] pair the helper's own "callee" return convention
  produces, since the trampoline has no idea about that convention and
  stores it verbatim.

  thread_poll/thread_result reach the real runtime functions through the
  existing generic-CallHost-fallback + bm_patc_resolve_instrs promotion
  (CallHost -> Call for any name the runtime defines) -- no new code needed
  for those two beyond thread_result's own unwrap.

  thread_spawn has no interpreter equivalent to compare against: the real
  engine's own thread_spawn is native-x64-only (docs/plans/block-ownership-
  model-thread-safety.md's own "What is actually at risk" section), so
  block-model's interpreter rejects it outright rather than inventing a
  synchronous fallback the real engine has no counterpart for -- confirmed
  by spec_fixtures/thread_spawn_basic.patlang, which runs the identical
  spawn/poll/result program through bm_lower_program/bi_run and expects the
  "thread_spawn is native-x64-only" contract failure, not a crash or a
  silently-wrong answer. Native success is checked separately, by
  self_hosting/block_model/tools/thread_spawn_check.sh (races are
  probabilistic, so it runs the executable five times and requires every run
  correct).

  The heap-thread-safety precondition from #176 (the free-list table must be
  the first allocation) still holds here unchanged: this fixture, like every
  other block-model-native program, has no runtime class declaration ahead
  of its own heap init, and thread_spawn's own lowering does not add one.

  Scenario: a closure capturing a value, run on a real spawned thread, computes the right result and the program exits cleanly
    Given a zero-param closure capturing x = 21 that returns x * 2, spawned via thread_spawn, polled until done, then read back with thread_result
    When the program is built as a native executable and run five times
    Then every run prints 42 then "ok", never a crash on the way out
