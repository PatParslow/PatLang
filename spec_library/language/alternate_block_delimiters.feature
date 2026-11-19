Feature: alternate block delimiters (do/end vs then/end vs { })

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print, or what both say as they refuse it (spec_steps_program.patlang).

  Scenario: while accepts do...end as an alternative to { }
    Given the program
      """
      let i = 0
      let sum = 0
      while i < 2 do
        let sum = sum + i
        let i = i + 1
      end
      let j = 0
      let sum2 = 0
      while j < 2 {
        let sum2 = sum2 + j
        let j = j + 1
      }
      print([sum, sum2])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [1, 1]
      """

  Scenario: closures accept do...end too
    Given the program
      """
      let f_do = |x| do return x * 2 end
      let f_brace = |x| { return x * 2 }
      print([f_do(5), f_brace(5)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [10, 10]
      """

  Scenario: if does NOT support do...end -- its alternate form uses 'then', not 'do'
    Given the program
      """
      if true do
        print("should not parse")
      end
      """
    When it runs interpreted and compiled
    Then both stop, saying
      """
      expected then or { after if condition
      """

  Scenario: if's alternate form is then/elif/else/end
    Given the program
      """
      let ran = false
      if true then
        let ran = true
      end
      print(ran)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      """
