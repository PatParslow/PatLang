Feature: function definition and return

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: return exits immediately with the given value
    Given the program
      """
      make a function called guarded takes n returns msg
        if n < 0 then
          return "negative"
        end
        print("not reached for a negative n")
        return "non-negative"
      end
      print(guarded(-5))
      """
    When it runs interpreted and compiled
    Then both print
      """
      negative
      """

  Scenario: a function with no explicit return implicitly returns its last statement's value
    Given the program
      """
      make a function called no_return takes n returns done
        let x = n + 1
      end
      print(no_return(1))
      print(type_of(no_return(1)))
      """
    When it runs interpreted and compiled
    Then both print
      """
      2
      int
      """

  Scenario: a function whose last statement produces no value of its own still returns Unit
    Given the program
      """
      make a function called tail_is_unit takes n returns done
        print("a side effect, not its return value")
      end
      print(type_of(tail_is_unit(1)))
      """
    When it runs interpreted and compiled
    Then both print
      """
      a side effect, not its return value
      unit
      """

  Scenario: a function declared `takes none` takes no parameters
    Given the program
      """
      make a function called seven takes none returns r
        return 7
      end
      print(seven())
      """
    When it runs interpreted and compiled
    Then both print
      """
      7
      """
