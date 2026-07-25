Feature: while (control flow)

  Scenario: The body repeats while the condition holds
    Given a loop summing i from 0 while i < 5, incrementing i each time
    When the while-statement runs to completion
    Then the sum is 10 (0+1+2+3+4)

  Scenario: A condition false from the start runs zero iterations
    Given `while false do ... end`
    When the statement is evaluated
    Then the body never executes, not even once

