Feature: rule Head(...) :- Body. (declaration sugar over rule_add)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: The sugar form produces the same result as a hand-written rule_add call
    Given the program
      """
      rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
      rule_add("parent", ["alice", "bob"], [])
      rule_add("parent", ["bob", "carol"], [])
      print(solve("grandparent", ["alice", logic_var("Z")]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[alice, carol]]
      """

  Scenario: A rule declaration can name the store it goes in, and a body goal the store it is solved against
    Given the program
      """
      rule store_parent(alice, bob) in family.
      rule store_parent(bob, carol) in family.
      rule store_gp(X, Z) :- store_parent(X, Y) from family, store_parent(Y, Z) from family.
      print(solve("store_gp", ["alice", logic_var("Z")]))
      print(list_len(solve("store_parent", ["alice", logic_var("Y")])))
      print(list_len(solve_in(logic_store_named("family"), "store_parent", ["alice", logic_var("Y")])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[alice, carol]]
      0
      1
      """
