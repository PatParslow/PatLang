Feature: match / case pattern matching (issue #44, self-hosted toolchain only)

  Scenario: A literal pattern matches on equality
    Given a match over the number 0 with cases for 0, "hi", a comparison, and a binding
    When the match is evaluated
    Then the literal-0 arm's body runs

  Scenario: A wildcard/binding-name pattern binds the scrutinee
    Given a match over the number 3 against the same case list
    When the match is evaluated
    Then the bare-identifier arm runs with the identifier bound to 3

  Scenario: A comparison-guard pattern matches by relation, not equality
    Given a match over the number 20 against the same case list
    When the match is evaluated
    Then the `> 10` arm's body runs

  Scenario: A tagged-list pattern destructures and binds its elements
    Given a match over ["Ok", 5] with cases ["Ok", v], ["Err", ["Nested", m]], and _
    When the match is evaluated
    Then the ["Ok", v] arm runs with v bound to 5

  Scenario: A nested tagged-list pattern destructures through two levels
    Given a match over ["Err", ["Nested", "boom"]] against the same case list
    When the match is evaluated
    Then the ["Err", ["Nested", m]] arm runs with m bound to "boom"

  Scenario: A shape that matches no non-wildcard arm falls through to wildcard
    Given a match over ["Err", "flat"] against the same case list
    When the match is evaluated
    Then the wildcard arm runs, not the nested-list arm

  Scenario: A `when` guard can reject an otherwise-matching pattern
    Given a match over the number 12 with a binding pattern guarded by `when n > 100`
    When the match is evaluated
    Then the guarded arm's test fails and a later arm runs instead

  Scenario: A `when` guard can accept, using its own pattern's binding
    Given a match over the number 200 against the same guarded case list
    When the match is evaluated
    Then the guarded arm's test succeeds, using its own pattern's binding

  Scenario: A string glob pattern matches via substring/prefix wildcards
    Given a match over "alfred smith" with a `*fred*` case
    When the match is evaluated
    Then the glob arm's body runs

  Scenario: A scrutinee that matches nothing, with no wildcard arm, is a runtime error
    Given a match with only literal cases for 1 and 2, no wildcard
    When the match is evaluated against 99
    Then the program halts with a fatal "no case matched" error, not a silent no-op

  Scenario: A matched arm with no `return` falls through past the match, not back into it
    Given a match where the matching arm has no `return`, with more arms and code after it
    When the match is evaluated
    Then a matched arm with no `return` correctly jumps past the remaining arms, not back into the match

  Scenario: A match that ends a function gives the function its value
    Given a function whose last statement is a match, each arm ending in a value
    When the match is evaluated
    Then the function returns the taken arm's value

  Scenario: An arm's let assigns the function's named result
    Given a function returning r, each arm of its match assigning r from the pattern's bindings
    When the match is evaluated
    Then the function returns what the taken arm assigned

  Scenario: A closure's match sees what the closure captured
    Given a closure whose match compares against and guards with a captured variable
    When the match is evaluated
    Then the captured value decides the arm

  Scenario: The scrutinee is evaluated once
    Given a match whose scrutinee calls a function that counts its calls, with several arms tested
    When the match is evaluated
    Then the function was called once

  Scenario: A value of another type does not match a literal or a list pattern
    Given a match over a number with string and list cases first, and over a string with number and list cases first
    When the match is evaluated
    Then each falls through to its wildcard arm
