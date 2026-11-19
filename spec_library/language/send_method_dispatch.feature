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

  Note: this is a REAL closure call (the method is resolved by walking the
  own class then the parent chain and invoked directly), distinct from
  send(obj, "set", field, val), the one verb send itself understands; any
  other method name is resolved by the class's own dispatch.
