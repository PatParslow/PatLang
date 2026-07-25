Feature: logical operators and / or / not (short-circuit)

  Scenario: 'and' short-circuits on a false left-hand side
    Given `false and X`, where X has a detectable side effect if evaluated
    When the expression is evaluated
    Then X is NEVER evaluated -- confirmed via a real side-effect counter, not assumed from the keyword

  Scenario: 'or' short-circuits on a true left-hand side
    Given `true or X`, where X has a detectable side effect if evaluated
    When the expression is evaluated
    Then X is NEVER evaluated

  Scenario: 'and' DOES evaluate the right-hand side when needed
    Given `true and X`
    When the expression is evaluated
    Then X IS evaluated, since its value is needed to decide the result

  Scenario: 'not' negates a boolean
    Given true and false
    When not is applied
    Then not true = false, not false = true

