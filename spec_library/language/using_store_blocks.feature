Feature: using blocks choose the store the logic forms use

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Inside a using block the logic forms read and write the block's store
    Given the program
      """
      let kb = logic_store_new()
      action_add("go", [["at", ["home"]]], [["at", ["work"]]], [["at", ["home"]]], 1)
      using kb as logic do
        rule parent(alice, bob).
        rule_add("parent", ["bob", "carol"], [])
        rule gp(X, Z) :- parent(X, Y), parent(Y, Z).
        fact("likes", "alice", "tea")
        rule at(home).
        print(solve("gp", ["alice", logic_var("Z")]))
        print(query("likes", "alice", "x"))
        print(plan_labels(plan([["at", ["work"]]])))
      end
      print(list_len(solve_in(kb, "parent", [logic_var("X"), logic_var("Y")])))
      print(list_len(solve("parent", [logic_var("X"), logic_var("Y")])) + list_len(solve("likes", [logic_var("X"), logic_var("Y")])) + list_len(solve("gp", [logic_var("X"), logic_var("Y")])))
      print(plan_labels(plan([["at", ["work"]]])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[alice, carol]]
      1
      [go]
      2
      0
      []
      """

  Scenario: An inner using block's store shadows the outer one until it ends
    Given the program
      """
      let outer = logic_store_new()
      let inner = logic_store_new()
      using outer as logic do
        rule where(outer).
        using inner as logic do
          rule where(inner).
          print(solve("where", [logic_var("W")]))
        end
        print(solve("where", [logic_var("W")]))
      end
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[inner]]
      [[outer]]
      """

  Scenario: An explicit store wins over the block's
    Given the program
      """
      let kb = logic_store_new()
      let other = logic_store_new()
      using kb as logic do
        rule named(x) in elsewhere.
        rule_add_to(other, "named", ["y"], [])
        print(solve_in(other, "named", [logic_var("V")]))
      end
      print(solve_in(logic_store_named("elsewhere"), "named", [logic_var("V")]))
      print(solve_in(kb, "named", [logic_var("V")]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[y]]
      [[x]]
      []
      """

  Scenario: A named function called inside a using block uses the default store
    Given the program
      """
      make a function called default_count takes pred returns n
        return list_len(solve(pred, [logic_var("X")]))
      end
      rule_add("fn_fact", ["default"], [])
      let kb = logic_store_new()
      using kb as logic do
        rule fn_fact(kb).
        print(default_count("fn_fact"))
        print(solve("fn_fact", [logic_var("X")]))
      end
      """
    When it runs interpreted and compiled
    Then both print
      """
      1
      [[kb]]
      """

  Scenario: A closure made inside a using block keeps its store after the block ends
    Given the program
      """
      let kb = logic_store_new()
      using kb as logic do
        rule kept(yes).
        let look = || do
          return solve("kept", [logic_var("X")])
        end
      end
      print(look())
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[yes]]
      """

  Scenario: rules_clear inside a using block empties the block's store only
    Given the program
      """
      rule_add("cleared", ["default"], [])
      let kb = logic_store_new()
      using kb as logic do
        rule cleared(kb).
        rules_clear()
      end
      print(solve_in(kb, "cleared", [logic_var("X")]))
      print(solve("cleared", [logic_var("X")]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      []
      [[default]]
      """
