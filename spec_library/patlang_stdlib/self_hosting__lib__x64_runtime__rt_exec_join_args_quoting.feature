Feature: rt_exec_join_args quote-only-when-needed (self_hosting/lib/x64_runtime.patlang, GitHub #43)

  Scenario: A multi-word argument keeps its quotes through cmd.exe's own /c re-parsing
    Given the x64 backend compiles a program that calls
      exec_capture("cmd.exe", "/c", "echo", "hello from exec_capture")
    When the compiled program prints the captured output
    Then it prints "hello from exec_capture" with the surrounding double quotes
      intact
    And this exactly matches `pat --ir-run`'s own output for the same program

  Scenario: A space-containing program path is still correctly quoted
    Given rt_exec_join_args is asked to join an argument containing a space
      (e.g. an install path like "C:\Program Files\NASM\nasm.exe")
    When the joined command line is built
    Then that argument is still wrapped in double quotes
    And CreateProcessA's own tokenizer treats it as a single argument, not two

  Scenario: An argument with no spaces is joined without quotes
    Given rt_exec_join_args is asked to join a plain single-word argument
      (e.g. "echo")
    When the joined command line is built
    Then that argument is NOT wrapped in quotes

  Scenario: RED before the fix
    Given rt_exec_join_args previously quoted EVERY argument unconditionally
    When x64_exec_capture_r15_selftest.patlang was run before this fix
    Then it printed "hello from exec_capture" WITHOUT quotes -- a real
      mismatch against the interpreter's quoted output, confirmed via
      self_hosting/x64_exec_capture_r15_selftest.patlang
