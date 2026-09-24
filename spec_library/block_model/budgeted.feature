Feature: budgeted blocks over fibers (GitHub issue #176, budgeted half)

  `budgeted(ms[, handle]) { body }` is an expression that runs its body for at
  most `ms` milliseconds and evaluates to `["done", value]` or `["paused",
  handle]`; passing the handle back as the second argument resumes the same
  body exactly where it stopped. It is cooperative multitasking, which is what
  lets a status/quit signal loop get a turn while a long job runs.

  The real lowerer compiles the body to a synthesized function run by the host
  `budgeted_run` inside a fiber, and injects `budget_check` (which yields once
  the deadline is near) at every `while` back-edge lexically inside the body.
  A host function cannot call back into a block-model function, so block-model
  reuses what it already has: the body is lowered exactly as a zero-parameter
  closure (issue #182, capture by value), the interpreter itself intercepts
  `bm_budgeted_run` -- it alone holds the running program -- and starts a real
  fiber whose entry function is the interpreter running that closure block, and
  a `while` inside the body gets a `budget_check` on its back-edge continuation.
  A fiber is an OS thread whose own call stack is the saved state, so
  resumption needs no state-saving machinery in the block model.

  Two limits, stated rather than glossed over. The body receives the
  `__globals` in force when its block was entered and its own changes to
  globals are not written back to the caller (the real engine's globals are
  ambient and would be). Interpreter only: native and WASM reject a program
  using it, since the fiber host functions are not part of that runtime.

  Scenario: a block that finishes within its budget, and a zero budget resumed to completion, match the real engine
    Given a function whose budgeted block sums 0..4 with a generous budget, then again with a zero budget driven by a caller loop that hands the returned handle back
    When it runs through bm_lower_program/bi_run
    Then it prints done, 10, then 10 and a nonzero pause count, exactly as pat --ir-run does for the identical source
