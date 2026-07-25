Feature: lower_case (PatLang-native, friendly_cli/lib/path_discovery.patlang)

  Scenario: Uppercase ASCII letters are converted
    Given the string "HELLO World 123!"
    When lower_case is applied
    Then the result is "hello world 123!"

  Scenario: Already-lowercase text is left unchanged
    Given the string "already lower"
    When lower_case is applied
    Then the result is unchanged

  Scenario: Non-letter characters are left unchanged
    Given the string "123!@#"
    When lower_case is applied
    Then the result is unchanged

  Scenario: Scope is ASCII only
    Given lower_case has no Unicode-aware case folding
    When applied to non-ASCII letters
    Then only the ASCII A-Z range is converted; other scripts are left as-is

