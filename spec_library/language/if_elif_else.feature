Feature: if / elif / else (control flow)

  Scenario: A true condition runs the then-branch
    Given the condition true
    When an if-statement is evaluated
    Then the then-branch executes

  Scenario: A false condition with no else runs nothing
    Given the condition false, with no else clause
    When an if-statement is evaluated
    Then neither branch executes; the statement is a no-op

  Scenario: A false condition with an else runs the else-branch
    Given the condition false, with an else clause
    When an if-statement is evaluated
    Then the else-branch executes

  Scenario: An elif chain runs exactly the first matching branch
    Given a false condition, followed by a nested if-true (elif-equivalent) branch
    When the statement is evaluated
    Then only that matching branch executes

