Feature: rule Head(...) :- Body. (declaration sugar over rule_add)

  Scenario: The sugar form produces the same result as a hand-written rule_add call
    Given `rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z).` plus parent(alice,bob) and parent(bob,carol)
    When solve("grandparent", ["alice", "Z"]) is called
    Then Z resolves to "carol" -- identical to the hand-written rule_add equivalent, since this IS that call under sugar

