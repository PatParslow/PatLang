Feature: take_before (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "the quick fox"
  Given position = 4
  Then take_before(...) = "the "

Scenario: example 2
  Given text = "cat sat mat"
  Given position = 0
  Then take_before(...) = ""

