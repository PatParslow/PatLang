Feature: print

  Scenario: print writes a value followed by a newline
    Given any value
    When print(value) is called
    Then its display text is written, followed by a newline -- confirmed across many other specs in this same file, each of which depends on print's output landing on its own line

  Scenario: printing Unit writes a blank line, not zero bytes
    Given an expression that evaluates to Unit (e.g. a function with no return statement, or set_var's own return value)
    When printed
    Then exactly one blank line is written, not nothing at all

