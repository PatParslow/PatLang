Feature: real native codegen for the block-model IR (Block Ownership Model, Fork A, Phase 9)

  Phase 9 (docs/plans/block-ownership-model-implementation-plan.md): the
  native half of Fork A's "front to back" -- self_hosting/block_model/
  native_codegen.patlang translates a BlockProgramIR into a single, real,
  flat FuncIR (blocks concatenated, JumpBlock expanded into ordinary
  Store instructions plus a real Jump), then reuses self_hosting/lib/
  codegen_x64.patlang's own, already-proven emit_program_x64 for
  everything else -- no new x64 emission code, no interpretation of the
  block-model IR at runtime at all. A real two-chunk build (mirroring
  self_hosting/build_x64_runtime.patlang's own established convention),
  linking against the already-built self_hosting/build/x64_runtime.obj,
  not a single bundled-source chunk (tried first, abandoned after
  codegen_x64.patlang's own hardcoded runtime-call asm text for
  overflow-checked arithmetic made textual renaming unsafe).

  A real bug was found and fixed building this, not just designed
  around in advance: JumpBlock expands into MULTIPLE instructions (a
  Store per forwarded value, plus a Jump), so a JumpIfFalse/Jump target
  computed against the original, one-JumpBlock-is-one-instruction
  numbering does not equal its own position in the expanded output --
  a loop's own JumpIfFalse landed mid-way through its own back edge's
  Store sequence instead of at the exit block's own, producing a
  genuine infinite loop. Fixed with a per-block index map from original
  instruction position to its own expanded position.

  Scenario: a loop-free, two-block program runs correctly through real native codegen
    Given a program that jumps from one block to another, forwarding two values
    When it is built and run as a real, fully native executable
    Then it prints the correct result

  Scenario: a small loop runs correctly and terminates
    Given a loop of a known, small iteration count
    When it is built and run as a real, fully native executable
    Then it prints the correct sum and the process exits cleanly, not hanging

  Scenario: the same loop shape at a much larger scale still matches the interpreted result
    Given the same benchmark loop used for the engine's own speed comparison, at N=800000
    When it is built and run as a real, fully native executable
    Then it prints the exact value every other execution path (interpreted, bi_run-compiled) already agreed on

  Scenario: block-to-block control flow compiles to real jumps, never calls
    Given the assembly emitted for the small loop above
    When the instructions between block labels are inspected directly
    Then every transfer of control between blocks is an ordinary jmp, with no call/ret introducing a call stack that was never there in the design

  Scenario: fact/query/type_of/read_file/write_file compile through real native codegen (Phase 19)
    Given a program using fact, query, type_of, write_file, and read_file
    When it is built and run as a real, fully native executable
    Then each one produces the exact same result the interpreter already gives

  Scenario: a failing require aborts through real native codegen, exiting with a nonzero code (Phase 19)
    Given a program whose require fails
    When it is built and run as a real, fully native executable
    Then it aborts with the same guaranteed-fail message the interpreter gives, and a nonzero exit code

  A real, project-wide bug was found and fixed while proving this, not
  designed around in advance: without `-Wl,--disable-dynamicbase`,
  Windows can relocate a linked image away from the fixed 0x140000000
  base `x64_family_code_asm`'s own classification logic hardcodes
  (needed to distinguish a string literal's `.data` address from a
  plain int) -- confirmed via a hand-instrumented raw address dump
  showing the actual runtime address far outside
  [0x140000000, 0x150000000), silently misclassifying every string
  constant as "other"/"int" and corrupting `print()`'s own dispatch for
  it. Fixed in `self_hosting/lib/x64_build.patlang` (every linker call
  site) and `self_hosting/block_model/tools/build_and_run_native.sh` --
  not block-model-specific, affects any native build linking more than
  one object file where the OS happens to relocate it.

  `fiber_yield` compiles but segfaults when called with no active fiber
  context established (no prior `fiber_new`/`fiber_resume`) -- a real,
  separate, deliberately out-of-scope finding for this pass, not
  silently papered over: a bare native smoke test with no fiber
  machinery around it isn't a valid usage pattern for it, matching the
  scoping this whole feature's Phase 19 slice already commits to.

  Scenario: Global*/Handler* compile through real native codegen, as hand-emitted assoc-list loops (Phase 19)
    Given a program using set_global/get_global across a jump chain, and a handler with two names registered
    When each is built and run as a real, fully native executable
    Then both produce the exact same result the interpreter already gives

  A real, previously-undiscovered bug in this same new code was found
  and fixed proving the scenario above, not designed around in advance:
  `rt_list_push(l, v)` (list argument first, value second) had its two
  arguments pushed in the WRONG order in three call sites inside the
  hand-emitted `HandlerRegister`/`GlobalSet` loop -- corrupting the
  handler's own backing list via `rt_list_push`'s own address/length
  read against the wrong operand, which surfaced as a genuine, real
  segfault the moment the loop actually ran with at least one entry to
  examine, not as a subtly wrong result. Found via systematically
  narrowing a minimal repro (a single `handler_register` followed by
  one `handler_lookup`), not by inspection alone.

  Scenario: Box* compiles through real native codegen, linked against a third heap_chunk.obj chunk
    Given a program that mutates a Box in a straight line (patched to BoxSetUnchecked by the flight check) and a second Box that is shared before being mutated (falling back to checked BoxSet)
    When it is built and run as a real, fully native executable, linked against self_hosting/build/{x64_runtime,heap_chunk}.obj
    Then the straight-line chain ends at the last value written, and the shared Box keeps its original value while the mutated one gets the new value -- real copy-on-write, not aliasing

  A real bug was found and fixed proving this scenario, not designed
  around in advance: `heap.patlang`'s own free-list table
  (`bm_freelist_table_addr`'s backing `"__vars"` entry) is populated by
  `bm_heap_init`, which interp.patlang's own `bm_ensure_heap_ready` calls
  lazily, once, before the first BoxNew -- the native path had no
  equivalent call at all, so the first `bm_alloc` walked
  `bm_freelist_pop -> bm_freelist_slot_offset -> bm_freelist_table_addr`
  through an uninitialized table address, segfaulting immediately.
  Confirmed via a real segfault (exit 139) running this exact fixture,
  not predicted from reading the code. Fixed by calling `bm_heap_init()`
  unconditionally at native program start (`bm_to_real_funcir`'s own
  `init_instrs`, alongside the existing entry-block `__globals` init) --
  eager rather than lazily flag-gated like the interpreter, since a
  native program has exactly one start (unlike `bi_run`'s shared
  interpreter process, reset per call), and cheap even when a program
  never touches a Box at all.

  Box is native-x64-only (heap.patlang's own `rt_heap_alloc`/
  `mem_peek_qword`/`mem_poke_qword` calls are not host functions under
  `pat --ir-run` at all -- confirmed directly, matching lower.patlang's
  own established finding for Phase 1/3), so this scenario cannot be
  cross-checked against a plain interpreter run. It is instead
  cross-checked against `bi_run` (interp.patlang's own bytecode
  interpreter for this exact block-model IR) compiled to native code via
  `./patc1.exe ... --x64` -- two independent code paths over the
  identical program, both genuinely native, agreeing on the same output.

  Scenario: Emit compiles through real native codegen, each handler as its own separate FuncIR
    Given a program with two handlers registered for the same event, and a handler whose own set_global must be visible in the emitting block right after emit() returns
    When it is built and run as a real, fully native executable
    Then both handlers fire in declaration order, the emitting block sees the handler's own global write immediately, emit() genuinely returns control (the statement after it still runs), and the enclosing function still returns to its own caller afterward

  Unlike every other Phase 19 opcode, this needed real new architecture,
  not just a dispatch case: by the time Emit runs, every handler
  registered anywhere in the program is compiled as its own real,
  separate FuncIR (not inlined, and not merged into the single flat
  "main" the way ordinary function/loop blocks always were), so Emit
  itself only ever needs an ordinary native Call -- no new call-with-
  return mechanism, no MakeClosure/CallValue, and no restriction to
  compile-time-literal event names (an event name computed at runtime
  works exactly like a literal, since both are just a string value
  compared with `rt_str_eq` at the dispatch site). `bm_to_real_funcir`
  now returns a LIST of FuncIRs (previously always exactly one) --
  `main`, partitioned to exclude every block owned by some handler, plus
  one FuncIR per handler root. A handler's own family (its root plus
  every synthesized descendant it can reach, e.g. a loop head/exit) is
  found via a real reachability closure over `JumpBlock` edges, proven
  correct rather than assumed: a synthesized block's name is always a
  fresh, globally-unique value referenced from nowhere except the one
  body that created it, so a handler's own closure can never
  accidentally pull in a block belonging to `main` or to a different
  handler. Each handler FuncIR ends by loading and returning its own
  final `__globals` -- exactly the value `interp.patlang`'s own Emit
  case already reads back out of a handler's "halt" outcome once it
  naturally finishes.

  Cross-checked against `pat --ir-run` running the SAME source through
  `bm_lower_program`/`bi_run` directly (unlike Box*, Emit/Global* need no
  native-only primitive, so this simpler cross-check is valid here) --
  both agree exactly: `100`, `200`, `42`, `2`, `3`.

  Scenario: BuildList and generic CallHost (Phase 18's own new opcodes) compile through real native codegen
    Given a program that builds a List literal via a bracket expression, calls list_len on it, and indexes into it
    When it is built and run as a real, fully native executable
    Then it produces the correct length and the correct indexed value

  Both translate as direct passthroughs to codegen_x64.patlang's own
  already-real `BuildList`/`CallHost` instructions -- no new native
  emission logic needed. `BuildList` always works (it has no allowlist
  restriction); `CallHost` for an ARBITRARY name is not guaranteed to
  (codegen_x64.patlang enforces its own "OS-boundary allowlist" for
  CallHost targets), so this scenario only confirms two names
  (`list_len`, `list_get`) that happen to fall inside it -- not a claim
  that every host function Phase 18's own interpreter-side
  `interp_call_host` fallback covers also compiles natively.

  Native call-with-return (GitHub issue #173), the native half of Phase 21
  and of `apply` with arguments (#153): `Call`, `ReturnValue` and
  `CallDynamic` used to be rejected cleanly by `bm_nc_unsupported`, so a
  program that called a declared function as a value, returned a computed
  value, or used `apply()` could not be built natively at all.

  Design, generalizing what `Emit` already does for a handler: every
  function that is the target of a `Call` gets its OWN separate native
  FuncIR (named `bm_fn_<name>`), holding that function's whole
  `JumpBlock`-reachable family of blocks, reached by an ordinary native
  `Call`. It returns a two-element list `[value, final_globals]`, which the
  call site unpacks (the value stays on the stack; the globals go back into
  the caller's own `__globals`, so Fork B's threading survives a real call
  boundary). Inside a callee every block ends with an explicit halt
  returning `[unit, its own final __globals]`, and `ReturnValue` returns
  `[value, its own __globals]` -- a block running off its own end is a halt
  in the interpreter, never a fall-through into whichever block happens to
  follow in the flattened array. `CallDynamic` dispatches on the runtime
  name with a chain of `rt_str_eq` comparisons, one per declared function
  taking at least the supplied number of arguments, like `Emit`'s event
  dispatch; a name that matches nothing reaches a guaranteed contract
  failure.

  One consequence had to be fixed for this to build at all: `main` used to
  hold every block not owned by a handler, harmless while every function was
  reached by `JumpBlock` (whose stores bind the callee's parameters), but a
  function reached ONLY by a `Call` has its parameters bound at no site
  inside `main`, so `codegen_x64.patlang`'s undefined-variable check
  correctly rejected `main`'s dead copy of it. `main` now holds exactly the
  blocks reachable from the entry by `JumpBlock` -- its own family, the same
  closure notion a handler or a call target gets.

  Each scenario is cross-checked against `pat --ir-run` running the same
  source, and checked as an ORDERED, adjacent sequence of printed values, not
  a substring.

  Scenario: a declared function called as a value, including recursion, runs through real native codegen
    Given a program calling double(5) + 1 and a recursive factorial
    When it is built and run as a real, fully native executable
    Then it prints 11 and then 120

  Scenario: a callee's final globals come back through the native Call and become the caller's
    Given a callee that changes a global and returns a value, called from a function that then reads the global
    When it is built and run as a real, fully native executable
    Then it prints the returned value and then the updated global

  Scenario: a callee whose return runs in a synthesized loop-exit block returns that block's own state
    Given a callee containing a while loop and a return after it
    When it is built and run as a real, fully native executable
    Then the loop's result comes back and the caller continues

  Scenario: apply with a runtime name and arguments dispatches natively
    Given a program using apply with two, one-statement and zero arguments
    When it is built and run as a real, fully native executable
    Then every applied function runs and returns exactly what the interpreter's own run does
