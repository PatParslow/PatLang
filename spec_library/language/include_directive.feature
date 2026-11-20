Feature: include (preprocessor directive)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: include splices a file's functions into scope, transitively
    Given the program
      """
      include "{root}/self_hosting/tools/spec_fixtures/include_sibling/includer.patlang"
      print("result=" + includer_double_plus_one(10))
      """
    When it runs interpreted and compiled
    Then both print
      """
      result=21
      """

  Scenario: a comment may follow an include, as it may any other line
    Given the program
      """
      include "{root}/self_hosting/tools/spec_fixtures/include_sibling/includer.patlang"   # doubles, then adds one
      print("result=" + includer_double_plus_one(4))
      """
    When it runs interpreted and compiled
    Then both print
      """
      result=9
      """

  Note: include paths resolve relative to the INCLUDING file's own
  directory, not the entry script's directory: includer.patlang includes
  its sibling helper.patlang by bare filename, and the program, written
  elsewhere, does not need to know helper.patlang exists at all.
