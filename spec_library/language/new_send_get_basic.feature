Feature: new / send("set",...) / get (ad hoc objects, no class declared)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: An ad hoc object gets implicit type/name fields for free
    Given the program
      """
      let obj = new("Widget", "w1")
      print([get(obj, "type"), get(obj, "name")])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [Widget, w1]
      """

  Scenario: send("set",...) writes a field, get reads it back
    Given the program
      """
      let obj = new("Widget", "w2")
      send(obj, "set", "color", "red")
      print(get(obj, "color"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      red
      """
