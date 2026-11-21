Feature: send (real user-defined method dispatch)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A child class's own method overrides the parent's
    Given the program
      """
      class Animal {
        field sound = "..."
        make a function called speak takes self returns msg
          return get(self, "sound")
        end
      }
      class Person inherits Animal {
        field job = "unemployed"
        make a function called speak takes self returns msg
          return "hi, my job is " + get(self, "job")
        end
      }
      print(send(new("Person", "p1"), "speak"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      hi, my job is unemployed
      """

  Scenario: An instance with no override uses the parent's method
    Given the program
      """
      class Animal {
        field sound = "..."
        make a function called speak takes self returns msg
          return get(self, "sound")
        end
      }
      class Person inherits Animal {
        field job = "unemployed"
        make a function called speak takes self returns msg
          return "hi, my job is " + get(self, "job")
        end
      }
      print(send(new("Animal", "a1"), "speak"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      ...
      """

  Scenario: A class's own method called set is the one that runs; without one, set sets a field
    Given the program
      """
      class Cell {
        field v = 0
        make a function called set takes self, x returns value
          print("own set " + x)
          self.v = x
          return x
        end
      }
      class Plain {
        field k = 0
      }
      let c = new("Cell")
      c.set(5)
      print(c.v)
      send(c, "set", 6)
      print(c.v)
      let p = new("Plain")
      p.set("k", 7)
      print(p.k)
      """
    When it runs interpreted and compiled
    Then both print
      """
      own set 5
      5
      own set 6
      6
      7
      """

  Note: this is a REAL closure call (the method is resolved by walking the
  own class then the parent chain and invoked directly). send(obj, "set",
  field, val) sets a field when the object's class, and its parents, have no
  method called set; a class that defines set gets its own method, like any
  other name.
