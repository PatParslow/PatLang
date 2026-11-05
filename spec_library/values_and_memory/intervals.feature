@language
Feature: intervals (spec 1.12)

  Scenario: an interval is a value with exact ends and the interval rules of arithmetic
    Given intervals made with interval_make, with int, rational and bigint ends
    When a program prints their class, their ends and their sums, differences, products and negations, alone and with real numbers
    Then each prints what the rules of spec 1.12 give

  Scenario: an interval whose low end is above its high end cannot be made
    Given interval_make(2, 1)
    When it is called
    Then the program stops at that call, naming interval_make's require clause

  Scenario: an interval has no division
    Given interval_make(1, 2) / 2
    When it is evaluated
    Then the program stops, naming the interval class
