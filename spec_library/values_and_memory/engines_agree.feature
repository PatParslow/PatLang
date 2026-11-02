@language
Feature: the interpreter and native code are one language (spec 1.7)

  Scenario: every @language scenario gives the same result on both engines
    Given each @language scenario in spec_library/values_and_memory
    When it runs under the interpreter and as a native executable
    Then both pass, with the same printed output
