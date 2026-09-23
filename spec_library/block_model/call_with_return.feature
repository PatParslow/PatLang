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

  Native x64 codegen for `Call`/`ReturnValue` (which needs a genuinely
  different design -- classification by call site, closed under one
  additional fixed-point rule, and each qualifying function compiled as
  its own separate FuncIR returning `[value, updated_globals]`, since
  native's own flattened-vs-separate-FuncIR distinction is real where
  the interpreter's is not) is explicitly deferred, not attempted in
  this pass -- see docs/plans/block-ownership-model-full-language-plan
  .md's own Phase 21 section for the recorded design.
