Feature: list/string literals and indexing

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A list literal is 0-based indexable
    Given the program
      """
      let l = [10, 20, 30]
      print([l[0], l[2]])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [10, 30]
      """

  Scenario: A string is indexable too, returning a single-character string
    Given the program
      """
      let s = "hello"
      print([s[0], s[4], type_of(s[0]), s[0].length])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [h, o, string, 1]
      """

  Scenario: Both lists and strings expose .length
    Given the program
      """
      print([[10, 20, 30].length, "hello".length])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [3, 5]
      """

  Scenario: A feature file's text reaches its steps as the characters it holds, whatever their encoding length
    Given the program
      """
      let s = "café λ€😀"
      print([s[3], s[5], s[6], s[7], s.length])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [é, λ, €, 😀, 8]
      """
