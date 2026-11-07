Feature: x64 dynamic-dispatch regressions (#98/#100/#85) -- a real interp-vs-x64/interp-vs-native comparison

  Scenario: band of a Float stops the program on both engines, as spec 1.11 says (#98)
    Given self_hosting/examples/x64_float_bitwise_native.patlang calls
      `band` on a value that is sometimes a plain int (1) and sometimes a
      genuine Float (1.0 + 61.0), forcing dynamic dispatch
    When the file is run on the v2 interpreter and compiled and run by v2
    Then both show 1, then stop at band of the float
    And the two outputs match exactly

  Scenario: string + bool, and print()'s own Unit return, both now match the interpreter under --x64 (#100, #85)
    Given self_hosting/examples/x64_dynamic_dispatch_regressions.patlang
      concatenates a string with a genuine Bool operand on both sides
      (#100), then captures print()'s own return value and inspects its
      type_of() and its behavior when concatenated with a string (#85)
    When the file is run on the v2 interpreter and compiled and run by v2
    Then both show: bool concat: true, false tail, noop, unit, prefix:
    And the two outputs match exactly

  Scenario: printing gives genuine Unit, not the old truthy-Bool placeholder (#63 item 2)
    Given self_hosting/examples/x64_rt_print_str_unit_native.patlang prints a string, a bool and a float, and reports type_of() on each print's result
    When the file is run on the v2 interpreter and compiled and run by v2
    Then both show: a, unit, true, unit, 3, unit

  Scenario: sqrt/sin/cos/pow print their real numeric result under --x64, not a garbage int (#109)
    Given self_hosting/examples/x64_math1_float_print_native.patlang calls sqrt/sin/cos/pow
    When the file is run on the v2 interpreter and compiled and run by v2
    Then both show the same real numeric results, not garbage ints (GitHub #109)

  Note: none of these four were catchable by the Rust cargo test suite
  (it has zero tests that invoke --x64 at all) or, for #85 and the
  related #83/#99 floor() regression, by `--ir-run`-only verification --
  both were previously "confirmed fixed" using only the interpreter,
  which never exercises the real x64 codegen/assembly/object-cache path
  a genuine `--x64` compile+run does. This is why these scenarios insist
  on a real compiled binary's actual output, not just a codegen-text
  inspection or an interpreter run alone.
