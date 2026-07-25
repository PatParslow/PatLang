Feature: tok_is (self_hosting/lib/parser.patlang)

  Scenario: Both type and text match
    Given a token ["IDENT", "foo"]
    When tok_is is applied with ty="IDENT", tx="foo"
    Then the result is true

  Scenario: Type differs
    Given a token ["IDENT", "foo"]
    When tok_is is applied with ty="KEYWORD", tx="foo"
    Then the result is false

  Scenario: Text differs
    Given a token ["IDENT", "foo"]
    When tok_is is applied with ty="IDENT", tx="bar"
    Then the result is false

