Feature: design by contract (Phase 12 of the full-language expansion)

  `require`/`ensure`/`assert` already lower, in the real self-hosted
  lower.patlang, to a single `contract_check(func_name, kind, text, ok)`
  host call -- a guaranteed-fail check when `ok` is false, a no-op
  continuation when true. This engine has no generic host-function-call
  expression support yet (Phase 17's own job), so this phase reuses its
  existing ContractFail instruction (already used for the immutable-
  reassignment and no-arm-matched cases) behind a JumpIfFalse instead of a
  real contract_check host call -- the observable behaviour (aborts with a
  named message when the condition is false, silently continues when
  true) matches; the exact host-call shape does not yet.

  Checked directly, not assumed: this phase's own contracts are entirely
  independent of the flight check (Fork C, Phase 7) -- the flight check's
  own bounded points-to/shape analysis is sized to proving `mut`
  exclusivity for box_set call sites specifically, and has nothing to say
  about an arbitrary boolean expression's truth value. A require/ensure/
  assert is never subsumed by it, and never will be under this design;
  the two are orthogonal concerns, not a case of "not yet wired together."

  Scenario: a true require/ensure/assert never aborts and the program continues normally
    Given a block whose require, ensure, and assert conditions are all true
    When it runs
    Then the program continues past every one of them and produces its normal result

  Scenario: a failing require aborts before the block's own body runs
    Given a block whose first statement is a require that evaluates to false
    When it runs
    Then it fails with a guaranteed error naming the require, and no later statement in the body ever runs

  Scenario: a failing ensure aborts after the block's body ran but before it jumps onward
    Given a block that runs its own body, then hits a failing ensure, then would jump to another block
    When it runs
    Then the block's own body already ran, the failure is reported, and the next block's own body never runs

  Scenario: an assert fails at the exact point it's written, mid-body
    Given a block with a statement before a failing assert and a statement after it
    When it runs
    Then the statement before the assert already ran and the statement after it never does
