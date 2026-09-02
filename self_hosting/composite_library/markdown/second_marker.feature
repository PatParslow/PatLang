Feature: second_marker (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "**hello** world"
  Given from = 2
  Then second_marker(...) = 7

Scenario: example 2
  Given text = "abc **bold** def"
  Given from = 6
  Then second_marker(...) = 10

