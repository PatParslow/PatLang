# Listing 15 of the thesis: the feature the schema is checked against.
Feature: Buying a snack using money
  As a user
  Bowen wants to buy a snack with money
  So that Bowen can get a snack to eat

  Scenario: Buying a cookie using money when the cookie is in stock
    Given cookie is in stock
    When Bowen inserts 10 dollars
    And Bowen selects cookie
    Then the vending machine dispenses a cookie
