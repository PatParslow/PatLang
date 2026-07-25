Feature: str_trim (self_hosting/lib/includes.patlang)

  Scenario: Leading and trailing spaces are stripped
    Given "  hello  "
    When str_trim is applied
    Then the result is "hello"

  Scenario: Tabs are stripped
    Given "\thello\t"
    When str_trim is applied
    Then the result is "hello"

  Scenario: A trailing newline is NOT stripped
    Given "hello\n"
    When str_trim is applied
    Then the result is still "hello\n" -- only space/tab/CR count as whitespace here, not \n

