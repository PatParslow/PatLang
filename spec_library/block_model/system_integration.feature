Feature: system integration, a representative slice (Phase 17 of the full-language expansion)

  Scoped deliberately to `read_file`/`write_file`, checked before writing
  code: both are genuine, fixed-arity host functions (rust-runtime/src/ir/
  hosts.rs), following the exact "call the real host function directly"
  pattern already used for Print/FiberYield/Fact/Query/TypeOf. `spawn`/
  `exec_capture` take a VARIADIC argument list this engine's fixed-arity
  recognized-call pattern doesn't accommodate without real design work
  (an argc-carrying instruction); `queue_publish`/`consume`/`ack` turned
  out not to be Rust host functions at all but ordinary PatLang library
  functions (self_hosting/lib/queue.patlang), a real dependency this pass
  doesn't pull in; `signal_*` is deferred for the same reason. Each is a
  real, separable follow-up, named here rather than assumed covered.

  Scenario: a file write/read round-trip preserves a heap-allocated string value correctly
    Given a block that writes a string to a file, then a different block that reads it back
    When it runs
    Then the read-back content matches exactly what was written
