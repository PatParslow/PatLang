Feature: action_add / plan (GOAP -- Goal-Oriented Action Planning)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A multi-step plan is found when no single action suffices
    Given the program
      """
      action_add("gather_wood", [], [["have", ["wood"]]], [], 1)
      action_add("build_house", [["have", ["wood"]]], [["have", ["house"]]], [], 1)
      print(plan_labels(plan([["have", ["house"]]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [gather_wood, build_house]
      """

  Scenario: An unreachable goal returns an empty plan
    Given the program
      """
      action_add("gather_wood", [], [["have", ["wood"]]], [], 1)
      print(plan_labels(plan([["nothing_produces_this", ["x"]]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      []
      """

  Scenario: A cheaper plan of more steps is preferred over a dearer direct one
    Given the program
      """
      action_add("direct", [], [["at", ["far"]]], [], 10)
      action_add("step1", [], [["at", ["near"]]], [], 1)
      action_add("step2", [["at", ["near"]]], [["at", ["far"]]], [], 1)
      print(plan_labels(plan([["at", ["far"]]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [step1, step2]
      """
