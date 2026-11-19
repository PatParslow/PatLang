Feature: let (variable binding)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A bound name is readable immediately
    Given the program
      """
      let x = 5
      print(x)
      """
    When it runs interpreted and compiled
    Then both print
      """
      5
      """

  Scenario: A second let with the same name reassigns it
    Given the program
      """
      let x = 5
      let x = x + 1
      print(x)
      """
    When it runs interpreted and compiled
    Then both print
      """
      6
      """

  Scenario: if/while block bodies share the ENCLOSING scope
    Given the program
      """
      let y = 1
      if true then
        let y = 99
      end
      print(y)
      """
    When it runs interpreted and compiled
    Then both print
      """
      99
      """

  Scenario: A while-loop's let accumulates across iterations in the same outer scope
    Given the program
      """
      let z = 1
      let i = 0
      while i < 3 do
        let z = z + 10
        let i = i + 1
      end
      print(z)
      """
    When it runs interpreted and compiled
    Then both print
      """
      31
      """

  Important distinction: this is DIFFERENT from a `make a function
  called ...` body, which sees NO outer-scope let at all -- a name must
  be passed in as a parameter to be visible inside a function. Blocks
  (if/while) and functions have genuinely different scoping rules in
  PatLang; do not assume one from the other.
