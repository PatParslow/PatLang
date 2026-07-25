Feature: starts_with (self_hosting/lib/markdown.patlang)

  Scenario: A genuine prefix match
    Given "hello world" and prefix "hello"
    When starts_with is applied
    Then the result is true

  Scenario: Not a prefix
    Given "hello world" and prefix "world"
    When starts_with is applied
    Then the result is false

  Scenario: Prefix longer than the string
    Given "hi" and prefix "hello"
    When starts_with is applied
    Then the result is false, not an error

  Note: markdown.patlang and test.patlang each declare their OWN
  starts_with (a real name collision, PatLang has no namespacing) --
  confirmed by direct source comparison to be BYTE-IDENTICAL bodies,
  unlike html_escape's genuinely different pair -- both independently
  verified here rather than assumed identical from the collision alone.

