@language
Feature: operators are methods, and raise ordinary events (spec 1.4)

  Scenario: an operator is a method of its left operand's class
    Given a class Money with a field cents and a method + taking other, returning a Money with the two amounts' cents summed
    When m1 + m2 is evaluated, with 150 and 275 cents
    Then the result is a Money with 425 cents

  Scenario: a method declaration names the events it raises
    Given a class Money whose + is declared `raises money_added`
    And a handler `when money_added do ... end` recording event_data
    When m1 + m2 is evaluated
    Then the handler ran once, with event_data [m1, m2, the result]

  Scenario: int's + raises its three events in order
    Given handlers for added_to and added that append event_name and event_data to a log
    When 3 + 5 is evaluated
    Then the log is: added_to [3, 5], added_to [5, 3], added [3, 5, 8]
    And the value of 3 + 5 is 8

  Scenario: a handler cannot change an operator's result
    Given a handler for added that tries to return 0
    When 3 + 5 is evaluated
    Then the value is 8

  Scenario: a handler's own operations do not raise its event again
    Given a handler for added that adds 1 + 1 and counts how many times it ran
    When 3 + 5 is evaluated
    Then the handler ran once

  Scenario: operator events are ordinary events
    Given a handler for added registered with `when added do ... end`
    When emit("added", [1, 2, 3]) is called directly
    Then the same handler runs, with event_data [1, 2, 3]

  Scenario: with no handler, an operator gives the same result as before
    Given no handler registered for any event
    When 3 + 5, 1.5 * 2 and "a" + "b" are evaluated
    Then they print as 8, 3 and ab, and 1.5 * 2 is a float
