Feature: x64 hosts match the interpreter (GitHub #114, #115)

  Scenario: the file hosts return the same types and values under --x64 (#115)
    Given self_hosting/file_hosts_parity_selftest.patlang
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both report: tests: 13 passed, 0 failed

  Scenario: sc_substr, sed and the stage-0 shim hosts exist under --x64 (#114)
    Given self_hosting/host_parity_selftest.patlang
    When the file is run under `pat --ir-run` and compiled+run via `--x64` again
    Then both report: tests: 32 passed, 0 failed

  Scenario: a host name with no implementation stops an --x64 program only when it is reached (#114)
    Given self_hosting/examples/x64_unresolved_host_native.patlang calls a host that does not exist
    When the file is run under `pat --ir-run` and compiled+run via `--x64` once more
    Then both print the lines before the call and stop at it with host fn 'no_such_host' not found
