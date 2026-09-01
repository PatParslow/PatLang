Feature: up_to_space (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given s = "/health HTTP/1.1"
  Then up_to_space(...) = "/health"

Scenario: example 2
  Given s = "/x HTTP/1.1"
  Then up_to_space(...) = "/x"

