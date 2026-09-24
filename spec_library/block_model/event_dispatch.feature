Feature: event dispatch (Phase 10 of the full-language expansion)

  Checked directly against the real Rust interpreter before writing any of
  this, not assumed from the design doc's own earlier §8 claim ("a fired
  event is already... jump to a known block... almost for free"): `emit`
  is NOT a one-way jump. rust-runtime/src/ir/interpreter.rs's own
  CallHost("emit", ...) handling calls each registered handler via
  run_function -- a real call with a real return -- then execution resumes
  right where the emit() call site was. This engine has no call stack at
  all (Fork A), so this phase gives `emit` a narrowly-scoped, explicit
  exception rather than reintroducing calls generally: a handler block
  runs to completion as a bounded sub-execution, and is not itself allowed
  to JumpBlock to another declared function (checked at lowering time, not
  silently permitted) -- so there is nothing to unwind, and control
  genuinely returns to the emitting block afterward.

  A `when EVENT do ... end` block becomes its own synthesized BlockIR,
  reachable ONLY through the event table Emit consults -- never through an
  ordinary JumpBlock the way a declared function is. Its two auto-bound
  params (event_name, event_data) plus the usual hidden __globals section
  are the only things its body can see, matching every other block
  boundary's own isolation guarantee (design doc section 3.2).

  Scenario: an emitted event reaches its handler with exactly its declared payload
    Given a program that emits an event carrying a payload
    When it is lowered and run
    Then the handler prints the event name and the payload it declared

  Scenario: a handler sees only its own two auto-bound params, not the emitting block's locals
    Given a handler block that references a name only the emitting block declared
    When the event is emitted
    Then it fails with a guaranteed unbound-variable error naming that name, never printing its value

  Scenario: multiple handlers for the same event all fire, in registration order
    Given a program with two separate when blocks for the same event
    When the event is emitted once
    Then both handlers run, in the order they were declared

  Scenario: control returns to the emitting block after its handlers run
    Given a program that emits an event in the middle of a block, with more statements after it
    When it runs
    Then the statements after the emit call still execute, in the correct order

  Scenario: a handler's global write is visible to the emitting block immediately afterward
    Given a handler that sets a global
    When the event that triggers it is emitted
    Then the block that emitted it reads the updated global right after the emit call

  Scenario: a handler containing a while loop runs to completion (regression, Phase 21)
    Given a when handler whose body contains a while loop
    When the event is emitted
    Then the loop runs to completion and the handler's own statements after it also run

  A real, previously-shipped bug was found and fixed proving this
  scenario, not designed around in advance: this file's own header claim
  above ("a handler block runs to completion as a bounded sub-
  execution") and the lowering-side claim that a `while` loop is
  reachable inside a handler body "for free" were both only half true --
  Emit's own dispatch (Phase 19) made a single bare `bi_run_block` call
  and rejected the loop's own first `JumpBlock` (its back-edge, `jump`,
  not `halt`) as "attempted to jump to another block -- unsupported".
  Fixed in Phase 21 by rewiring Emit's own handler dispatch onto a new
  `bi_run_from` helper, which follows `jump` outcomes to completion the
  same way `bi_run`'s own top-level loop always did, instead of assuming
  one call suffices.

  Phase 10 lowered a handler body with empty declared-function tables because a
  handler ran as one bounded step with no way to follow a jump, so a handler
  calling a declared function fell through to the host-call path and failed
  ("host function 'shout' not supported"). Emit has run handlers through
  `bi_run_from` since Phase 21, which completes both jumps and value calls, so the
  tables are now passed for real (issue #178; the signal library's `when`
  handlers call `signal_reply`, an ordinary declared function).

  Scenario: a when-handler can call declared functions, as a value, as a bare statement, and in tail position
    Given a handler that stores a declared function's result and calls it again as a statement, and a second handler whose only statement is such a call
    When it runs through bm_lower_program/bi_run
    Then it prints the same lines in the same order as pat --ir-run does for the identical source
