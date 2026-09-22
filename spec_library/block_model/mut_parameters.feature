Feature: mut parameters, wired to a real refcounted heap (Block Ownership Model, Forks C/D)

  Section 3.4 (docs/plans/block-ownership-model.md) extends `mut` from
  body-local `let` bindings to parameter declarations: a parameter without
  `mut` is read-only; a `mut` parameter permits mutation, checked before it
  happens via section 3.5's refcount rule. This phase wires Phase 1's
  standalone refcounted heap into Phase 2's block/jump engine for real, on
  a single new "Box" value (a one-cell mutable reference) -- see
  self_hosting/block_model/lower.patlang's own header for the `mut_`
  parameter-naming convention standing in for real `mut` syntax, which
  doesn't exist in self_hosting/lib/parser.patlang today. Native x64 only,
  like Phase 1 -- see spec_fixtures' own headers for why.

  Scenario: a mut parameter permits mutation, in place, at refcount 1
    Given a block with a mut parameter holding the only reference to a box
    When it mutates that box
    Then the same box is mutated in place, not cloned

  Scenario: a non-mut parameter rejects mutation with a guaranteed-fail error
    Given a block with a read-only parameter holding a reference to a box
    When it attempts to mutate that box
    Then it fails with a guaranteed error naming that parameter

  Scenario: a mut parameter clones rather than mutating in place when aliased
    Given a block with a mut parameter holding one of two live references to the same box
    When it mutates that box
    Then a fresh box is produced and the other reference's own value is untouched
