# A richer version of vending_machine.feature: it names its own state
# ("vending machine inventory", "Bowen's balance") and states its
# preconditions/postconditions as quantities and arithmetic rather than
# leaving them implicit, so zi_infer_skeleton_auto (self_hosting/lib/
# zs_infer.patlang) can infer real require/ensure clauses and the state
# variables they talk about, not just vacuous placeholders.
Feature: Buying a snack using money
  As a user
  Bowen wants to buy a snack with money
  So that Bowen can get a snack to eat

  Scenario: Buying a cookie using money when the cookie is in stock
    Given cookie is in stock
    And vending machine inventory contains at least one cookie
    And Bowen's balance is at least 10 dollars
    When Bowen inserts 10 dollars
    And Bowen selects cookie
    Then the vending machine dispenses a cookie
    And the vending machine inventory subtracts a cookie
    And Bowen's balance is decreased by 10 dollars
