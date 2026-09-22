Feature: the same block-model IR also compiles correctly to WASM (Block Ownership Model, Fork A, viability check)

  Checked before considering a full-language expansion of this design:
  does native_codegen.patlang's own translation (BlockProgramIR -> a
  single, real, flat FuncIR) work through a SECOND, completely separate
  backend, not just self_hosting/lib/codegen_x64.patlang? PatLang's own
  WASM story is a genuinely different code generator --
  self_hosting/lib/codegen.patlang's own emit_program_rs (mirroring
  rust-runtime/src/ir/codegen.rs), which emits Rust source text then
  cross-compiles it via `rustc --target wasm32-wasip1` -- not the
  self-hosted x64 backend targeting wasm somehow.

  bm_to_real_funcir itself needed NO changes for this beyond one
  parameter: the two backends disagree about whether `print` is an
  ordinary Call (x64_runtime.patlang defines it as a real PatLang
  function) or a genuine CallHost (codegen.patlang's own host_chunk_of
  maps "print" to its "io_misc" chunk) -- found by checking each
  backend's own source directly, not assumed uniform. A real, pre-
  existing gap was also found and worked around along the way:
  x64_runtime.patlang cannot be `include`d directly into an ordinary
  --ir-run script at all (a parameter named a reserved keyword in the
  native Rust parser used for ordinary scripts, fine only because it's
  normally consumed exclusively via patc1.exe's own internal self-hosted
  parsing pipeline) -- confirmed in isolation before concluding it, and
  worked around by inlining the small rustc-invocation logic needed
  instead of including that whole file.

  Scenario: a loop-free, two-block program compiles to WASM and runs correctly
    Given a program that jumps from one block to another, forwarding two values
    When it is compiled via emit_program_rs and run under a real WASM host
    Then it prints the correct result

  Scenario: a loop (the shape that had the real bug in the x64 path) also runs correctly and terminates under WASM
    Given a loop of a known, small iteration count
    When it is compiled via emit_program_rs and run under a real WASM host
    Then it prints the correct sum and the process exits cleanly, not hanging

  Scenario: the same large-scale benchmark loop matches every other execution path under WASM too
    Given the same benchmark loop used for the engine's own speed comparison, at N=800000
    When it is compiled via emit_program_rs and run under a real WASM host
    Then it prints the exact value every other execution path already agreed on
