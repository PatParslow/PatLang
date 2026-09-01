Feature: find_position_from (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "**bold** and more"
  Given needle = "**"
  Given start = 2
  Then find_position_from(...) = 6

Scenario: example 2
  Given text = "a **very bold** word"
  Given needle = "**"
  Given start = 3
  Then find_position_from(...) = 13

