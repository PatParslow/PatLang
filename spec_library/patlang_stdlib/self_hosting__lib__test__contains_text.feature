Feature: contains_text (self_hosting/lib/test.patlang)

  Scenario: A substring occurring mid-string is found
    Given "hello world" and needle "lo wo"
    When contains_text is applied
    Then the result is true

  Scenario: A needle not present
    Given "hello world" and needle "xyz"
    When contains_text is applied
    Then the result is false

  Scenario: A needle longer than the haystack
    Given "hi" and needle "hello"
    When contains_text is applied
    Then the result is false, not an error

