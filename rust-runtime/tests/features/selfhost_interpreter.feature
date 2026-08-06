# Guards against: the self-hosted meta-circular interpreter
# (self_hosting/lib/interp.patlang, `interpret_ir`) drifting silently, since
# nothing wired it into `cargo test` when it was first built (2026-07-24,
# see the patlang-selfhosted-interpreter-and-wasm-idea memory) -- until now
# only verified by hand-run smoke tests. Each scenario exercises one of the
# 4 slices built so far (arithmetic/control-flow, host calls/lists, user
# function recursion, closures) via patc1.exe's own `lower`+`interpret`
# subcommands -- the real, user-facing entry point, not internal test-only
# plumbing -- so a regression in the CLI wiring is caught here too, not just
# a regression in `interp.patlang` itself.
#
# Scope note, corrected 2026-08-06 (see [issue: 5 scenarios silently
# failing since 86e4fef]): `interpret` used to always echo the program's
# own final return value on success -- these scenarios were originally
# written against THAT behavior. 86e4fef (2026-07-31) deliberately changed
# `interpret` to stay silent on success, matching `--ir-run`'s own
# convention exactly (only the program's own explicit `print()` calls
# produce output; the implicit final return value is never echoed) -- a
# real, reasoned fix for a genuine cosmetic bug, not a regression to
# revert. But every scenario here was never updated to match, so all 5
# started failing identically the moment that commit landed, and stayed
# broken for a week because nothing had run this exact feature file since.
# Fixed here by making each scenario `print()` the value under test
# explicitly, the same way any real PatLang program would, instead of
# relying on an implicit return-value echo that no longer exists.

Feature: Self-hosted meta-circular interpreter (interpret_ir)
  As a maintainer of the self-hosted PatLang compiler
  I want the meta-circular interpreter to correctly execute every
    instruction kind it claims to support
  So that a regression in interp.patlang or its CLI wiring is caught by
    `cargo test`, not by hand

  Scenario: Slice 1 -- arithmetic and operator precedence
    Given a PatLang program:
      """
      let x = 3 + 4 * 2
      print(x)
      """
    When I run it through the self-hosted meta-circular interpreter
    Then the self-hosted interpreter's output matches the expected value
      """
      11
      """

  Scenario: Slice 1 -- control flow (if/else via Jump/JumpIfFalse)
    Given a PatLang program:
      """
      let x = 10
      if x > 5 then
        print(100)
      else
        print(200)
      end
      """
    When I run it through the self-hosted meta-circular interpreter
    Then the self-hosted interpreter's output matches the expected value
      """
      100
      """

  Scenario: Slice 2 -- CallHost (print, list_len) and BuildList (list literals)
    Given a PatLang program:
      """
      let xs = [1, 2, 3]
      print(list_len(xs))
      print(list_get(xs, 1))
      """
    When I run it through the self-hosted meta-circular interpreter
    Then the self-hosted interpreter's output matches the expected value
      """
      3
      2
      """

  Scenario: Slice 3 -- recursive user-defined function calls
    Given a PatLang program:
      """
      make a function called fact takes n returns r
        if n <= 1 then
          return 1
        end
        return n * fact(n - 1)
      end
      print(fact(5))
      """
    When I run it through the self-hosted meta-circular interpreter
    Then the self-hosted interpreter's output matches the expected value
      """
      120
      """

  Scenario: Slice 4 -- closures (MakeClosure/CallValue, variable capture)
    Given a PatLang program:
      """
      make a function called make_adder takes n returns r
        return |x| { return x + n }
      end
      let add_three = make_adder(3)
      print(add_three(7))
      """
    When I run it through the self-hosted meta-circular interpreter
    Then the self-hosted interpreter's output matches the expected value
      """
      10
      """
