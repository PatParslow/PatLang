Feature: rule_add / solve (real backward-chaining logic engine)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A ground fact is a rule with an empty body
    Given the program
      """
      rule_add("parent", ["alice", "bob"], [])
      print(list_len(solve("parent", ["alice", "bob"])))
      """
    When it runs interpreted and compiled
    Then both print
      """
      1
      """

  Scenario: A chained rule resolves an unbound variable via multiple facts
    Given the program
      """
      rule_add("parent", ["alice", "bob"], [])
      rule_add("parent", ["bob", "carol"], [])
      rule_add("grandparent", [logic_var("X"), logic_var("Z")], [["parent", [logic_var("X"), logic_var("Y")]], ["parent", [logic_var("Y"), logic_var("Z")]]])
      print(solve("grandparent", ["alice", logic_var("Z")]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [[alice, carol]]
      """

  Scenario: No matching rule or fact returns an empty list
    Given the program
      """
      print(solve("no_such_relation_at_all", ["x", "y"]))
      """
    When it runs interpreted and compiled
    Then both print
      """
      []
      """

  Note: a variable is a logic_var("X") value, never a string: a string
  holding "X", capitalised or not, is data and matches only itself
  (review finding S1).
