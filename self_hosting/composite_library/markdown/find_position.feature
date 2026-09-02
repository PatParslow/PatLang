Feature: find_position (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "**hello** world"
  Given marker = "**"
  Then find_position(...) = 0

Scenario: example 2
  Given text = "abc **bold** def"
  Given marker = "**"
  Then find_position(...) = 4

