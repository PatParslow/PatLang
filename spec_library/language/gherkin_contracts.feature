Feature: Gherkin-driven contract clauses for GOAP synthesis (require/ensure steps)

  Scenario: A require/ensure clause checked against a hand-written function's own bound value
    Given `Given an integer x` binds the global variable x, and a scenario adds `And require x < 10` / `And ensure x < 20`
    When the scenario runs against a hand-written "brilliant" transformation (returns 2*x)
    Then both clauses are evaluated immediately against the bound value of x, exactly like an ordinary require/ensure statement would be

  Scenario: A require/ensure clause checked against a GOAP-synthesized action's own binding
    Given an action `scale(X)` requiring `input(X)`, producing `scaled(X)`, and a scenario clause `And require X < 10` / `And ensure X < 20`
    When `plan([["scaled", ["5"]]])` synthesizes the candidate `scale(X=5)`
    Then both clauses are evaluated against X's bound value as parsed out of that plan step's own label, before the candidate is accepted -- not encoded as a GOAP GroundFact (a scalar comparison like `X < 10` isn't a unifiable ground predicate the way action_add's preconditions are)

  Scenario: A synthesized candidate that violates its contract clause is correctly rejected, not silently accepted
    Given the same `scale(X)` action, but `plan([["scaled", ["15"]]])` synthesizes `scale(X=15)`
    When the scenario's `And require X < 10` clause is checked against that binding
    Then the violation is detected and reported -- the scenario's own meta-check ("a contract-violating candidate is correctly rejected") is what passes, honestly distinguishing "the feature works" from "the underlying candidate happened to satisfy its contract"

  Scenario: The contract-checking mechanism never becomes a runtime assertion itself
    Given the library that implements require/ensure clause checking (self_hosting/lib/gherkin_contracts.patlang)
    When its own source text is inspected directly
    Then it contains no call to contract_check(...) -- the host primitive require/ensure/assert always lower to elsewhere in the language -- confirming the guard is genuinely separate from (and happens before) any code that would run the checked action for real
