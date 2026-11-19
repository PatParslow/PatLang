Feature: fact / query (legacy flat 2-arg logic trio)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: fact records a binary relation
    Given the program
      """
      fact("likes", "alice", "bob")
      fact("likes", "alice", "carol")
      print(query("likes", "alice", "anything"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      2
      """

  Scenario: the third query argument is accepted but ignored
    Given the program
      """
      fact("likes", "alice", "bob")
      fact("likes", "alice", "carol")
      print([query("likes", "alice", "bob"), query("likes", "alice", "something_else_entirely")])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [2, 2]
      """

  Scenario: no matching facts returns 0
    Given the program
      """
      fact("likes", "alice", "bob")
      print(query("likes", "nobody_ever_recorded", "x"))
      """
    When it runs interpreted and compiled
    Then both print
      """
      0
      """

  Note: this is the LEGACY trio (hard-coded to exactly 2 relation
  arguments) -- rule_add/solve (separate spec) is the real, general
  backward-chaining engine and is what an inference/synthesis system
  should actually reach for; fact/query is documented here for
  accuracy, not as a recommendation.
