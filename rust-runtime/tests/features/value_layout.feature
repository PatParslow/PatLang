# Guards against: the exact bug found this session -- the compiled-native
# program's `Value` enum quietly doubling in size (128 bytes vs the
# interpreter's 64) because `Value::Complex(ComplexT)` stored its payload
# inline instead of boxed, unlike the interpreter's own
# `Value::Complex(Box<Value>, Box<Value>)`. Nothing in the existing suite
# asserted anything about memory layout, so this went unnoticed until a
# hand-built benchmark harness happened to surface it as a compiled-slower-
# than-interpreted anomaly. These scenarios pin both compiled-path Value
# shapes (`PRELUDE_VALUE_FAST` and `PRELUDE_NUMERIC_TOWER`) and the
# interpreter's real Value to known-good byte bounds using the REAL emitted
# chunk text (not a hand-copied stand-in that could silently drift), so any
# future unboxing regression fails loudly here instead of only showing up as
# an unexplained performance/memory anomaly.

# Note: the interpreter's own `ir::types::Value` size is a property of this
# crate's compiled types, not something observable through the CLI/stdout --
# it's asserted directly, in-process, by tests/value_layout_native.rs
# (`size_of::<patlang_runtime::ir::types::Value>() == 64`) rather than as a
# Gherkin scenario here, and that assertion is what the two scenarios below
# are pinned against.

Feature: Compiled Value memory layout matches the interpreter
  As a maintainer of both Value representations
  I want the compiled path's Value sizes to stay within known-good bounds
  So that a future variant becoming accidentally unboxed is caught immediately

  Scenario: the fast (non-tower) compiled Value module stays small
    Given the "fast" compiled Value module
    When I compile it directly with rustc and run it
    Then the reported Value size is at most 56 bytes

  Scenario: the numeric-tower compiled Value module matches the interpreter's size
    Given the "numeric_tower" compiled Value module
    When I compile it directly with rustc and run it
    Then the reported Value size is at most 64 bytes
