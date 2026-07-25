Feature: rule_add / solve (real backward-chaining logic engine)

  Scenario: A ground fact is a rule with an empty body
    Given rule_add("parent", ["alice","bob"], [])
    When solve("parent", ["alice","bob"]) is called
    Then the result is a list with exactly 1 solution

  Scenario: A chained rule resolves an unbound variable via multiple facts
    Given rule_add("grandparent", ["X","Z"], [["parent",["X","Y"]], ["parent",["Y","Z"]]]) plus parent(alice,bob) and parent(bob,carol)
    When solve("grandparent", ["alice","Z"]) is called
    Then Z resolves to "carol" -- confirmed via real chained unification, not a flat lookup

  Scenario: No matching rule or fact returns an empty list
    Given a query with no possible proof
    When solve is called
    Then the result is an empty list, not an error

  Note: any argument string starting with an UPPERCASE letter (e.g.
  "X", "Z") is treated as a logic VARIABLE, not a ground constant --
  a real, previously-documented gotcha (see [[patlang-stage0-gotchas]])
  now folded into this instruction's own contract: passing arbitrary
  string data through rule_add/solve must ground it first (e.g. a
  lowercase marker) if it isn't guaranteed lowercase-first.

