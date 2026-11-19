Feature: goal / pursue / activate / action_bind (declarative GOAP surface syntax)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: pursue finds a real multi-step plan for a named goal
    Given the program
      """
      rule_add("dep", ["house", "walls"], [])
      rule_add("dep", ["walls", "foundation"], [])
      rule_add("built", ["foundation_base"], [])
      action_add("build_from_base", [["built", ["foundation_base"]]], [["built", ["foundation"]]], [], 1)
      action_add("build_from_dep", [["dep", [logic_var("X"), logic_var("Y")]], ["built", [logic_var("Y")]]], [["built", [logic_var("X")]]], [], 1)
      goal need_a_house {
        built(house)
      }
      let p = pursue need_a_house
      print(plan_labels(p))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [build_from_base, build_from_dep(X=walls,Y=foundation), build_from_dep(X=house,Y=walls)]
      """

  Scenario: activate runs each bound closure and succeeds only if all do
    Given the program
      """
      rule_add("dep", ["house", "walls"], [])
      rule_add("dep", ["walls", "foundation"], [])
      rule_add("built", ["foundation_base"], [])
      action_add("build_from_base", [["built", ["foundation_base"]]], [["built", ["foundation"]]], [], 1)
      action_add("build_from_dep", [["dep", [logic_var("X"), logic_var("Y")]], ["built", [logic_var("Y")]]], [["built", [logic_var("X")]]], [], 1)
      action_bind("build_from_base", |args| {
        return true
      })
      action_bind("build_from_dep", |args| {
        return true
      })
      goal need_a_house {
        built(house)
      }
      print(activate pursue need_a_house)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      """

  Scenario: a plan being found does NOT guarantee activating it succeeds
    Given the program
      """
      rule_add("dep", ["house", "walls"], [])
      rule_add("dep", ["walls", "foundation"], [])
      rule_add("built", ["foundation_base"], [])
      action_add("build_from_base", [["built", ["foundation_base"]]], [["built", ["foundation"]]], [], 1)
      action_add("build_from_dep", [["dep", [logic_var("X"), logic_var("Y")]], ["built", [logic_var("Y")]]], [["built", [logic_var("X")]]], [], 1)
      action_bind("build_from_base", |args| {
        return true
      })
      action_bind("build_from_dep", |args| {
        if args[0] == "house" then
          return false
        end
        return true
      })
      goal need_a_house {
        built(house)
      }
      let p = pursue need_a_house
      print(list_len(p))
      print(activate p)
      """
    When it runs interpreted and compiled
    Then both print
      """
      3
      false
      """
