Feature: json_quote (self_hosting/lib/json.patlang)

  Scenario: A plain string is wrapped in double quotes
    Given "hello"
    When json_quote is applied
    Then the result is "\"hello\""

  Scenario: Embedded double-quotes are escaped
    Given a string containing \"
    When json_quote is applied
    Then the embedded quote becomes \\\"

  Scenario: Embedded backslashes are escaped
    Given a string containing a literal backslash
    When json_quote is applied
    Then it becomes an escaped double-backslash

  Scenario: Embedded newlines are escaped
    Given a string containing a real newline byte
    When json_quote is applied
    Then it becomes the two-character sequence \\n

