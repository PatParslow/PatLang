Feature: full pattern matching (Phase 11 of the full-language expansion)

  Extends design doc section 4.1's own finding ("forks don't need their own
  boundary" -- verified there only for if/else) to match/case: reuses the
  real self-hosted compile_pattern's own desugaring exactly (a pattern
  becomes a boolean test expression plus zero or more binding Let
  statements, JumpIfFalse-chained arm by arm, matching lower_match's own
  reasoning for evaluating bindings before a guard) rather than inventing
  a new pattern-compilation scheme for this engine.

  Scoped deliberately, not silently: this phase covers PWild, PBind, PLit,
  and PCmp (with an optional `when` guard) -- the four pattern kinds
  expressible with this engine's existing Const/Var/Bin expression
  lowering. PGlob and PList are explicitly out of scope here (named
  plainly, checked before writing code, not discovered as a gap later):
  PGlob needs a generic host-function-call expression (glob_match), and
  PList needs Member/Index expression support plus real List values --
  neither exists in this engine yet (System integration, Phase 17, and
  general host-call breadth are what would unlock them).

  Scenario: a wildcard arm matches anything that reaches it
    Given a match with a literal arm that doesn't match, followed by a wildcard arm
    When it runs
    Then the wildcard arm's body runs

  Scenario: a bind pattern makes the scrutinee available under a new name in the arm body
    Given a match whose only arm binds the scrutinee to a new name
    When it runs
    Then the arm body can use that name and sees the scrutinee's own value

  Scenario: a literal pattern matches only its exact value
    Given a match with two literal arms and a wildcard fallback
    When the scrutinee equals the second literal arm's value
    Then exactly that arm's body runs, not the first literal arm's or the wildcard's

  Scenario: a comparison pattern with a guard clause only matches when the guard holds too
    Given a match with a bind-and-guard arm ("case n when n > 100 then ...") followed by a plain bind fallback
    When the scrutinee fails the guard
    Then control falls through to the fallback arm, not the guarded one

  Scenario: an unmatched scrutinee with no wildcard arm is a guaranteed-fail error, not a silent no-op
    Given a match with only literal arms and no wildcard, run against a scrutinee none of them match
    When it runs
    Then it fails with a guaranteed error naming that no arm matched

  List patterns. `case [1, x]` matches a value that is a list of exactly that
  length whose elements match their own sub-patterns, binding names as it goes,
  as the real lowerer's compile_list_pattern does; the length is only asked of
  something already known to be a list, because `and` short-circuits. Three real
  programs (parser_harness, shape_smoke and the router DSL demo) used them and
  were rejected as "match pattern kind 'PList'".

  Scenario: list patterns bind elements and fall through exactly as the real engine does
    Given a function matching an empty list, a literal-and-binding list and a literal-and-two-bindings list, with a string and a number that match no list arm
    When it runs through bm_lower_program/bi_run
    Then it prints the same six lines as pat --ir-run does for the identical source
