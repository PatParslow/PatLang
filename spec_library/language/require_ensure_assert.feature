Feature: require / ensure / assert (design-by-contract)

  Scenario: A passing contract has no visible effect
    Given `safe_divide(10, 2)` with `require b != 0` and `ensure (r*b)==a`
    When called
    Then it returns 5 normally, as if no contract were present

  Scenario: A require violation is fatal, naming the function/kind/condition
    Given `safe_divide(0, 0)`
    When called
    Then it fails with "contract violation: precondition failed in safe_divide(): b != 0" -- the exact source condition text, not a generic message

  Scenario: require/ensure/assert all lower to the same underlying check
    Given the three different keywords
    When any one fails
    Then the error names the correct kind label ("precondition" for require, "postcondition" for ensure, "assertion" for assert) -- distinguished by a string tag on ONE shared host call, not three separate mechanisms

