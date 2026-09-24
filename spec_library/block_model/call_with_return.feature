Feature: call-with-return for ordinary functions (Phase 21 of the full-language expansion)

  The real blocker Phase 18 found and precisely diagnosed: a block-model
  function could only "return" via a tail call to another declared block
  (`JumpBlock`) -- there was no mechanism for returning a plain computed
  value, which real library code needs constantly (`let x = helper(5) +
  1`). Generalizes the exact design Fork A's own `Emit` already proved
  (Phase 10/19): a bounded sub-execution with a real return, just no
  longer restricted to event handlers.

  For the interpreter specifically (this feature), no classification or
  flattening distinction is needed at all -- `bi_run`/`bi_run_block`
  never concatenate blocks into one array in the first place (that's a
  native-x64-codegen-only artifact, Phase 9's own optimization); a
  function call with return is just an ordinary recursive invocation of
  the SAME "run a block, follow jump outcomes, stop at halt" loop
  `bi_run`'s own top-level loop already was, generalized into a new
  `bi_run_from` helper. Recursion (direct or mutual) works for free,
  handled by the HOST interpreter's own real call stack -- a genuine,
  incidental capability gain over the flat model, which cannot express
  recursion at all. Existing `JumpBlock`-based tail-call sites are left
  completely unchanged -- this is purely additive, not a replacement.

  Two new block-model instructions: `Call` (pops args + the current
  `__globals`, in the same written-order convention `JumpBlock` already
  uses, recurses via `bi_run_from`, pushes the result, updates the
  caller's own `__globals` to the callee's final one) and `ReturnValue`
  (pops one value, ends the current `bi_run_block` call immediately with
  it -- reachable anywhere in a block's own instrs, including nested
  inside if/else, not only at the textual end).

  Scenario: a declared function called as a sub-expression, its result used in further computation
    Given a function that returns a computed value, called from inside a larger expression
    When it runs through bm_lower_program/bi_run
    Then the result matches exactly what pat --ir-run produces for the identical source

  Scenario: direct recursion works
    Given a recursive function computing a factorial
    When it runs through bm_lower_program/bi_run
    Then it computes the correct result

  A third, more severe finding turned up while re-attempting Phase 18's
  own checkpoint one level further out (self_hosting/schema_bdd_selftest
  .patlang's own run_schema_bdd_selftest calls several declared functions
  as ordinary BARE statements in sequence, each expected to run in turn):
  a bare-statement call to a declared function ALWAYS lowered via
  `JumpBlock` -- a one-way, non-returning transfer -- correct only when
  that call is genuinely the very last thing that ever runs. Reached
  anywhere else (more statements after it in the same list, or as the
  last statement of an ordinary if/else branch, since
  `bm_lower_stmt_list` threads no continuation information through at
  all), it silently discarded every statement written after it, with NO
  ERROR of any kind. Confirmed via two minimal repros before fixing:
  `a(); b(); print(999)` printed only `a`'s own output; an `if true then
  helper() end` followed by `print(999)` never reached that `print`
  either. Fixed by using the SAME `Call`+discard convention already
  established for `apply()`/the generic `CallHost` fallback everywhere
  this bare call is NOT provably the enclosing list's own final
  statement with nothing pending afterward -- that one safe shape keeps
  using `JumpBlock` (checked directly: no currently-passing
  native_codegen_check.sh fixture relies on the bug this removes, since
  every native fixture with a bare declared-function call already uses it
  only in that genuinely safe position).

  Scenario: a bare-statement call to a declared function is followed by more code, which still runs
    Given a function that calls two other declared functions as bare statements, then prints a value of its own
    When it runs through bm_lower_program/bi_run
    Then all three effects happen in order, matching exactly what pat --ir-run produces for the identical source

  Scenario: a bare-statement call inside an ordinary if branch is followed by more code after the whole if
    Given an if branch whose only statement is a bare call to a declared function, followed by a print after the if
    When it runs through bm_lower_program/bi_run
    Then the print after the if still runs, matching exactly what pat --ir-run produces for the identical source

  Native x64 codegen for `Call`/`ReturnValue` needed a genuinely different
  design -- each qualifying function compiled as its own separate FuncIR
  returning `[value, updated_globals]`, since native's own
  flattened-vs-separate-FuncIR distinction is real where the
  interpreter's is not. It was deferred when this feature was written and
  has since been done (GitHub issue #173, together with `CallDynamic`):
  see spec_library/block_model/native_codegen.feature's own call-with-return
  scenarios, and docs/plans/block-ownership-model-full-language-plan.md's
  Phase 21 and Phase 23 sections.

  A regression in the fix above (GitHub issue #157), and an instructive one:
  the special case that keeps `JumpBlock` for a bare call that is genuinely
  the LAST statement of its function returned the bare instruction list,
  where every other return path of `bm_lower_top_level_stmt_list` returns the
  `[instrs, pending]` pair. Its caller read the first instruction as
  `instrs` and the second as the synthesized-block list, so a function ending
  in a bare call to another declared function crashed with an unknown
  instruction. No fixture reached that branch when it was written -- every
  earlier bare-call fixture had the call followed by another statement or
  inside an `if`, and the native suite (which uses `return F()`, a different
  path) could not exercise it either. It surfaced the first time a real
  program ended a body with a bare call: a script-style selftest's closing
  `t_report()`.

  Scenario: a bare-statement call that is the last statement of its function runs and returns control correctly
    Given a function whose final statement is a bare call to another declared function
    When it runs through bm_lower_program/bi_run
    Then both functions' output appears, matching exactly what pat --ir-run produces for the identical source
