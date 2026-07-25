Feature: let (variable binding)

  Scenario: A bound name is readable immediately
    Given `let x = 5`
    When x is read
    Then it is 5

  Scenario: A second let with the same name reassigns it
    Given `let x = 5` then `let x = x + 1`
    When x is read afterward
    Then it is 6

  Scenario: if/while block bodies share the ENCLOSING scope
    Given `let y = 1` then `if true then let y = 99 end`
    When y is read after the if-block
    Then it is 99 -- the if-block did NOT get its own scope; it mutated the outer y directly

  Scenario: A while-loop's let accumulates across iterations in the same outer scope
    Given `let z = 1` then a 3-iteration while-loop doing `let z = z + 10` each time
    When z is read after the loop
    Then it is 31 (1 + 10 + 10 + 10), confirming each iteration's let mutates the SAME outer z, not a fresh one

  Important distinction: this is DIFFERENT from a `make a function
  called ...` body, which sees NO outer-scope let at all -- a name must
  be passed in as a parameter to be visible inside a function. Blocks
  (if/while) and functions have genuinely different scoping rules in
  PatLang; do not assume one from the other.

