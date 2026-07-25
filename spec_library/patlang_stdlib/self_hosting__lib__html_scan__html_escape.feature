Feature: html_escape (self_hosting/lib/html_scan.patlang)

  Scenario: Ampersand is escaped
    Given "a&b"
    When html_escape is applied
    Then the result is "a&amp;b"

  Scenario: Angle brackets are escaped
    Given "<div>"
    When html_escape is applied
    Then the result is "&lt;div&gt;"

  Scenario: Double-quotes are NOT escaped (deliberately different from html.patlang's html_escape)
    Given a string containing \"
    When html_escape is applied
    Then the quote passes through unchanged -- quote-escaping for attribute contexts is the separate html_attr_escape function in this same file

  Scenario: Plain text is unchanged
    Given "plain text"
    When html_escape is applied
    Then the result is unchanged

