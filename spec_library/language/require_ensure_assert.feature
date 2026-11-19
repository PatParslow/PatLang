Feature: require / ensure / assert (design-by-contract)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print, or what both say as they stop (spec_steps_program.patlang).

  Scenario: A passing contract has no visible effect
    Given the program
      """
      make a function called safe_divide takes a, b returns r
        require b != 0
        let r = a / b
        ensure (r * b) == a
        return r
      end
      print("result=" + safe_divide(10, 2))
      """
    When it runs interpreted and compiled
    Then both print
      """
      result=5
      """

  Scenario: A require violation is fatal, naming the function/kind/condition
    Given the program
      """
      make a function called safe_divide takes a, b returns r
        require b != 0
        let r = a / b
        ensure (r * b) == a
        return r
      end
      print("safe_divide(0, 0) = " + safe_divide(0, 0))
      print("(unreachable)")
      """
    When it runs interpreted and compiled
    Then both stop, saying
      """
      contract violation: precondition failed in safe_divide(): b != 0
      """

  Scenario: an ensure violation is labelled a postcondition
    Given the program
      """
      make a function called bad_ensure takes n returns r
        let r = n
        ensure r > 100
        return r
      end
      print(bad_ensure(1))
      """
    When it runs interpreted and compiled
    Then both stop, saying
      """
      postcondition failed in bad_ensure()
      """

  Scenario: an assert violation is labelled an assertion
    Given the program
      """
      assert (1 + 1) == 3
      print("(unreachable)")
      """
    When it runs interpreted and compiled
    Then both stop, saying
      """
      assertion failed
      """
