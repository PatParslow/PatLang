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

  A regression and a re-verification (GitHub issues #181 and #174). This
  feature's own check script had been failing every scenario since Phase 19,
  unnoticed: Phase 19 made `main`'s initialization call `bm_heap_init`
  unconditionally, which the WASM path (`emit_program_rs`, no heap chunk) does
  not have, so EVERY WASM program failed at startup on a function it never
  used. It went unnoticed because the check is a standalone script that
  nothing runs -- it is now part of the pre-commit gate recorded in the plan.
  The fix emits the heap initialization only for a program that contains a
  Box instruction.

  Fixing that exposed the real remaining WASM gap, measured rather than
  guessed by building every native fixture for `wasm32-wasip1`: the
  hand-emitted `Global*`/`Handler*` walks and the `Emit` and `apply()`
  dispatch chains call `x64_runtime.patlang`'s own `rt_list_len`,
  `rt_list_get`, `rt_list_push` and `rt_str_eq`, and `Fact`/`Query`/
  `TypeOf`/`ReadFile`/`WriteFile` call runtime-defined functions; none exist
  under the Rust-source backend. When the translator targets that backend
  (`print_op` = `"CallHost"`) a single rewrite pass at the end of flattening
  retargets each to its ordinary host equivalent (`CallHost list_len` and so
  on, `Bin "=="` for the string comparison) -- one instruction for one, so no
  jump target moves. The heap (`Box*`) and fibers are native-only BY DESIGN
  (they depend on `heap_chunk.obj` and the x64 runtime's own stack switching)
  and now fail at BUILD time naming the reason, instead of at startup or
  partway through a run.

  Each scenario below is checked as an ORDERED, adjacent sequence of printed
  values against what the native build prints for the same fixture.

  Scenario: Global and Handler operations run correctly under WASM
    Given programs that set a global read several blocks later, and register two handler names to two values
    When they are compiled via emit_program_rs and run under a real WASM host
    Then they print exactly what the native build prints

  Scenario: Emit's event dispatch runs correctly under WASM
    Given a program with two handlers on one event, a handler that sets a global, and statements after each emit
    When it is compiled via emit_program_rs and run under a real WASM host
    Then handlers fire in declaration order, the emitter sees the handler's global, and control returns

  Scenario: call-with-return, including apply() with arguments, runs correctly under WASM
    Given programs calling a function as a value, threading globals through a call, returning from a loop-exit block, and using apply
    When they are compiled via emit_program_rs and run under a real WASM host
    Then they print exactly what the native build prints

  Scenario: fact, query, type_of, read_file and write_file run correctly under WASM
    Given a program using all five, given access to the working directory by the WASM host
    When it is compiled via emit_program_rs and run under a real WASM host
    Then it prints exactly what the native build prints

  Scenario: Box and FiberYield programs are rejected at build time under WASM, naming why
    Given a program using Box operations and a program using fiber_yield
    When each is translated for the WASM backend
    Then each fails while translating with a message naming the missing native heap or the x64 runtime's stack switching, and no .wasm is produced

  Scenario: closures run under WASM through the same runtime dispatch (issue #183)
    Given the closure programs of closures.feature, built for wasm32-wasip1
    When each runs under wasmtime
    Then the output is the same sequence of values as pat --ir-run prints for the identical source

  Scenario: budgeted blocks fail at build time under WASM, naming why (issue #176)
    Given a program using budgeted(ms) { ... }
    When it is built for wasm32-wasip1
    Then translation is rejected, naming the missing fiber host functions, and no .wasm is produced
