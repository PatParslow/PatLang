Feature: arithmetic operators + - * / % (plain integers)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Basic arithmetic
    Given the program
      """
      print([2 + 3, 5 - 3, 4 * 3, 10 / 2])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [5, 2, 12, 5]
      """

  Scenario: Multiplication binds tighter than addition
    Given the program
      """
      print(2 + 3 * 4)
      """
    When it runs interpreted and compiled
    Then both print
      """
      14
      """

  Scenario: Modulo follows the dividend's sign (truncating, not floored)
    Given the program
      """
      print(-10 % 3)
      """
    When it runs interpreted and compiled
    Then both print
      """
      -1
      """

  Scenario: Ordinary int arithmetic stays int (representation invariant, GitHub #49)
    Given the program
      """
      let x = 2 + 3 * 4
      print(numeric_kind(x))
      """
    When it runs interpreted and compiled
    Then both print
      """
      int
      """

  Note: this spec covers PLAIN INTEGER arithmetic only. Cross-type
  behaviour (Int+Float, Rational, BigInt overflow promotion, Complex)
  is real and already covered by a separate, previously-verified
  initiative -- see the numeric tower documentation, not this spec.
