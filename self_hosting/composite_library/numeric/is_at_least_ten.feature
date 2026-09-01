Feature: is_at_least_ten (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given n = 15
  Then is_at_least_ten(...) = true

Scenario: example 2
  Given n = 3
  Then is_at_least_ten(...) = false

Scenario: example 3
  Given n = 10
  Then is_at_least_ten(...) = true

Scenario: example 4
  Given n = 9
  Then is_at_least_ten(...) = false

