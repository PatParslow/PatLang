# Guards against: type_of being the one piece of the reflection/
# transpilation work (see optimized-zooming-snowglobe.md) that MUST be a
# native runtime primitive rather than self-hosted PatLang -- self-hosted
# code has no way to see into the actual in-memory `Value` representation.
# Because it's native, it has its own failure modes a self-hosted test
# script can never catch: this feature caught two real bugs while landing
# type_of --
#   1. type_of wasn't in `Lowerer::is_allowed_host`'s allowlist
#      (ir/lowering.rs), so any call to it nested inside another call's
#      argument position (e.g. `print(type_of(1))`) was silently dropped at
#      lowering time -- no error, just missing output.
#   2. the compiled-native path's `Host::call` unconditionally coerces every
#      Int/Float argument down to a plain `Number(f64)` before dispatch
#      (`host_coerce_arg`), which made `type_of(1)` wrongly report "float"
#      instead of "int" when compiled, while the interpreter (which never
#      coerces) correctly said "int" -- a genuine interpreted-vs-compiled
#      divergence that only this kind of side-by-side parity check reveals.
# Both are fixed; these scenarios are the regression guard.

Feature: type_of runtime reflection
  As a maintainer of the one native reflection primitive
  I want type_of to agree across the interpreted and compiled paths
  So that a future change to argument coercion or host dispatch can't silently break it

  Scenario Outline: type_of agrees on a bare value, interpreted and compiled
    Given a PatLang program that prints "type_of(<expr>)"
    When I run it both interpreted and compiled
    Then both runs exit successfully
    And the interpreted and compiled outputs match exactly
    And it prints exactly "<expected>"

    Examples:
      | expr                            | expected |
      | 1                                | int      |
      | 1.5                              | float    |
      | "hello"                          | string   |
      | [1, 2, 3]                        | list     |
      | true                             | bool     |
      | sqrt(-4)                         | complex  |
      | 10 / 3                           | rational |
      | 9223372036854775807 + 1          | bigint   |

  # Regression case for bug #1 above: type_of nested directly inside another
  # call's argument position, not bound to a `let` first.
  Scenario: type_of works when nested directly inside print's argument
    Given a PatLang program that prints "type_of(1)"
    When I run it both interpreted and compiled
    Then both runs exit successfully
    And the interpreted and compiled outputs match exactly
    And it prints exactly "int"

  Scenario: type_of on an object property value compiles and runs natively
    Given a PatLang program:
      """
      new("Counter", "c1")
      print(type_of(get("c1", "type")))
      """
    When I run it both interpreted and compiled
    Then both runs exit successfully
    And the interpreted and compiled outputs match exactly
    And it prints exactly "string"
