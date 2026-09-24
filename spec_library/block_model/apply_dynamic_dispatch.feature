Feature: apply() dynamic dispatch with arguments (GitHub issue #153)

  `apply(fname, a1, ..., an)` calls a DECLARED function by a
  runtime-computed name string, passing arguments. Neither `JumpBlock` nor
  the Phase 21 `Call` instruction can express it -- both bake a
  compile-time-literal callee name into the instruction. `CallDynamic`
  (commit 5b22750) covered only `apply(fname)`, zero arguments, as a bare
  statement -- scoped that way after checking only self_hosting/lib/
  test.patlang's own call sites, which missed self_hosting/lib/schema_bdd
  .patlang's own `apply(invariant_fn, state)` / `apply(require_fn, state,
  inputs)` / `let triple = apply(harness_fn, func_name)`, all with
  arguments and mostly in value context.

  `CallDynamic` now carries the extra-argument count as an operand. The
  lowerer pushes the arguments in written order, then the callee-name
  expression, then the current `__globals`; the interpreter pops them
  back off, resolves the callee block, and binds the arguments
  positionally to that block's own declared parameters, exactly as
  `Call` does for a statically named callee. A single shared lowering
  helper serves both value context (result kept on the stack) and bare
  statement context (result discarded), so the two cannot drift apart.

  Scenario: apply with zero, one, two and three arguments returns the callee's value in value context
    Given a program calling apply with 0, 1, 2 and 3 arguments, in value context and as a bare statement
    When it runs through bm_lower_program/bi_run
    Then every printed value matches exactly what pat --ir-run produces for the identical source

  Two failure paths that must be loud and specific rather than silent:
  more arguments than the callee declares (which would otherwise drop the
  extra ones with no error), and a name that matches no declared function
  (`bi_find_block` returns `false` for an unknown name rather than
  raising, which an earlier comment in this engine wrongly claimed it did).

  Scenario: apply with more arguments than the callee declares fails loudly, naming the callee and both counts
    Given a program calling apply on a one-parameter function with two arguments
    When it runs through bm_lower_program/bi_run
    Then it fails with a contract violation naming the callee and both counts, and never runs the statement after the call

  Scenario: apply with a name that matches no declared function fails loudly, naming the missing function
    Given a program calling apply with a name no declared function has
    When it runs through bm_lower_program/bi_run
    Then it fails with a contract violation naming the missing function, and never runs the statement after the call
