Feature: es_contains (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given hay = "hello world"
  Given needle = "world"
  Then es_contains(...) = true

Scenario: example 2
  Given hay = "hello world"
  Given needle = "zzz"
  Then es_contains(...) = false

