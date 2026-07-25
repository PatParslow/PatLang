Feature: file_exists (self_hosting/lib/x64_runtime.patlang)

  Scenario: A real file returns "1"
    Given a path that exists on disk
    When file_exists is applied
    Then the result is the STRING "1" (not a boolean or integer)

  Scenario: A nonexistent path returns "0"
    Given a path that does not exist
    When file_exists is applied
    Then the result is the STRING "0"

