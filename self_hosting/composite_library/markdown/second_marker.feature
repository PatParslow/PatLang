Feature: second_marker (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given line = "note **important** text"
  Given first_pos = 5
  Then second_marker(...) = 16

Scenario: example 2
  Given line = "**start** of line"
  Given first_pos = 0
  Then second_marker(...) = 7

Scenario: example 3
  Given line = "a ***bold** b"
  Given first_pos = 2
  Then second_marker(...) = 9

