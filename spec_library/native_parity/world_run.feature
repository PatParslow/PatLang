Feature: world_run gives native x64 programs the same clean-world run as the interpreter

  interp_run's "world" backend runs source in-process, in a world whose global
  stores are swapped for empty ones, and returns the captured stdout. The
  interpreter provides this through world_run; native x64 must give the same
  answer for the same source.

  Scenario: a program run in a clean world returns its printed output
    Given a source string that prints the value of 3 + 4
    When it is run with interp_run and backend "world"
    Then ok is true
    And stdout is "7"
    And stderr is empty

  Scenario: a clean world does not see the caller's variables
    Given the caller has set the variable "marker" to 42
    And a source string that prints the value of "marker" or -1 when it is unset
    When it is run with interp_run and backend "world"
    Then stdout is "-1"
    And the caller still reads "marker" as 42 afterwards

  Scenario: the caller's variables are restored after a world run that changes them
    Given the caller has set the variable "marker" to 42
    And a source string that sets "marker" to 0 and prints it
    When it is run with interp_run and backend "world"
    Then stdout is "0"
    And the caller still reads "marker" as 42 afterwards

  Scenario: an exhausted step budget reports failure without leaking state
    Given a source string that loops forever
    When it is run with interp_run, backend "world", and max_steps 1000
    Then ok is false
    And the caller still reads "marker" as 42 afterwards

  Scenario: a crashing program reports failure with its error text
    Given a source string that calls an undefined function
    When it is run with interp_run and backend "world"
    Then ok is false
    And stderr is not empty

  Scenario: stdin is rejected by the world backend
    Given a source string that reads a line from stdin
    When it is run with interp_run, backend "world", and stdin "x"
    Then ok is false
    And stderr mentions "stdin"

  Scenario: native and interpreter agree on every scenario above
    Given each scenario above is compiled with --x64 and with --ir-run
    When both binaries run it
    Then their ok, stdout, and stderr values are identical
