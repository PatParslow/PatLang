Feature: traits (composable mixins, last-listed wins on collision)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A colliding method name resolves to the LAST-listed trait
    Given the program
      """
      class Nameable {
        make a function called label takes self returns msg
          return "name:" + get(self, "name")
        end
      }
      class Serializable {
        make a function called label takes self returns msg
          return "serialized:" + get(self, "name")
        end
      }
      class Widget {
        traits Nameable, Serializable
      }
      print(send(new("Widget", "w1"), "label"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      serialized:w1
      """

  Scenario: A non-colliding trait method is still composed in
    Given the program
      """
      class Nameable {
        make a function called label takes self returns msg
          return "name:" + get(self, "name")
        end
      }
      class Serializable {
        make a function called to_str takes self returns msg
          return "<obj " + get(self, "name") + ">"
        end
      }
      class Widget {
        traits Nameable, Serializable
      }
      let w = new("Widget", "w1")
      print(send(w, "to_str"))
      print(send(w, "label"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      <obj w1>
      name:w1
      """

  Scenario: The class's own field declarations work unaffected
    Given the program
      """
      class Nameable {
        make a function called label takes self returns msg
          return "name:" + get(self, "name")
        end
      }
      class Widget {
        traits Nameable
        field kind = "widget"
      }
      print(get(new("Widget", "w1"), "kind"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      widget
      """
