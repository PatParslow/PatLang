Feature: x64_nl_char (self_hosting/lib/codegen_x64.patlang)

  Scenario: Returns a single newline byte
    Given no arguments
    When x64_nl_char is called
    Then the result is exactly one byte, chr(10)

  Note: unlike x64_runtime.patlang's functions, this one runs at
  CODEGEN time (compiling the .asm text itself), not inside the
  compiled target program -- ordinary native chr() applies, no tagged-
  pointer representation involved, safely callable under --ir-run.

