Feature: inner_text (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given line = "note **important** text"
  Given m1 = 5
  Given m2 = 16
  Then inner_text(...) = "important"

Scenario: example 2
  Given line = "**start** of line"
  Given m1 = 0
  Given m2 = 7
  Then inner_text(...) = "start"

Scenario: example 3
  Given line = "a **hi** b"
  Given m1 = 2
  Given m2 = 6
  Then inner_text(...) = "hi"

Scenario: example 4
  Given line = "x **a much longer inner span here** y"
  Given m1 = 2
  Given m2 = 33
  Then inner_text(...) = "a much longer inner span here"

