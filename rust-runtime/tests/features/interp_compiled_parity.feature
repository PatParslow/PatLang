# Guards against: the interpreter (`--ir-run`) and the compiled-native path
# (`--patc`) silently disagreeing on behavior. `pat --compare` already does
# this by hand from the CLI, but nothing wired it into `cargo test` -- so a
# divergence introduced by, say, a chunk's hand-transcribed text drifting
# from the interpreter's real logic would only be found by someone manually
# running `--compare` on the right program, which is exactly how the
# Complex-boxing bug's *sibling* correctness risk (the two paths silently
# computing different results, as opposed to just different memory/speed)
# would have gone unnoticed. This feature diffs interpreted vs. compiled
# stdout, byte for byte, across a representative corpus.

Feature: Interpreted vs. compiled output parity
  As a maintainer of both PatLang execution paths
  I want the interpreter and the compiled-native binary to agree exactly
  So that the two paths never silently diverge in behavior

  Scenario Outline: <label> produces identical output interpreted and compiled
    Given a PatLang program that prints "<expr>"
    When I run it both interpreted and compiled
    Then both runs exit successfully
    And the interpreted and compiled outputs match exactly

    Examples:
      | label                       | expr                        |
      | integer arithmetic          | 6 * 7                       |
      | exact rational division     | 10 / 3                       |
      | float division               | 10.0 / 4.0                   |
      | bigint overflow promotion    | 9223372036854775807 + 1      |
      | complex from negative sqrt   | sqrt(-4)                     |
      | numeric_kind on a complex    | numeric_kind(sqrt(-4))       |
      | string concatenation         | "foo" + "bar"                |
      | list length                  | list_len([1, 2, 3, 4])       |

  Scenario: a real multi-feature program produces identical output interpreted and compiled
    Given a PatLang program:
      """
      make a function called fib takes n returns r
        if n < 2 then
          return n
        else
          return fib(n - 1) + fib(n - 2)
        end
      end
      new("Counter", "c1")
      send("c1", "set", "v", 0)
      let i = 0
      while i < 5 do
        send("c1", "set", "v", get("c1", "v") + fib(i))
        let i = i + 1
      end
      print(get("c1", "v"))
      print(10 / 4)
      print(sqrt(2) * sqrt(2))
      """
    When I run it both interpreted and compiled
    Then both runs exit successfully
    And the interpreted and compiled outputs match exactly
