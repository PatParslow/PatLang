Feature: take_after (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "the quick fox"
  Given position = 9
  Then take_after(...) = " fox"

Scenario: example 2
  Given text = "a b this tail deliberately runs past thirty two characters and keeps going for a while longer still"
  Given position = 4
  Then take_after(...) = "this tail deliberately runs past thirty two characters and keeps going for a while longer still"

