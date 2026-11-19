Feature: closures (|params| { body } literal, free-variable capture)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A closure captures a free variable from its enclosing scope
    Given the program
      """
      let base = 10
      let add_to_base = |x| { return base + x }
      print(add_to_base(5))
      """
    When it runs interpreted and compiled
    Then both print
      """
      15
      """

  Scenario: A closure can be called through a variable it's assigned to
    Given the program
      """
      let base = 10
      let add_to_base = |x| { return base + x }
      let f = add_to_base
      print([f(5), add_to_base(5)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [15, 15]
      """

  Scenario: Closures returned from a function each capture their OWN value independently
    Given the program
      """
      make a function called outer takes n returns closure
        return |x| { return x + n }
      end
      let add10 = outer(10)
      let add20 = outer(20)
      print([add10(1), add20(1)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [11, 21]
      """
