Feature: action_add / plan (GOAP -- Goal-Oriented Action Planning)

  Scenario: A multi-step plan is found when no single action suffices
    Given action_add("gather_wood", [], [["have",["wood"]]], [], 1) and action_add("build_house", [["have",["wood"]]], [["have",["house"]]], [], 1)
    When plan([["have",["house"]]]) is called
    Then the result is ["gather_wood", "build_house"], in that exact order -- a real search, not a single-action lookup

  Scenario: An unreachable goal returns an empty plan
    Given a goal no registered action (or chain of actions) can produce
    When plan is called
    Then the result is an empty list, not an error

  Note: plan() performs uniform-cost (Dijkstra) search, so a cheaper
  multi-step plan is preferred over a pricier direct one when both
  exist -- this spec doesn't yet cover that cost-preference case with
  a competing pair of plans; a good candidate for a follow-up scenario.

