Feature: comparison operators == != < <= > >=

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Equality and inequality
    Given the program
      """
      print([3 == 3, 3 == 4, 3 != 4, 3 != 3])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [true, false, true, false]
      """

  Scenario: Ordering is strict for < and >, inclusive for <=/>=
    Given the program
      """
      print([3 < 4, 4 < 3, 3 < 3, 3 <= 3, 4 > 3, 3 > 3, 3 >= 3])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [true, false, false, true, true, false, true]
      """

  Scenario: == does real value equality on strings, not reference identity
    Given the program
      """
      let s1 = "abc"
      let s2 = substr("xabcx", 1, 3)
      print(s1 == s2)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      """

  Scenario: comparison results are always bool, never leak the operand type (representation invariant, GitHub #49)
    Given the program
      """
      let x = 3 < 4
      print(type_of(x))
      """
    When it runs interpreted and compiled
    Then both print
      """
      bool
      """
