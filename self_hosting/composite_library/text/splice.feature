Feature: splice (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "the quick fox"
  Given position = 4
  Given original_len = 5
  Given replacement = "slow"
  Then splice(...) = "the slow fox"

Scenario: example 2
  Given text = "a b c"
  Given position = 2
  Given original_len = 1
  Given replacement = "banana"
  Then splice(...) = "a banana c"

