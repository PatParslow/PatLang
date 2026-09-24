Feature: activate and action_bind (GitHub issue #177, second slice)

  `activate PLAN` runs the closures bound (by `action_bind`) to a plan's steps
  and stops at the first step that returns false. It was the part of #177 that
  needed first-class closures (#182).

  It is not a host call at all: host functions cannot call back into the
  interpreter to run a closure, so the real lowerer synthesizes ordinary
  control-flow AST -- `Let`/`While`/`If`/`Call` -- that walks the plan, looks up
  each step's bound closure with `action_lookup`, and calls it THROUGH A
  VARIABLE with the step's bound argument values as a single list. Block-model
  does the same, as an AST rewrite applied to a body before lowering (so the
  synthesized `let`s are seen by the bound-name analysis and the closure-call
  path handles the call like any other), for the two statement shapes the real
  lowerer recognizes: `let x = activate(P)` and a bare `activate(P)`. The four
  host functions behind it (`action_bind`, `action_lookup`, `action_base_name`,
  `action_label_args`) are served from this engine's host extension table
  (#159); `action_bind` stores whatever value it is given without a type check,
  so a list-encoded closure round-trips through it unchanged.

  Like `fact`/`query` and the rule/goal stores (Phase 15, #177's first slice),
  the action store is a process-wide thread-local outside `__globals`.

  Scenario: activate runs every bound closure, and stops at a failing step even though the plan is still found
    Given a goal with a three-step plan, every action bound to a closure returning true, then one action re-bound to fail for a specific step
    When it runs through bm_lower_program/bi_run
    Then activate returns true, then false, matching exactly what pat --ir-run produces for the identical source
