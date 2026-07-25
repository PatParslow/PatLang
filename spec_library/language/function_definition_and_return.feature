Feature: function definition and return

  Scenario: return exits immediately with the given value
    Given a function with an if-guarded `return "negative"` before any later statement
    When called with an input that satisfies the guard
    Then the function returns immediately, never reaching code after the if-block

  Scenario: a function with no return statement returns Unit, printed as a blank line
    Given a function whose body has no `return` anywhere
    When its result is printed
    Then a single BLANK line is printed -- NOT the text "nil"/"undefined", and NOT silently nothing at all; the function does NOT implicitly return its last expression's value (unlike Ruby/Rust)

