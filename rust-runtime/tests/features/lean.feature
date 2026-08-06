# Guards against: regressions in the Lean 4 lexer, parser, emitter and
# runner libraries under self_hosting/lib/lean_*.patlang.
#
# The test pyramid for this feature:
#   Unit:        tokenise tiny snippets, verify token type/text/count.
#   Integration: parse full Lean 4 constructs, verify AST shape.
#   Round-trip:  parse then emit, verify structural equivalence.
#   Query:       lean_file_imports / lean_file_theorems / lean_set_option_val.
#   Runner:      lean_check_file / lean_run_file (requires lean on PATH,
#                skipped if not present).
#
# All scenarios follow RED → GREEN: added here before the library existed,
# confirmed failing, then flipped green by the implementation.

Feature: Lean 4 support in PatLang
  As a PatLang developer
  I want to read, parse, query, emit, and run Lean 4 source files from PatLang
  So that PatLang programs can work with Lean 4 proofs and programs

  # ---- Lexer scenarios ----

  Scenario: tokenise a minimal Lean file without token loss
    Given the self-hosted test suite "lean"
    When I run it interpreted
    Then the self-hosted suite reports all tests passed

  Scenario: the Lean selftest exits successfully
    Given the self-hosted test suite "lean"
    When I run it interpreted
    Then it exits successfully
    And stdout contains "ALL TESTS PASSED"
