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

  Numeric fluents (PDDL 2.1): fluent_set gives a fluent its value, an action
  added with action_add_numeric has numeric preconditions and effects besides
  its facts, and plan_numeric(goal_facts, numeric_goals) plans to both. A
  condition is [fluent, op, value] with op one of < <= > >= == !=; an effect is
  [fluent, op, value] with op one of = += -= *= /=. A value is a number, a
  number's text, or a variable the action's preconditions bind.

  Scenario: A counter is counted down to zero with arithmetic, no table of facts
    Given the program
      """
      fluent_set("count", 3)
      action_add_numeric("chop_wood", [], [["count", ">=", 1]], [], [], [["count", "-=", 1]], 1)
      print(plan_labels(plan_numeric([], [["count", "==", 0]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [chop_wood, chop_wood, chop_wood]
      """

  Scenario: An inequality goal is met where an exact one cannot be
    Given the program
      """
      fluent_set("count", 5)
      action_add_numeric("chop_big", [], [["count", ">", "0"]], [], [], [["count", "-=", "2"]], 1)
      print(list_len(plan_numeric([], [["count", "<=", 0]])))
      print(list_len(plan_numeric([], [["count", "==", 0]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      3
      0
      """

  Scenario: An effect's value can come from a fact the preconditions bind
    Given the program
      """
      rule_add("stride", ["2"], [])
      fluent_set("pos", 0)
      action_add_numeric("jump", [["stride", [logic_var("S")]]], [["pos", "<", 10]], [], [], [["pos", "+=", logic_var("S")]], 1)
      print(plan_labels(plan_numeric([], [["pos", ">=", 5]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [jump(S=2), jump(S=2), jump(S=2)]
      """

  Scenario: Facts and fluents are planned together, cheapest first
    Given the program
      """
      fluent_set("fuel", 0)
      action_add_numeric("refuel", [], [["fuel", "<", 2]], [], [], [["fuel", "+=", 1]], 1)
      action_add_numeric("drive", [], [["fuel", ">=", 2]], [["at", ["town"]]], [], [["fuel", "-=", 2]], 1)
      action_add("taxi", [], [["at", ["town"]]], [], 5)
      print(plan_labels(plan_numeric([["at", ["town"]]], [])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [refuel, refuel, drive]
      """
