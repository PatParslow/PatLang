Feature: replace_in_text (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "the quick fox"
  Given original = "quick"
  Given replacement = "slow"
  Then replace_in_text(...) = "the slow fox"

Scenario: example 2
  Given text = "cat sat mat"
  Given original = "cat"
  Given replacement = "hat"
  Then replace_in_text(...) = "hat sat mat"

