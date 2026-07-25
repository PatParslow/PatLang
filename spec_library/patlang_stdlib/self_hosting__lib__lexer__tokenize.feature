Feature: tokenize (self_hosting/lib/lexer.patlang)

  Scenario: A simple assignment tokenizes as expected
    Given the source "x = 1\n"
    When tokenize is applied
    Then the result is [IDENT x][OP =][NUM 1][NL][EOF], as a vec_* handle (use vec_len/vec_get, not list_len/list access)

  Scenario: Empty input still yields an EOF token
    Given the empty string
    When tokenize is applied
    Then the result has exactly one token, EOF

  Scenario: A '#' line comment produces no token at all
    Given "# a comment\nx"
    When tokenize is applied
    Then the comment text is silently consumed -- no COMMENT token exists in this lexer -- only [NL][IDENT x][EOF] remain

  Scenario: String escapes decode to real bytes
    Given "\"a\\nb\\t\\\"c\""
    When tokenize is applied
    Then the STR token's text contains a real newline, tab, and quote byte, not the literal two-character escape sequences

  Scenario: Two-character operators are recognized as one token
    Given "=="
    When tokenize is applied
    Then the result is a single OP token with text "==", not two separate '=' tokens (same handling applies to !=, <=, >=, and the ':-' rule turnstile)

