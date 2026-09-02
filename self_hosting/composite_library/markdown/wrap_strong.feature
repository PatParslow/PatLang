Feature: wrap_strong (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given inner = "hello"
  Then wrap_strong(...) = "<strong>hello</strong>"

Scenario: example 2
  Given inner = "bold"
  Then wrap_strong(...) = "<strong>bold</strong>"

