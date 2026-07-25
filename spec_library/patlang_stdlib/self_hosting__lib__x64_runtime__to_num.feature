Feature: to_num (x64 backend runtime, self_hosting/lib/x64_runtime.patlang)

  Scenario: A digit string is parsed
    Given the string "123"
    When to_num is applied
    Then the result is the integer 123

  Scenario: A leading '-' is honoured
    Given the string "-45"
    When to_num is applied (probed as 0-7 negated fixnum)
    Then the negative value round-trips correctly

  Scenario: Scope is deliberately limited to integer parsing
    Given this backend's own call sites only ever pass already-integer-valued strings
    When to_num is applied
    Then no float-string parsing is attempted (unlike the native interpreter's fuller to_num)

