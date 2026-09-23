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

  Scenario: a while nested inside an if, itself inside another while, runs correctly (Phase 22)
    Given a loop whose body contains an if with its own nested while
    When the loop runs to completion
    Then the nested loop's own effect is counted correctly across every outer iteration that reaches it

  Phase 5's own original restriction ("a `while` reached [nested inside
  an if/else] hits bm_lower_unsupported, named plainly") is lifted here:
  an `if` whose then/else contains a `while` now gets the same real
  block split a top-level `while` always has
  (`bm_lower_if_with_nested_while`, self_hosting/block_model/lower
  .patlang), generalizing `bm_lower_while`'s own "hand the code after
  the loop to a synthesized exit block" pattern from `while` to `if`.

  A second, real, PRE-EXISTING bug (not introduced by the `if`-nesting
  work above, confirmed via a minimal repro with no `if` involved at
  all -- a plain `while` directly nested inside another `while`, with a
  value read only AFTER the inner loop) was found and fixed proving
  this: the outer loop's own false-path/exit-transfer code lives,
  textually, INSIDE its own head block's own scope, so it needs access
  to whatever the code AFTER the loop needs too, not just the loop
  BODY's own free variables — which is all `captured` used to be. A
  value referenced only after a loop, never inside its own body,
  crashed with "unbound in this block's own pointer" the instant such a
  shape was tested, since the loop head's own declared params (computed
  from the body's own free vars alone) never included it in the first
  place. Fixed by unioning the body's own free vars with free vars of
  "everything after the loop" (and whatever the enclosing continuation
  itself needs) — confirmed this union still correctly EXCLUDES a value
  referenced nowhere at all (this feature's own existing "outer local"
  scenario above, and `free_variable_capture.feature`'s own dedicated
  precision scenarios, both re-verified passing unchanged, not merely
  assumed unaffected).

  This whole fix is built on a new, general mechanism, not a one-off
  patch for this specific shape: `bm_lower_top_level_stmt_list` now
  takes an explicit CONTINUATION parameter (a tagged value, `["none"]`
  or `["jump", target_name, captured, jump_params]`, applied via a new
  `bm_apply_continuation` at whatever point turns out to be this
  statement list's own actual natural end) instead of assuming the
  natural end is always "just stop" -- correctly threading "what happens
  next" through however many levels of nested `while`/`if` a function's
  body actually has, not just one.
