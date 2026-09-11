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
# Scope note, corrected AGAIN 2026-09-11 (the 2026-08-06 note below was
# itself wrong -- caught by asking "does the trailing value actually track
# the program's return value?" and testing it directly, rather than trusting
# the earlier diagnosis a second time): patc1_main.patlang's `interpret`
# handler was checked directly and does NOT echo the program's own return
# value on success -- it only ever prints on `Err`. The trailing "0" every
# scenario below sees is unrelated to what the *interpreted* program
# returns: `return 42` and `return x` (x=11) both still produced a bare "0"
# at the end, and the same "0" appears after `lower` too, which never runs
# the guest program's logic at all. It's an artifact of patc1_main.patlang's
# OWN top-level control flow -- itself a compiled PatLang program, with its
# own unrelated implicit-value leak, one layer up from the interpreted guest
# program `interpret` is executing. Fixing that properly means auditing
# patc1_main.patlang's own dispatch chain, which is a separate, larger piece
# of work than these scenarios need; fixed here pragmatically instead, by
# asserting the real, verified, current output (including the trailing "0")
# rather than the output either previous note incorrectly predicted.
#
# 2026-08-06 note (kept for history, superseded above): claimed `interpret`
# used to always echo the program's final return value, and that 86e4fef
# fixed it to stay silent on success -- neither half of that survived
# direct testing.

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
      0
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
      0
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
      0
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
      0
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
      0
      """
