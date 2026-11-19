Feature: if / elif / else (control flow)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A true condition runs the then-branch
    Given the program
      """
      let ran = "none"
      if true then
        let ran = "then"
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      then
      """

  Scenario: A false condition with no else runs nothing
    Given the program
      """
      let ran = "none"
      if false then
        let ran = "then"
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      none
      """

  Scenario: A false condition with an else runs the else-branch
    Given the program
      """
      let ran = "none"
      if false then
        let ran = "then"
      else
        let ran = "else"
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      else
      """

  Scenario: An elif chain runs exactly the first matching branch
    Given the program
      """
      let ran = "none"
      if false then
        let ran = "then"
      elif true then
        let ran = "elif"
      elif true then
        let ran = "second elif"
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      elif
      """
