Feature: strip_hash (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given line = "# Hello"
  Then strip_hash(...) = "Hello"

Scenario: example 2
  Given line = "# World"
  Then strip_hash(...) = "World"

