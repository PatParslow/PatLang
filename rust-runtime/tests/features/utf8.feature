# Guards against: the UTF-8 core stdlib library drifting from correctness
# or being broken by changes to the runtime's string-handling primitives
# (char_code, substr, chr, str_intern, etc.).  A regression here would
# silently break any downstream library that depends on utf8.patlang for
# Unicode-aware character processing (e.g. the Lean 4 lexer).

Feature: UTF-8 core stdlib library
  As a PatLang developer
  I want the UTF-8 library to correctly encode and decode Unicode codepoints
  So that libraries processing non-ASCII text have a reliable foundation

  Scenario: utf8_next decodes an ASCII byte correctly
    Given the self-hosted test suite "utf8"
    When I run it interpreted
    Then the self-hosted suite reports all tests passed

  Scenario: utf8 selftest exits successfully with zero failures
    Given the self-hosted test suite "utf8"
    When I run it interpreted
    Then it exits successfully
    And stdout contains "ALL TESTS PASSED"
