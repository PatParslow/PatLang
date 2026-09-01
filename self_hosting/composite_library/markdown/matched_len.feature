Feature: matched_len (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given m1 = 5
  Given m2 = 16
  Then matched_len(...) = 13

Scenario: example 2
  Given m1 = 0
  Given m2 = 7
  Then matched_len(...) = 9

