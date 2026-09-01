Feature: first_line (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given text = "GET /health HTTP/1.1

"
  Then first_line(...) = "GET /health HTTP/1.1"

Scenario: example 2
  Given text = "POST /x HTTP/1.1

"
  Then first_line(...) = "POST /x HTTP/1.1"

