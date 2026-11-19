Feature: logical operators and / or / not (short-circuit)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). X prints when it is evaluated,
  so a side effect, not the keyword, shows whether it was.

  Scenario: 'and' short-circuits on a false left-hand side
    Given the program
      """
      make a function called x takes none returns v
        print("X evaluated")
        return true
      end
      print(false and x())
      """
    When it runs interpreted and compiled
    Then both print
      """
      false
      """

  Scenario: 'or' short-circuits on a true left-hand side
    Given the program
      """
      make a function called x takes none returns v
        print("X evaluated")
        return true
      end
      print(true or x())
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      """

  Scenario: 'and' DOES evaluate the right-hand side when needed
    Given the program
      """
      make a function called x takes none returns v
        print("X evaluated")
        return true
      end
      print(true and x())
      """
    When it runs interpreted and compiled
    Then both print
      """
      X evaluated
      true
      """

  Scenario: 'not' negates a boolean
    Given the program
      """
      print([not true, not false])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [false, true]
      """
