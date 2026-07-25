Feature: synth2_query (self_hosting/lib/synthesis_recursive.patlang)

  Scenario: Builds a [pred, arg, expect] triple
    Given pred="buildable", arg="widget", expect=true
    When synth2_query is applied
    Then the result is ["buildable", "widget", true]

