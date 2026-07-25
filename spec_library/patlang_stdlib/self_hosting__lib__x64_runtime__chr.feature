Feature: chr (x64 backend runtime, self_hosting/lib/x64_runtime.patlang)

  Scenario: A byte value converts to its 1-byte string
    Given the value 10 (newline)
    When chr is applied
    Then the result is a single newline byte, used as a line separator by the probe itself

  Scenario: Scope is single-byte only
    Given this backend's strings are plain bytes, no UTF-8 handling
    When chr is applied to any value
    Then only a single-byte ASCII-range result is ever produced

