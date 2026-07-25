Feature: parse_program (self_hosting/lib/parser.patlang)

  Scenario: A let statement parses correctly
    Given tokenized "let x = 1\n"
    When parse_program is applied
    Then the result is ["Program", [["Let", "x", ["Num","1"], false, false]]]

  Scenario: A bare expression statement parses correctly
    Given tokenized "x + 1\n"
    When parse_program is applied
    Then the result is ["Program", [["Expr", ["Bin", "+", ["Var","x"], ["Num","1"]]]]]

  Scenario: Empty input yields zero statements
    Given tokenized "" (a single EOF token)
    When parse_program is applied
    Then the result is ["Program", []], not an error

  Note: the returned AST uses ordinary PatLang lists (list_len/indexing),
  even though the INPUT token stream from tokenize is a vec_* handle
  (vec_len/vec_get) -- do not mix up the two access conventions.

