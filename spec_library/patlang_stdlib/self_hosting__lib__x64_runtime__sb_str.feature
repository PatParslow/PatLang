Feature: sb_new/sb_push/sb_str (x64 backend's own string builder, self_hosting/lib/x64_runtime.patlang)

  Background:
    This is the x64 native-codegen backend's own heap-based string
    builder -- a hand-rolled bump-allocated byte buffer with a handle
    table, NOT the same implementation as the native interpreter's
    sb_new/sb_push/sb_str (which operate on Rust-native values). They
    share names by convention only, so ordinary PatLang code compiles
    unchanged under either backend. Only callable from code actually
    compiled by the x64 backend (patc1.exe ... --x64) -- these operate
    on tagged-pointer values that don't exist under plain --ir-run.

  Scenario: Sequential pushes concatenate in call order
    Given a fresh handle from sb_new
    When "hello " then "world" are pushed via sb_push
    Then sb_str returns "hello world"

