Feature: sdsl_len/sdsl_trim (self_hosting/lib/syntax_dsl.patlang)

  Scenario: sdsl_len returns the character count
    Given "hello"
    When sdsl_len is applied
    Then the result is 5

  Scenario: sdsl_trim strips leading/trailing whitespace
    Given "  hello  "
    When sdsl_trim is applied
    Then the result is "hello"

  Note: sdsl_len/sdsl_trim take a plain string `s` (via list_len/substr),
  distinct from the `h`-suffixed sibling functions in this same file
  which take a str_intern HANDLE instead (see this file's own header
  comment above sdsl_len) -- do not mix the two calling conventions.

