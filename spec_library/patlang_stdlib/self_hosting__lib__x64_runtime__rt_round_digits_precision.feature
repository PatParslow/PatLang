Feature: rt_round_digits float precision (self_hosting/lib/x64_runtime.patlang, GitHub #42)

  Scenario: sqrt(2.0) prints with full round-trip precision, matching the interpreter
    Given the x64 backend compiles a program that calls print(sqrt(2.0))
    When the compiled program is run
    Then it prints "1.4142135623730951"
    And this exactly matches `pat --ir-run`'s own output for the same program

  Scenario: atan2(1.0, 1.0) prints with full round-trip precision, matching the interpreter
    Given the x64 backend compiles a program that calls print(atan2(1.0, 1.0))
    When the compiled program is run
    Then it prints "0.7853981633974483"
    And this exactly matches `pat --ir-run`'s own output for the same program

  Scenario: RED before the fix
    Given rt_round_digits kept only 15 fractional digits (one short of Rust's f64
      Display round-trip precision for these values)
    When x64_math_selftest.patlang was run before this fix
    Then it printed "1.414213562373095" (missing the trailing 1) and
      "0.785398163397448" (missing the trailing 3) -- a real mismatch against
      the interpreter, confirmed via self_hosting/x64_math_selftest.patlang
