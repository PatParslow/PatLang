Feature: substr (x64 backend runtime, self_hosting/lib/x64_runtime.patlang)

  Scenario: A mid-string slice is extracted
    Given "hello world"
    When substr is applied with start 6, count 5
    Then the result is "world"

