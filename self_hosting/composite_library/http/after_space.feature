Feature: after_space (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given s = "GET /health HTTP/1.1"
  Then after_space(...) = "/health HTTP/1.1"

Scenario: example 2
  Given s = "POST /x HTTP/1.1"
  Then after_space(...) = "/x HTTP/1.1"

Scenario: example 3
  Given s = "GET /a/very/long/path/that/keeps/going/on/and/on/for/a/while HTTP/1.1"
  Then after_space(...) = "/a/very/long/path/that/keeps/going/on/and/on/for/a/while HTTP/1.1"

