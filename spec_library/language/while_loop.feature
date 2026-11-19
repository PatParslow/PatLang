Feature: while (control flow)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: The body repeats while the condition holds
    Given the program
      """
      let i = 0
      let sum = 0
      while i < 5 do
        let sum = sum + i
        let i = i + 1
      end
      print(sum)
      """
    When it runs interpreted and compiled
    Then both print
      """
      10
      """

  Scenario: A condition false from the start runs zero iterations
    Given the program
      """
      let ran = false
      while false do
        let ran = true
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      false
      """
