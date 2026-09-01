Feature: body_for_path (derived by example, self_hosting/lib/synthesis_by_example.patlang)

Scenario: example 1
  Given path = "/health"
  Then body_for_path(...) = "OK"

Scenario: example 2
  Given path = "/echo"
  Then body_for_path(...) = "ECHO"

Scenario: example 3
  Given path = "/time"
  Then body_for_path(...) = "TIME"

Scenario: example 4
  Given path = "/nope"
  Then body_for_path(...) = "NOT FOUND"

