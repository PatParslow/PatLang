Feature: function definition and return

  Scenario: return exits immediately with the given value
    Given a function with an if-guarded `return "negative"` before any later statement
    When called with an input that satisfies the guard
    Then the function returns immediately, never reaching code after the if-block

  Scenario: a function with no explicit return implicitly returns its last statement's value
    Given a function whose body ends in a plain `let x = n + 1` with no explicit `return` anywhere
    When it is called
    Then it returns that last statement's value (an int), the same as Ruby/Rust block semantics -- not Unit

  Scenario: a function whose last statement produces no value of its own still returns Unit
    Given a function whose body ends in a bare `print(...)` call (print's own return value is Unit) with no explicit `return`
    When its result is printed
    Then a single BLANK line is printed -- NOT the text "nil"/"undefined", and NOT silently nothing at all; a function's implicit return is genuinely Unit only when its tail statement's own value IS Unit

