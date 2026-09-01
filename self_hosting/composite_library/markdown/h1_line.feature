Feature: h1_line (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given line = "# Hello"
  Then h1_line(...) = "<h1>Hello</h1>"

Scenario: example 2
  Given line = "# World Peace"
  Then h1_line(...) = "<h1>World Peace</h1>"

