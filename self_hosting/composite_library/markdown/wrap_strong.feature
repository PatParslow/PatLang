Feature: wrap_strong (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given inner = "important"
  Then wrap_strong(...) = "<strong>important</strong>"

Scenario: example 2
  Given inner = "very important"
  Then wrap_strong(...) = "<strong>very important</strong>"

