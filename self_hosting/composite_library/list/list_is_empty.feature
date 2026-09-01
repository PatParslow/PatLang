Feature: list_is_empty (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given xs = []
  Then list_is_empty(...) = true

Scenario: example 2
  Given xs = [1]
  Then list_is_empty(...) = false

Scenario: example 3
  Given xs = [1, 2, 3]
  Then list_is_empty(...) = false

