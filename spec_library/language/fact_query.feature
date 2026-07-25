Feature: fact / query (legacy flat 2-arg logic trio)

  Scenario: fact records a binary relation
    Given fact("likes", "alice", "bob") and fact("likes", "alice", "carol")
    When query("likes", "alice", ANYTHING) is called
    Then the result is 2 -- a COUNT of matching facts, not a boolean or a list

  Scenario: the third query argument is accepted but ignored
    Given the same facts above
    When query is called with different, even nonsensical, third arguments
    Then the result is unchanged -- query only ever filters on (pred, a), matching ANY b

  Scenario: no matching facts returns 0
    Given a subject with no recorded facts
    When query is called
    Then the result is 0, not an error

  Note: this is the LEGACY trio (hard-coded to exactly 2 relation
  arguments) -- rule_add/solve (separate spec) is the real, general
  backward-chaining engine and is what an inference/synthesis system
  should actually reach for; fact/query is documented here for
  accuracy, not as a recommendation.

