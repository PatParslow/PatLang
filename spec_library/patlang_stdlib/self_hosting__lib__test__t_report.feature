Feature: t_report (self_hosting/lib/test.patlang)

  Background:
    This spec verifies t_report's OWN narrow contract (reads t_pass/
    t_fail counters, reports, returns a boolean) by setting those
    counters directly -- it does NOT verify that check() (which
    normally sets them) correctly judges any given assertion. That
    would be a genuinely circular claim (verifying the test framework's
    own correctness using the test framework), named explicitly here
    rather than quietly assumed away.

  Scenario: All tests passed
    Given t_pass=3, t_fail=0
    When t_report is called
    Then it returns true

  Scenario: Some tests failed
    Given t_pass=2, t_fail=1
    When t_report is called
    Then it returns false

