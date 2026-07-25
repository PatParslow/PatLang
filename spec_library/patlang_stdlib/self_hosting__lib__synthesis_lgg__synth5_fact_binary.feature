Feature: synth5_fact_binary (self_hosting/lib/synthesis_lgg.patlang)

  Scenario: Builds a [pred, arg1, arg2] triple
    Given pred="dep", arg1="a", arg2="b"
    When synth5_fact_binary is applied
    Then the result is ["dep", "a", "b"]

