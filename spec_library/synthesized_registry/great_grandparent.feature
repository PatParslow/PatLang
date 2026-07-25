Feature: great_grandparent(X) -- synthesized via pure logic induction (Tier A, no LLM)

  Background (Given, background facts, shown during induction):
    parent(alice, bob). parent(bob, carol). parent(carol, dave).
    parent(erin, frank). parent(frank, george). parent(george, helen).
    parent(grace, henry). parent(henry, irene). parent(irene, jack).
    (the grace/henry/irene/jack chain exists in the background but was
    NEVER referenced by any example shown during induction -- reserved
    entirely for the blind held-back check below)

  Scenario: Visible positive examples (shown to the induction engine)
    Given alice has a witnessed 3-hop parent chain (alice->bob->carol->dave)
    And erin has a witnessed 3-hop parent chain (erin->frank->george->helen)
    When synth5_induce("great_grandparent", ["alice","erin"], visible_queries, facts, 5) runs
    Then it returns ["ok", <chain>] -- a genuine 3-hop chain rule was induced from these two examples alone

  Scenario: Visible negative example (shown to the induction engine)
    Given dave, at the END of a chain with no further children
    When great_grandparent(dave) is checked
    Then it correctly evaluates false -- dave has no witnessed 3-hop chain of his own

  Scenario: BLIND held-back positive check (NEVER shown during induction)
    Given grace's chain (grace->henry->irene->jack), never referenced by any visible example or query
    When the INDUCED rule (not re-induced, the exact same one from the visible examples) is checked against great_grandparent(grace)
    Then it correctly evaluates true -- the rule genuinely generalizes to a witnessed-but-unseen case, not just the two chains it was shown

  Scenario: BLIND held-back negative check (NEVER shown during induction)
    Given bob, only 2 hops deep in the FIRST chain (a plausible-looking near-miss, not obviously distinguishable from a real great-grandparent without actually applying the rule)
    When the same induced rule is checked against great_grandparent(bob)
    Then it correctly evaluates false -- confirming the rule didn't overfit to "anyone connected to alice's chain"
