Feature: loops as back-edge blocks (Block Ownership Model, section 4.1)

  Section 4.1 (docs/plans/block-ownership-model.md) decided a `while` body
  is its own block, entered by a genuine back edge -- the model's own
  jump-with-a-pointer mechanic applied to the case where the next block
  happens to be the current one. self_hosting/block_model/lower.patlang
  synthesizes a loop-head block (the back edge) and a loop-exit block
  (whatever textually followed the loop), both taking a WHOLESALE-captured
  `inherited` section (every name known before the `while` was reached --
  Fork E's real free-variable analysis is Phase 6's own, later job). Runs
  entirely under the interpreter (no Box involved).

  Scenario: an outer local, never reassigned by the loop, is visible on every iteration
    Given a loop whose body reads a local set once before the loop started
    When the loop runs several iterations
    Then every iteration sees that outer local's value correctly

  Scenario: a scratch local declared inside the loop body does not survive iterations
    Given a loop whose body declares and increments a scratch local from scratch each time
    When the loop runs several iterations
    Then the scratch local never carries a value forward from the previous iteration

  Scenario: an if/else inside a loop body needs no extra block boundary
    Given a loop body containing an ordinary if/else
    When the loop runs to completion
    Then the if/else behaves exactly as it would outside a loop
