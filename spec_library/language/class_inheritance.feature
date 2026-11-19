Feature: class / inherits (single inheritance, field defaults)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A child class's own default overrides the parent's
    Given the program
      """
      class Animal {
        field legs = 4
      }
      class Person inherits Animal {
        field legs = 2
      }
      let p = new("Person", "p1")
      print(p.legs)
      """
    When it runs interpreted and compiled
    Then both print
      """
      2
      """

  Scenario: A field not redeclared by the child is still inherited
    Given the program
      """
      class Animal {
        field legs = 4
        field sound = "..."
      }
      class Person inherits Animal {
        field legs = 2
      }
      let p = new("Person", "p2")
      print(p.sound)
      """
    When it runs interpreted and compiled
    Then both print
      """
      ...
      """

  Scenario: An instance of the parent class is unaffected by the child's overrides
    Given the program
      """
      class Animal {
        field legs = 4
      }
      class Person inherits Animal {
        field legs = 2
      }
      let a = new("Animal", "a1")
      print(a.legs)
      """
    When it runs interpreted and compiled
    Then both print
      """
      4
      """
