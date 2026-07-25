Feature: synth2_ground (self_hosting/lib/synthesis_recursive.patlang)

  Scenario: Prepends the v: prefix
    Given "X"
    When synth2_ground is applied
    Then the result is "v:X"

