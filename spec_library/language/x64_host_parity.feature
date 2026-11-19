Feature: x64 hosts match the interpreter (GitHub #114, #115)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). The first two run a selftest
  and check its summary, and that both engines print the same.

  Scenario: the file hosts return the same types and values (#115, #192)
    Given the program
      """
      include "{root}/self_hosting/file_hosts_parity_selftest.patlang"
      """
    When it runs interpreted and compiled
    Then both print the same, ending
      """
      tests: 18 passed, 0 failed
      ALL TESTS PASSED
      """

  Scenario: sc_substr, sed and the stage-0 shim hosts exist (#114)
    Given the program
      """
      include "{root}/self_hosting/host_parity_selftest.patlang"
      """
    When it runs interpreted and compiled
    Then both print the same, ending
      """
      tests: 32 passed, 0 failed
      ALL TESTS PASSED
      """

  Scenario: a host name with no implementation stops a program only when it is reached (#114)
    Given the program
      """
      print("before")
      if 1 == 2 then
        no_such_host(1)
      end
      print("dead branch skipped")
      no_such_host(2)
      print("never printed")
      """
    When it runs interpreted and compiled
    Then both print, before stopping
      """
      before
      dead branch skipped
      """
    And both stop, saying
      """
      host fn 'no_such_host' not found
      """
