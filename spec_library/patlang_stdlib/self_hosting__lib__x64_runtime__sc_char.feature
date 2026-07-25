Feature: sc_code/sc_char (self_hosting/lib/x64_runtime.patlang)

  Background:
    These names ALSO exist as genuine, DIFFERENT native host functions
    (rust-runtime/src/ir/hosts.rs registers sc_len/sc_code/sc_char/
    str_intern directly). x64_runtime.patlang's own versions here are
    thin wrappers around mem_peek_qword/mem_peek_byte on a str_intern-
    derived handle -- confirm which one a given call site actually
    resolves to (whether x64_runtime.patlang is included/compiled for
    that call site) before assuming this spec applies.

  Scenario: sc_code returns the ASCII code at an index
    Given a str_intern handle for "XYZ"
    When sc_code is applied with idx 0
    Then the result is 88 ('X')

  Scenario: sc_char returns the character at an index
    Given a str_intern handle for "XYZ"
    When sc_char is applied with idx 2
    Then the result is "Z"

