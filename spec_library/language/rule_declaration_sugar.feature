Feature: rule Head(...) :- Body. (declaration sugar over rule_add)

  Scenario: The sugar form produces the same result as a hand-written rule_add call
    Given `rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z).` plus parent(alice,bob) and parent(bob,carol)
    When solve("grandparent", ["alice", "Z"]) is called
    Then Z resolves to "carol" -- identical to the hand-written rule_add equivalent, since this IS that call under sugar

  Scenario: A rule declaration can name the store it goes in, and a body goal the store it is solved against
    Given `rule spec_store_parent(alice, bob) in spec_family.`, `rule spec_store_parent(bob, carol) in spec_family.` and `rule spec_store_gp(X, Z) :- spec_store_parent(X, Y) from spec_family, spec_store_parent(Y, Z) from spec_family.`
    When solve("spec_store_gp", ["alice", "Z"]) and solve("spec_store_parent", ["alice", "Y"]) are called
    Then Z resolves to "carol", and the parent facts are in spec_family, not in the default store
