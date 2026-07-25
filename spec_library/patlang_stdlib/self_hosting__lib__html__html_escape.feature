Feature: html_escape (self_hosting/lib/html.patlang)

  Scenario: Ampersand is escaped
    Given "a&b"
    When html_escape is applied
    Then the result is "a&amp;b"

  Scenario: Angle brackets are escaped
    Given "<div>"
    When html_escape is applied
    Then the result is "&lt;div&gt;"

  Scenario: Double-quotes are escaped
    Given a string containing \"
    When html_escape is applied
    Then it becomes &quot;

  Scenario: Plain text is unchanged
    Given "plain text"
    When html_escape is applied
    Then the result is unchanged

  Note: html.patlang's own implementation walks char_code/substr per
  character; html_scan.patlang's uses the str_intern/sc_len/sc_code
  interned-string API instead -- different approach, same native host
  primitives underneath, both independently verified to produce
  identical results on these cases.

