Feature: the repository keeps its own rules

  Checks over every file the repository tracks, run by
  self_hosting/tools/run_repository_checks.patlang. Each one closes a gap that let
  a problem through more than once: tests no gate ran, tests that needed tools a
  clean clone does not have, and absence tested by turning a lookup into text.

  Scenario: no program keeps its state in globals
    Given every PatLang file but the old runtime's own and the fixtures testing set_var as a language feature
    When its code is searched for set_global, get_global, set_var and reads of __vars
    Then there are none

  Scenario: every selftest is run by a gate or retired with a reason
    Given every tracked file named *_selftest.patlang
    When each is looked for in run_selftests.patlang's lists, the block-model library parity feature and the gates' own build units
    Then each is in exactly one of them, and each retired one says why

  Scenario: no program starts a retired tool
    Given every tracked PatLang file but the old route's own, each allowed one with its reason
    When its code is searched for rust-runtime/target, patc1.exe, pat.exe and --ir-run
    Then there are none, and every allowed file still exists and still needs its place

  Scenario: no program tests a lookup's absence by turning it into text
    Given every tracked PatLang file
    When its code is searched for "" + get(
    Then there are none: a missing field reads as unit, so the test is == unit (spec 1.5)
