Feature: debugger parity via a bounded jump-history trail (Block Ownership Model, Fork A)

  Fork A's one identified real gap (docs/plans/block-ownership-model.md,
  section 6): this engine has no call stack at all, so an equivalent of
  "how did we get here" needs an explicit jump-history trail rather than
  a real call stack's own view. self_hosting/block_model/interp.patlang's
  bi_debug_run is bi_run's own execution loop, runnable as a real fiber
  (fiber_new/fiber_yield/fiber_resume/fiber_alive) so an external caller
  can genuinely pause it mid-execution and query the trail, not just
  finish it and inspect a result. Checked directly before relying on it:
  these fiber primitives are special-cased in the Rust interpreter's own
  instruction dispatch (rust-runtime/src/ir/interpreter.rs), representation-
  agnostic, exactly Fork A's own finding about the real debugger's
  pause/resume mechanism -- not something only the native backend
  provides. Runs entirely under the interpreter.

  Scenario: pausing mid-execution returns a real, changing trail of the last jumps
    Given a program that jumps through three distinct blocks before finishing
    When it is resumed one block at a time via a real fiber
    Then each pause returns a longer, genuinely different trail than the last, ending with the correct final result

  Scenario: the trail is bounded, not a growing log
    Given a program chaining more blocks than the trail's own cap
    When it runs to completion one block at a time
    Then the trail never exceeds its cap and always shows the most recent blocks
