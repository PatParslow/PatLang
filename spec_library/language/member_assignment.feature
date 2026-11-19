Feature: obj.prop = value (member-assignment sugar)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Dot-assignment writes the same store dot-read and get() both read from
    Given the program
      """
      class Holder {
        field placeholder = 0
      }
      let o = new("Holder", "o1")
      o.color = "blue"
      print([o.color, get(o, "color")])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [blue, blue]
      """
