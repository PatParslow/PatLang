Feature: step (self_hosting/lib/test.patlang)

  Scenario: Registers a step's implementing function
    Given step text "a fresh till" and implementing function name "st_fresh_till"
    When step is called
    Then get("a fresh till", "fn") returns "st_fresh_till" -- a real object-system side effect (new + send), not a pure computation

