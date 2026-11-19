Feature: print

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: print writes a value followed by a newline
    Given the program
      """
      let r = print("a line")
      print(type_of(r))
      print(42)
      """
    When it runs interpreted and compiled
    Then both print
      """
      a line
      unit
      42
      """

  Scenario: printing Unit writes a blank line, not zero bytes
    Given the program
      """
      make a function called nothing takes none returns done
        print("before")
      end
      print(nothing())
      print("after")
      """
    When it runs interpreted and compiled
    Then both print
      """
      before

      after
      """
