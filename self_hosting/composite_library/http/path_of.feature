Feature: path_of (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given reqline = "GET /health HTTP/1.1"
  Then path_of(...) = "/health"

Scenario: example 2
  Given reqline = "POST /x HTTP/1.1"
  Then path_of(...) = "/x"

