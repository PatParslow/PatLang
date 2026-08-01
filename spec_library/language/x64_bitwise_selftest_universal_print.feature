Feature: x64_bitwise_selftest uses print(), not an x64-only primitive (GitHub #47)

  Scenario: bitwise selftest passes interp-vs-x64 comparison
    Given self_hosting/examples/x64_bitwise_selftest.patlang uses print()
      (available under every backend) instead of rt_print_i64 (only defined
      inside self_hosting/lib/x64_runtime.patlang, in scope for --x64 alone)
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both show: 8, 15, 6, 1152921504606846976, 1
    And the two outputs match exactly

  Scenario: RED before the fix
    Given the original file called rt_print_i64, a name unresolved under
      pat --ir-run/--patc
    When the file was run under `pat --ir-run` before this fix
    Then every rt_print_i64 call silently no-op'd (an unresolved Call does not
      error under this project's interpreter), producing EMPTY interpreter
      output
    And comparing that empty output against the x64 backend's real,
      correct output (8/15/6/1152921504606846976/1) always reported a
      mismatch, regardless of whether the x64 backend's own bitwise codegen
      was correct
