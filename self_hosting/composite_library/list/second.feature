Feature: second (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given xs = [10, 20, 30]
  Then second(...) = 20

Scenario: example 2
  Given xs = [a, b, c, d]
  Then second(...) = "b"

