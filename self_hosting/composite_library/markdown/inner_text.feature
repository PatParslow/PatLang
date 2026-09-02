Feature: inner_text (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "**hello** world"
  Given start = 2
  Given end = 7
  Then inner_text(...) = "hello"

Scenario: example 2
  Given text = "abc **bold** def"
  Given start = 6
  Given end = 10
  Then inner_text(...) = "bold"

Scenario: example 3
  Given text = "x**y** longer tail here"
  Given start = 3
  Given end = 4
  Then inner_text(...) = "y"

