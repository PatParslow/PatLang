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

  Scenario: A class's methods may be written in the short forms, beside the word form
    Given the program
      """
      class Counter {
        field n = 0
        fn add(self, by) {
          self.n = self.n + by
          return self.n
        }
        function twice(self) {
          return self.n * 2
        }
        make a function called reset takes self returns n
          self.n = 0
          return self.n
        end
      }
      class Wide inherits Counter {
        fn twice(self) {
          return self.n * 3
        }
      }
      let c = new("Counter")
      c.add(5)
      print([c.n, c.twice()])
      c.reset()
      print(c.n)
      let w = new("Wide")
      w.add(4)
      print(w.twice())
      """
    When it runs interpreted and compiled
    Then both print
      """
      [5, 10]
      0
      12
      """
