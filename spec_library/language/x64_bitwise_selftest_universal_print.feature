Feature: x64_bitwise_selftest uses print(), not an x64-only primitive (GitHub #47)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: the bitwise selftest prints the same on both engines
    Given the program
      """
      include "{root}/self_hosting/examples/x64_bitwise_selftest.patlang"
      """
    When it runs interpreted and compiled
    Then both print
      """
      8
      15
      6
      1152921504606846976
      1
      """

  History: the file once called rt_print_i64, defined only inside the old
  x64 runtime. The old interpreter treated the unresolved call as a no-op
  and printed nothing, so the comparison with the x64 build's real output
  always reported a mismatch, whether or not the x64 bitwise code was
  right. print() is defined on every engine.
