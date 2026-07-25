Feature: rt_print_i64 (self_hosting/lib/x64_runtime.patlang)

  Scenario: A negative number formats with a leading '-'
    Given the value -42
    When rt_print_i64 is applied
    Then "-42" followed by a newline is written to stdout

