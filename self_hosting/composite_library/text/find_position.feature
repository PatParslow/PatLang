Feature: find_position (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "cat sat mat"
  Given original = "cat"
  Then find_position(...) = 0

Scenario: example 2
  Given text = "the quick fox"
  Given original = "quick"
  Then find_position(...) = 4

Scenario: example 3
  Given text = "a b c d e original"
  Given original = "original"
  Then find_position(...) = 10

