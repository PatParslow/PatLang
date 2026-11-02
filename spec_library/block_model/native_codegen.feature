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

  GitHub issue #215: every call site above, pure or not, paid the SAME
  cost -- the callee's return value arrives wrapped in a heap-allocated
  `[value, final_globals]` list, unpacked at the call site via two
  separate `rt_list_get` calls, because Fork B's globals-threading is
  unconditional (docs/plans/block-ownership-model.md 6, Fork B). Measured
  directly comparing this against the pre-cutover lowerer: ~9x slower on
  both recursive and flat function-call-heavy code, with a pure loop (no
  calls at all) showing no difference -- confirming the call-with-return
  wrapper itself, not something else, as the cost.

  Fix: a function that never reads or writes `__globals`, directly or
  through anything it calls (checked transitively, to a fixed point, over
  the real call graph -- `bm_nc_compute_pure_fns`), skips the wrapper
  entirely at BOTH ends of the call it's reached by: the callee's own
  compiled FuncIR drops the trailing `__globals` parameter and returns its
  value bare (no `BuildList`), and the call site drops the `Load
  __globals` push `bm_lower_declared_call` always emits and the two
  `rt_list_get` unpack calls, using the bare return value directly. A
  function reached through `CallDynamic`, `apply`, `fiber_new`, or
  `budgeted_run` -- where the actual callee is a runtime value, not a
  compile-time name -- is conservatively never classified pure, since
  nothing here can rule out what it might call. This is purely a native
  x64 codegen decision: the canonical `BlockProgramIR` shape, `lower.
  patlang`'s own output, and `interp.patlang`'s execution are completely
  unchanged -- Fork B's actual guarantee (every block's own `__globals`
  before and after it runs stays observably correct) still holds for
  every function, impure functions are untouched, and only a fast-path
  choice about machine code generation changes for provably pure ones.

  Scenario: a function that never touches globals, directly or transitively, skips the globals wrapper entirely
    Given a program with a pure function, a pure recursive function, an impure function, and a function that calls the impure one without touching globals itself
    When it is built and run as a real, fully native executable
    Then every function's output is exactly what the interpreter produces, AND the generated assembly shows the globals-unpack sequence only for the genuinely impure call sites, not the pure ones

  Scenario: Pure functions skip the globals wrapper in a program with closures and events
    Given self_hosting/block_model/spec_fixtures/native_call_pure_with_closures.patlang,
      whose pure functions are called from top-level code, from closure
      bodies, from an event handler and through apply
    When it is built and run natively
    Then it prints 8 16 120 18 22 10, as the interpreter does
    And every call to double in the generated asm pops one argument and
      no __globals. A closure call is a CallDynamic, whose dispatcher
      already calls a pure target bare; the closure entry helpers call
      apply and are impure; handlers are named "__on_..." and are not
      roots. So closures and events no longer switch the analysis off for
      the whole program.

  Scenario: The ownership pass's dominator tree agrees with walking the block
    Given every block of the native interpreter's source
      (self_hosting/block_model/pati_main.patlang) after bm_lower_program
    When self_hosting/block_model/tools/dom_tree_check.patlang asks, for
      pairs of stores, exits and entry, whether one dominates the other
    Then bm_fam_dominates (a dominator tree built once per block, each
      answer O(1)) agrees with bm_nc_raw_block_index_dominates (a walk of
      the block per question) on every pair, and no block needs the
      walk as a fallback. The walk made a native build of the
      interpreter take hours once the ownership pass ran on programs
      with closures.

  Scenario: set_var releases the fresh value it is given
    Given self_hosting/block_model/spec_fixtures/native_set_var_releases.patlang,
      which stores a fresh list, then a fresh string, under one key 2000
      times
    When it is built and run natively
    Then the heap grows by under 8 bytes per store and the last values
      read back. set_var keeps its own reference (rt_ns_set), so the
      caller releases the fresh argument after the call, as for a pure
      call (bm_nc_runtime_borrows_args). Each store used to stay on the
      heap.

  Scenario: Joining a string with a number releases the number's text
    Given self_hosting/block_model/spec_fixtures/native_concat_releases_text.patlang,
      which joins strings with ints, a float, bools, lists, a rational
      and Unit
    When it is built and run natively
    Then each result is the interpreter's, and 2000 rounds of `"v" + i`
      and `i + "w"` grow the heap by under 8 bytes each. The text "+"
      made for the non-string operand used to be kept (24 bytes a call).

  Scenario: Budgeted blocks run natively
    Given self_hosting/block_model/spec_fixtures/native_budgeted_runs.patlang,
      with a budgeted block that finishes inside its budget, a zero-budget
      block resumed from its handle until done, and a top-level block that
      writes to an object
    When it is built and run natively
    Then it prints what the interpreter prints: "done", 10, 10, 5 pauses,
      and "done 4 6". The native runtime had no bm_budgeted_run, so any
      program using budgeted() failed to build; it now runs the body on a
      fiber through budgeted_run, entered by name via bm_budget_invoke.

  Scenario: A class with only fields gives natively built objects its defaults
    Given self_hosting/block_model/spec_fixtures/class_field_defaults_reference.patlang,
      with a fields-only class (int, string, bool, list and float
      defaults) and a class with a method
    When it is built and run natively
    Then each field reads back its default: 50, x, true, [1, 2], 1.5, 51
      and 4, as under the interpreter. A fields-only class was never
      registered with class_def, so every field read 0.

  Scenario: A native program recurses as deep as the interpreter allows
    Given self_hosting/block_model/spec_fixtures/native_deep_recursion.patlang,
      an impure function recursing 100000 calls deep, not as a tail call
    When it is built natively with the compiler's own linker
    Then it prints 300000, as the interpreter does. Native executables
      reserved a 1 MB stack where the interpreter runs on 256 MB, so this
      died with a stack overflow (0xC00000FD), and so did the native
      compiler compiling itself.

  Scenario: Loops at the top level and in a handler release the values they rebind
    Given self_hosting/block_model/spec_fixtures/native_main_and_handler_loops_release.patlang,
      whose top-level while loop and `when tick` handler loop each rebind
      a local to a fresh nested list every iteration
    When it is built and run natively
    Then the output is the interpreter's, and neither loop grows the heap
      by 8 bytes or more an iteration. main and handlers only had the
      single-block ownership pass, so a loop in either kept every value
      it rebound (184 bytes an iteration for `[[name, true]]`); they now
      get the block-family pass functions get.

  Scenario: a pure function's internal __globals forwarding, and its entry seed, are both dropped -- single-block or multi-block (issue #216, follow-up to #215)
    Given a pure, branch-free function (one block) called many times in a
      loop
    When it is built and run as a real, fully native executable, reading
      the real heap's own bump-pointer high-water mark before and after
      the loop
    Then the heap shows exactly zero growth across every call -- not
      merely less growth than before. The #215 fix's own entry seed
      ([BuildList, 0] + a Store, meant only to give an internal JumpBlock
      something to forward for a multi-block pure root) was being emitted
      unconditionally for EVERY pure function, including single-block
      ones where nothing could ever reference it: a real, unreclaimed
      rt_heap_alloc(64) on every call, found while re-verifying
      docs/plans/general-refcounting.md's own foundational assumption
      that the refcounted heap's existing "many alloc+drop cycles stay
      flat" guarantee (refcounted_heap_native_check.patlang) still held.
      A MULTI-block pure function (one with its own if/while) paid this
      cost too -- BOM's own universal "every block forwards __globals"
      convention (Fork B) threads it between a pure root's OWN internal
      blocks unconditionally, regardless of purity -- closed by making
      every internal JumpBlock within a pure root's own closure drop
      "__globals" from its forwarded params and pop the single Load that
      fed it (lower.patlang always emits exactly one such Load
      immediately before any JumpBlock/Call, the same invariant the
      external Call-site fix already relies on). With that in place the
      entry seed became unconditionally unnecessary for any pure root,
      not just single-block ones, and refcounted_heap_native_check.
      patlang's own "100000 cycles stay flat" scenario -- regressed by
      #215, exercising exactly this multi-block shape via bm_alloc/
      bm_freelist_pop/bm_rc_dec -- now passes again.

  Scenario: bm_heap_init runs before main's own entry seed, so the free-list table genuinely lands first (docs/plans/general-refcounting.md, Phase 1)
    Given a program that uses box_new (so bm_nc_program_uses_heap is true)
    When it is built and run as a real, fully native executable
    Then a direct check of the free-list table's own magic marker at the
      heap's base address reports true -- the table landed at the heap's
      genuine first allocation. bm_heap_init() used to run AFTER main's
      own [BuildList, 0] "__globals" seed (unconditionally the very first
      thing any program's main does), so heap.patlang's own lock-free
      fast path (bm_heap_fixed_ready, "is the table the first allocation,
      so every thread finds it with no lookup at all") could never be
      true for a real program with any other startup code -- confirmed
      directly: even a single `print("x")` already shows a 64-byte heap
      bump before its own first statement runs. Every bm_alloc/
      bm_rc_inc/bm_rc_dec call then fell through to the slow,
      lock-plus-"__vars"-lookup path instead, measured at roughly 700x
      slower per alloc+drop cycle. Calling bm_heap_init() first, before
      the seed, fixes this for any program that uses Box at all -- scaling
      checked directly (500k/1M/2M box_set/box_get cycles: 32ms/37ms/49ms,
      linear, not the earlier pathological per-call cost).

  Scenario: box_new/box_get/box_set now work through the ordinary --x64 CLI, not just block-model's own test tooling (docs/plans/general-refcounting.md, Phase 1)
    Given an ordinary program (built directly with ./patc1.exe, not via
      block-model's own build_native.patlang/build_and_run_native.sh
      tooling) that calls box_new/box_get/box_set in a loop
    When it is compiled via the plain --x64 CLI flag
    Then it links and runs successfully, giving the correct answer --
      before this fix it failed outright with "LINK ERROR: undefined
      symbol 'bm_heap_init'", since heap.patlang's own functions were
      never linked into an ordinary --x64 build at all, only into
      block-model's own separate heap_chunk.obj. Folding heap.patlang's
      source into build_x64_runtime.patlang's own compile (so bm_alloc/
      bm_rc_*/bm_heap_init become part of x64_runtime.obj, already
      linked into every program) fixes this for free, with zero change
      to either file's own content -- interp.patlang's own
      `include "heap.patlang"` (the interpreter's path, source-level
      inclusion, not link-time resolution) keeps working completely
      unchanged. block-model's own heap_chunk.obj third-chunk linking
      (build_native.patlang/build_and_run_native.sh) is now redundant
      and was simplified away.

  Scenario: a string built via a known producer, stored once and never returned, in a branch-free function, gets its refcount decremented and genuinely reclaimed (docs/plans/general-refcounting.md, Phase 2, first increment)
    Given a branch-free function (one block, no internal Jump/
      JumpIfFalse at all) that calls one of the 8 known string-
      producing functions (rt_str_concat/sb_str/chr/substr/sc_char/
      rt_unit_to_str/rt_int_to_str/rt_limb9_to_str/rt_dquote_str),
      stores the result in a local that is never reassigned, never
      returned, and never closure-captured, and returns something else
      entirely
    When it is built directly with ./patc1.exe (the ordinary --x64 CLI,
      not block-model's own build_native.patlang -- that test harness
      has a separate, pre-existing gap calling an external runtime
      function by name from block-model source directly, unrelated to
      this feature, found and worked around rather than fixed here) and
      called 50000 times in a loop, reading the real heap's own bump-
      pointer high-water mark before and after (after one warm-up call,
      the same warm-up discipline refcounted_heap_native_check.patlang's
      own "100000 cycles" scenario already established -- the first
      allocation of a never-before-seen size is a genuine one-time cost,
      not growth from the cycles themselves)
    Then the heap shows exactly zero growth across every cycle -- not
      merely less growth than before rt_string_new existed (which alone
      only avoids unnecessary allocation, proven earlier in this same
      plan; it does not, by itself, reclaim anything without an actual
      decrement). bm_nc_insert_string_rc_decs (native_codegen.patlang)
      finds the eligible local and inserts a single rt_string_rc_dec
      call immediately before the function's own one reachable
      terminal -- unambiguous because a branch-free closure is
      guaranteed to have exactly one such terminal (bm_nc_flatten_
      blocks's own tail-fallback Return, appended unconditionally after
      every root, is provably unreachable dead code in this specific
      shape). A branching function (an if/else with its own early
      return, needing the decrement duplicated at each exit point) is
      deliberately out of scope for this increment.

  Scenario: a merging if/else (no early return) still has exactly one reachable terminal, so its own eligible local gets decremented too (docs/plans/general-refcounting.md, Phase 2, second increment)
    Given a function with internal Jump/JumpIfFalse (a merging if/else
      that conditionally recomputes an unrelated local, never
      re-touching the one holding a known-producer string) built and
      called 50000 times through the ordinary --x64 CLI, alternating
      which branch runs each cycle, reading the real heap's own bump-
      pointer high-water mark before and after (after one warm-up call)
    When bm_nc_closure_has_unambiguous_single_terminal (native_codegen
      .patlang) is asked whether this closure is eligible
    Then it says yes -- generalized from an earlier, stricter version of
      this check (which required ZERO internal Jump/JumpIfFalse at all,
      rejecting this common, safe shape outright) to instead verify
      directly that every jump TARGET lands strictly before the
      function's own first ReturnValue, not merely that no jumps exist.
      A merging if/else's own jump targets always land before its one
      shared return (confirmed directly: targets of 12, return at index
      14); a genuine early return's own jump targets always land at or
      past its first return instead (confirmed directly: targets of 10,
      first return at index 8), correctly keeping that harder case
      excluded without being lumped in by a looser check. The heap
      shows exactly zero growth across every cycle, both branches
      genuinely exercised.

  Scenario: a genuine early return still gets a decrement at every terminal it dominates (docs/plans/general-refcounting.md, Phase 2, third increment)
    Given a function that creates a string via a known producer
      UNCONDITIONALLY, before any branching at all, then has a genuine
      early return (an if branch that itself returns, leaving a
      DIFFERENT, later return reachable for the other branch) -- called
      50000 times through the ordinary --x64 CLI, alternating which
      branch runs each cycle
    When bm_nc_insert_string_rc_decs (native_codegen.patlang) is asked
      whether this local's own creation point dominates every terminal
      in the function
    Then it says yes -- the string's own Store instruction sits before
      every Return/ReturnValue in the function (real or dead-tail), and
      nothing jumps over it from earlier in the stream, so nothing can
      ever reach ANY exit without having created it first. A decrement
      gets inserted before EACH of the function's own terminals, not
      just one. Generalized from this plan's own second increment,
      which only handled a function with exactly one reachable exit --
      a genuine early return (a DIFFERENT, real shape, not the same
      thing as a merging if/else that happens to have two Jump targets)
      was previously left untouched entirely, a missed but safe
      opportunity, not a bug. The heap shows exactly zero growth across
      every cycle.
      A real bug was found and fixed building this, not just designed
      around: an early version of the rewrite inserted decrements at
      each terminal without adjusting EXISTING Jump/JumpIfFalse targets
      for the shift this caused, so a jump whose target landed at or
      after an earlier insertion point would land in the wrong place --
      confirmed directly by a real measurement (nonzero heap growth
      where the whole point of this pass is exactly zero), since the
      interpreted IR dump used to design this pass only ever displays
      the instruction list and never executes a jump, so it could not
      have caught this. Fixed with a proper two-pass rewrite
      (bm_nc_cumulative_shift_at) that corrects every existing jump
      target before returning the rewritten instruction list.

  Scenario: a local returned at one terminal and discarded at another, in the same function, is handled correctly at each (docs/plans/general-refcounting.md, Phase 2, third increment)
    Given a function that creates a string, returns IT directly on one
      path (ownership transfers to the caller there) but discards it on
      the other (returns something else entirely) -- called 50 times
      through the ordinary --x64 CLI, alternating which path runs each
      cycle, repeatedly reusing the SAME freed block via the free list
    When bm_nc_insert_string_rc_decs (native_codegen.patlang) decides,
      AT EACH terminal independently, whether this local is the value
      actually being returned right there (a Load of that same name
      immediately before that specific Return/ReturnValue)
    Then no decrement is inserted at the terminal where it IS being
      returned, but a decrement IS inserted at the terminal where it
      is NOT -- a local can dominate every terminal in a function yet
      only actually be returned at one of them. Verified against pat
      --ir-run on the identical source, not merely "did not crash": the
      native output matches the interpreted output's own first 50 lines
      exactly, proving the repeatedly-reused block's own content is
      never corrupted by a premature or missing decrement on either
      path.

  Scenario: main's own top-level code gets the same string-decrement pass as ordinary callee functions (docs/plans/general-refcounting.md, Phase 2, fourth increment)
    Given a short program (single-block top-level code, no loop) that
      builds and discards three strings via known producers directly at
      the top level, not inside any declared function, built through
      the ordinary --x64 CLI
    When bm_nc_closure_is_single_block is asked whether main's own
      closure (main_blocks) is eligible, the same gate ordinary callee
      functions already use
    Then bm_nc_insert_string_rc_decs runs on main's own flattened
      instructions too, and the output matches pat --ir-run exactly.
      Unlike every earlier increment's own fixture, this one proves
      correctness through output comparison rather than a heap-growth
      measurement: main only ever runs once per process, so there is no
      LATER allocation within the same run that could show a freed
      block being reused -- the only thing actually at risk for main's
      own case is something being freed too early and corrupting a
      later read, which wrong printed output would reveal directly.
    And handler functions (bm_nc_build_handler_funcirs) get the same
      pass under the same single-block gate, for the same reason.

  Scenario: a local passed as an argument to another call, well before its own decrement, is still handled correctly (docs/plans/general-refcounting.md, Phase 2, verified not just assumed)
    Given a function that creates a string, passes it to print() (an
      ordinary external call, ordinary argument-passing) well before
      the function's own terminal, then returns something else entirely
      -- called 20 times through the ordinary --x64 CLI, alternating
      which character gets built each cycle
    When bm_nc_insert_string_rc_decs (native_codegen.patlang) decides
      eligibility
    Then nothing about being used as a call argument disqualifies the
      local at all -- this pass only ever special-cases the single
      instruction immediately before a terminal (is it the value being
      returned there), never anything else a local gets used for, so
      this was never a gap needing new code, only an explicit proof it
      already worked rather than an assumption from the absence of a
      disqualifying check. If the decrement were happening too early
      (before print's own use), the printed character would be
      corrupted; too late, and the heap would grow. Checked both ways
      in the same run: the printed sequence matches exactly, and the
      real heap shows exactly zero growth after warm-up.

  Scenario: a string built and discarded inside a real while loop is decremented at the loop's own back-edge but not its exit (docs/plans/general-refcounting.md, Phase 2, loop increment)
    Given a while loop (always modeled as a multi-block closure in this
      project's own architecture -- a head block, here combined with
      the body, connected to itself via a back-edge JumpBlock and to an
      exit block via another) that builds a string fresh each iteration
      via a known producer, uses it for nothing, and never forwards it
      -- called through the ordinary --x64 CLI for 50000 real
      iterations
    When bm_nc_raw_block_index_dominates (native_codegen.patlang) is
      asked, independently, whether the string's own creation point
      dominates the back-edge exit and whether it dominates the
      loop-exit exit
    Then it says yes for the back-edge (reached only by running the
      loop body, which always creates the string first) and no for the
      loop-exit (reached directly by the condition's own JumpIfFalse,
      which skips the body -- and the string's own creation -- entirely
      when the loop is about to end). A decrement is inserted before the
      back-edge but not the loop-exit -- checking dominance against
      EVERY exit uniformly, the way the single-block passes do, would
      reject this candidate outright, since it can never dominate the
      loop-exit path by construction; checking each exit independently
      is what makes this the single biggest real-world case this whole
      plan has targeted (strings built and discarded inside a loop)
      actually work. The real heap shows exactly zero growth across all
      50000 iterations.
      Found and fixed building this, not designed around in advance: a
      pre-existing, previously low-impact gap (issue #219 -- block-
      model's own build_native.patlang test harness never called bm_
      patc_resolve_runtime_calls the way the ordinary CLI's own bm_
      patc_lower does) became a REAL failure the moment this increment
      started inserting genuine rt_string_rc_dec calls into existing
      block-model fixtures (tailapp, issue #180) -- fixed directly
      rather than worked around again, since it was now blocking real
      test infrastructure, not just a hypothetical gap.

  Scenario: the single-block pass is retrofitted to per-terminal dominance, closing a gap the loop increment's own fix already closed for the raw pass (docs/plans/general-refcounting.md, single-block dominance retrofit)
    Given a function that takes an early return in one branch and creates
      a string, via a known producer, ONLY on the other (fall-through)
      branch -- called through the ordinary --x64 CLI for 50000 cycles,
      alternating which branch runs each call, warmed up once through the
      fall-through path so the string's own free-list size class is
      already primed before the real measurement starts
    When bm_nc_flat_index_dominates (native_codegen.patlang) is asked,
      independently, whether the string's own creation point dominates
      the early-return terminal and whether it dominates the fall-through
      function's own terminal
    Then it says no for the early-return terminal (unreachable by
      construction -- that path never creates the string at all, so there
      is nothing to decrement there either way) and yes for the other
      (nothing reaches it without already having taken the fall-through
      path, which always creates the string first). A decrement is
      inserted at the terminal it dominates, closing a gap the pass's own
      earlier, uniform "dominates EVERY terminal" check left open: that
      check saw the early-return terminal sitting at or before the
      string's own Store and rejected the candidate OUTRIGHT, from every
      terminal, including the one it actually dominates -- the string
      leaked on every fall-through call (confirmed directly: 600000 bytes
      over 50000 calls before this fix). Generalized from the raw/loop
      pass's own bm_nc_raw_block_index_dominates and bm_nc_raw_reaches_
      avoiding (this plan's loop increment, just above) to the flat
      (string-op) level the single-block pass itself runs at --
      bm_nc_flat_reaches_avoiding treats "Return" (flat emission's own
      void/halt terminal, with no raw-level counterpart) as a dead end
      alongside "ReturnValue", the one difference from the raw version's
      own op set. The real heap shows exactly zero growth across all
      50000 cycles.
      A fixture-level mistake was found and fixed building this, kept
      distinct from the code fix itself: the first version of this
      scenario's own fixture warmed up through the EARLY-RETURN path
      (never creating the string at all), leaving the free-list size
      class unprimed and showing a small constant growth (24 bytes, two
      cold allocations) rather than zero -- not a dominance bug, the same
      "warm up through the path actually being measured" requirement
      native_string_rc_dec_early_return.patlang's own warm-up call
      already follows, re-confirmed by fixing the fixture alone (no code
      change) and re-running to zero.

  Scenario: a local reassigned from two separate string-producer calls is decremented at the reassignment point AND at the terminal (docs/plans/general-refcounting.md, reassigned-locals increment)
    Given a function that reassigns the same local twice -- `let s = chr(n);
      ...; let s = chr(n + 1)` -- and never returns or otherwise uses
      either value -- called through the ordinary --x64 CLI for 50000
      cycles, warmed up once first
    When bm_nc_reassignable_eligible_names is asked whether this local
      qualifies for the decrement passes
    Then it says yes, because every Store of this local is immediately
      preceded by a string-producer call and the textually-first Store
      dominates the second one -- generalized from the earlier version of
      this check, which required EXACTLY one Store and rejected any
      reassigned local outright, leaking BOTH values (the overwritten
      first one, never decremented, and the still-live final one, also
      never decremented since the whole local was excluded from the pass).
      bm_nc_insert_reassignment_decs inserts a decrement of the OLD value
      immediately before the producer call that computes the new one
      (confirmed directly: inserting it AFTER that call instead, between
      the call and its own Store, broke the producer-call-immediately-
      followed-by-Store adjacency the terminal pass's own eligibility
      re-check depends on, and silently dropped the local from that pass
      entirely -- caught by re-measuring heap growth, not by re-reading
      the IR shape, since it showed half the expected reduction rather
      than zero). bm_nc_insert_string_rc_decs then decrements the final
      (second) value at the terminal, using the local's FIRST store as
      the creation point for the per-terminal dominance check -- still
      correct with more than one Store, since the first store already
      dominates every later one by construction, so it also dominates
      anything a later store does. The real heap shows exactly zero
      growth across all 50000 cycles (48 bytes leaked per call before
      this fix: 24 for the overwritten first value, 24 for the discarded
      final one).

  Scenario: a local whose value escapes into a list literal is never freed while the list itself is still live (docs/plans/general-refcounting.md, list/dict-element-storage safety gate)
    Given a function that builds a string via a known producer, wraps it
      in a one-element list literal, and returns the LIST -- never the
      string itself directly -- called through the ordinary --x64 CLI
      2000 times, each result kept alive in an outer list, followed by
      2000 more unrelated string allocations to create real allocation
      pressure against any wrongly-freed block
    When this local's own value is stored into the list literal
    Then it is NOT freed out from under the container still holding it
      (a REAL, confirmed memory-corruption bug found scoping this plan's
      "list/dict-element storage" item, not a missing optimization: the
      local dominates the function's own terminal -- the LIST is the
      value actually returned there, not the local itself -- so an
      earlier version of this pass decremented the local anyway, freeing
      the string while the list still held the exact same pointer.
      Confirmed directly: 1923 of 2000 kept-alive lists came back with
      silently corrupted string content under allocation pressure before
      the original fix (a blanket exclusion from the decrement pass,
      GitHub #221); zero after). Phase 4c (general-refcounting.md)
      replaced that blanket exclusion with the real mechanism it was
      standing in for: bm_nc_insert_list_element_incs (native_codegen.
      patlang) inserts an explicit increment at the exact point this
      local's value is stored into the list, giving it a genuine SECOND
      owner -- so the local's own decrement now correctly fires again
      (no longer excluded) and only brings the refcount from 2 down to
      1, leaving the list's own eventual cascade (rt_list_buf_rc_dec,
      x64_runtime.patlang) as the one reference that actually frees it.
      The value is still never wrongly freed early; it is also no longer
      bumped forever the way the original exclusion left it.

  Scenario: list nodes and buffers are genuinely refcounted and reclaimed (docs/plans/general-refcounting.md, Phase 3a foundation)
    Given self_hosting/lib/x64_runtime.patlang's persistent-list implementation
      (rt_list_new/rt_list_node_new/rt_list_push/rt_list_set_functional/
      rt_list_materialize), previously allocating its node and buffer via
      plain rt_heap_alloc and never freeing either
    When node and buffer become two separately bm_alloc'd, genuinely
      refcounted blocks (rt_list_node_rc_inc/dec, rt_list_buf_rc_inc/dec,
      reusing block_model/heap.patlang's own generic allocator Phase 1/2
      already built and proved for strings) -- a retired node's own
      `next` field becomes a real, counted reference to its successor
      (rt_list_materialize will later walk it forward, so the successor
      must outlive it), and a retired node releases its own buffer
      reference at retire time rather than waiting for its own eventual
      death, since no read path ever consults a retired node's buffer
      field again
    Then explicit rt_list_node_rc_inc/dec calls (no compiler pass decides
      when to decrement a list LOCAL yet -- that is Phase 3b, separate,
      not yet started; the bare-literal shape, native_list_rc_basic, is
      now a top-level loop rebinding a local, which main's ownership pass
      releases itself) show the heap's own high-water mark staying flat
      across 50000 build-and-release cycles, in three shapes: a bare
      BuildList literal, a chain of list_push calls each retiring the
      previous node (both the in-place-growth and buffer-doubling
      paths), and a genuinely shared node forced through
      rt_list_materialize, whose stale reference still reads back
      correctly after the live one is mutated. A plain-integer list is
      used deliberately throughout -- this phase reclaims the list's OWN
      node/buffer only, never cascades into string/list ELEMENTS stored
      inside it (that is Phase 3c, separate, not yet started), so a
      string element would leak independently and mask whether the list
      itself was genuinely reclaimed.
      A real regression was found and fixed verifying this (not merely
      discovered and left): x64_buildlist_asm (codegen_x64.patlang, the
      raw-asm emission for every list LITERAL, including a closure's own
      captured-values list) used to allocate its node and buffer as ONE
      combined rt_heap_alloc block, incompatible with this scheme once
      list_push/list_set treat them as independently bm_alloc'd, size-
      keyed blocks -- changed to two separate `call bm_alloc` allocations
      instead. That fix itself then broke thread_safety_check.sh (every
      run hung before its own first print): a test fixture's `include
      "heap.patlang"` -- always redundant once heap.patlang's functions
      are auto-bundled via x64_runtime.obj, confirmed directly by
      removing it with no other change -- created a duplicate/shadowed
      `bm_alloc` symbol that collided specifically with x64_buildlist_
      asm's own hand-written `call bm_alloc`, a collision shape patc1_
      main.patlang's own name-collision check does not currently catch.
      Fixed by removing that fixture's own redundant include. Verified
      after both fixes: native_codegen_check.sh, refcounted_heap_native_
      check.sh, thread_safety_check.sh, and the full language spec gate
      all remain green.

  Scenario: a list local is automatically decremented when discarded or reassigned, the same way a string local already was (docs/plans/general-refcounting.md, Phase 4b)
    Given the single-block dominance pass (bm_nc_reassignable_eligible_
      names / bm_nc_insert_string_rc_decs / bm_nc_insert_reassignment_
      decs, native_codegen.patlang), previously recognizing only a
      string-producer call as a value worth automatically decrementing
    When BuildList, and CallHost calls to list_push/list_set, are ALSO
      recognized as producers (bm_nc_is_list_producer_call) -- a local
      whose every Store is producer-preceded by the SAME kind (all
      string, or all list; a local that could hold either depending on
      path is excluded outright, since deciding which decrement
      function applies would need a runtime type check this pass does
      not do) is eligible the same way a string local already was, and
      the right decrement call (rt_string_rc_dec or the new rt_list_rc_
      dec, x64_runtime.patlang) is chosen per name from its own first
      store's producer
    Then a list built via a literal, stored in a local, never returned
      or passed into another BuildList/list_push/list_set call, is
      decremented at its own function's terminal; a list_push RESULT
      stored in a local and discarded the same way is decremented too;
      and a local reassigned between two list literals is decremented
      both at the reassignment point (job 1) and at the terminal
      (job 2) -- 50000 cycles each, exactly zero heap growth, confirmed
      directly (104 bytes leaked per call before this pass recognized
      list producers at all).
      A real regression was found and fixed verifying this: Phase 3a's
      own native_list_rc_retire_chain.patlang fixture manually called
      rt_list_node_rc_dec on two locals (`d` in build_and_discard, `c`
      in sharing_cycle) that neither escape into a further list_push/
      list_set/BuildList call nor are closure-captured -- both became
      genuinely eligible for THIS pass the moment it landed, and the
      fixture's own manual decrement collided with the compiler's new
      automatic one, segfaulting from a real double-decrement. Fixed by
      removing those two now-redundant manual calls, relying on this
      pass instead; the fixture's OTHER locals (`a`/`b` in build_and_
      discard, `a` in sharing_cycle) stay manually managed, since each
      is used as list_push's own base argument at least once, which
      this pass's escape check still conservatively excludes.

  Scenario: a buffer's own death cascades into the String/List elements it holds (docs/plans/general-refcounting.md, Phase 4c)
    Given rt_list_buf_rc_dec (x64_runtime.patlang), previously freeing a
      buffer without ever looking at what it held -- the actual "list/
      dict-element storage" feature Phase 2's own header named and
      deferred, not yet built even after Phase 3a/4b made the list's
      own node/buffer genuinely refcounted
    When a buffer's own refcount reaches zero, every element within
      its node's real LENGTH (not the buffer's own allocated capacity,
      which a doubling growth can genuinely exceed -- see the next
      scenario) that is itself a String or List is now decremented too
      (rt_rc_dec_if_refcounted)
    Then a function building a one-element list wrapping an unnamed,
      freshly built string (chr(...) fed directly into the list
      literal) and discarding the whole list, called 50000 times,
      causes exactly zero heap growth. Two real, confirmed bugs were
      found and fixed getting here, each caught by the SAME heap-growth
      measurement showing a nonzero number instead of silently passing:
      (1) the cascade's own per-call scratch copy (needed to read every
      element before releasing the buffer -- a concurrent thread could
      otherwise pop and overwrite a freed block mid-read) was itself
      allocated via the heap's plain bump allocator (rt_heap_alloc, no
      free at all) instead of the real, reclaimable one (bm_alloc/bm_
      rc_dec) -- leaked a fixed `len * 8` bytes on every single cascade,
      independent of the refcount bookkeeping around it.
      (2) once a String's tagged value could be reached by this
      cascade, it became possible for the first time to reach a string
      LITERAL this way (`["a", "b"]`, not a chr()-built string) -- a
      literal's tagged pointer has the identical tag bits as a real,
      bm_alloc'd string but points at a static .data label with NO
      refcount header at all (codegen_x64.patlang's own x64_collect_
      string_data), so decrementing it corrupts whatever static data
      happens to sit there instead. Fixed in the two generic
      dispatchers (rt_rc_inc_if_refcounted/rt_rc_dec_if_refcounted),
      reusing the SAME [heap_base, heap_base + used) bound codegen_x64.
      patlang's own type_of/numeric_kind payload check already
      established for this exact literal-vs-heap distinction (GitHub
      #57/#89) -- confirmed directly: x64_list_equality.patlang's own
      first comparison (two structurally identical lists of string
      literals) started returning false instead of true the moment
      element-level cascading landed, and true again once this fix did.

  Scenario: a named local stored into TWO separate lists gets a real, compiler-inserted increment at each site, not just an exclusion (docs/plans/general-refcounting.md, Phase 4c)
    Given bm_nc_insert_list_element_incs (native_codegen.patlang), a new
      compiler pass walking each BuildList/list_push/list_set
      instruction's own operands (via bm_nc_flat_skip_value_backward,
      which skips a whole compound sub-expression as one value, not
      just one instruction, so a multi-instruction operand can't be
      mistaken for a bare Load) -- for any operand that is exactly a
      bare Load of a name bm_nc_reassignable_eligible_names already
      considers independently decrement-eligible, it inserts a real
      rt_rc_inc_if_refcounted call immediately before that Load
    When bm_nc_flat_list_escaped_names (GitHub #221's own original
      exclusion -- never decrement a local that escapes into a list at
      all) is removed entirely, now that a real increment balances the
      local's own decrement instead of needing to dodge it
    Then a local stored into ONE list needs its own decrement to drop
      the refcount from 2 to 1, not 0 (native_string_rc_dec_list_escape.
      patlang, updated for this); a local stored into TWO separate
      lists needs its own refcount at 3 (one creation plus two
      compiler-inserted increments) against the three releases that
      actually fire (the local's own decrement, plus each list's own
      cascade) -- confirmed directly: a function sharing one named,
      chr()-built local into two one-element lists, reading both back
      and discarding everything, called 50000 times, causes exactly
      zero heap growth and zero mismatched reads (no early free from
      under-counting, no double-free from over-releasing).

  Scenario: reading a list element into a named local gives it a real, compiler-inserted increment, not just a borrow (docs/plans/general-refcounting.md, Phase 4d)
    Given list_get (the host call `a[i]`/`s[i]` indexing lowers to)
      returns a BORROW from the container by default -- a value whose
      type cannot be known statically (an int, most of the time, in
      many real programs), unlike chr()/concat() (always String) or
      BuildList/list_push/list_set (always List)
    When list_get is registered as a THIRD producer kind, "dynamic"
      (bm_nc_producer_kind, bm_nc_is_dynamic_producer_call,
      native_codegen.patlang), whose own decrement function is the
      generic runtime dispatcher rt_rc_dec_if_refcounted (x64_runtime.
      patlang -- it already checks the value's own tag at runtime and
      no-ops on anything that isn't a String or List), and a new
      compiler pass, bm_nc_insert_list_get_result_incs, inserts a real
      rt_rc_inc_if_refcounted immediately AFTER the Store whenever
      list_get's own result is stored into a name this now makes
      independently decrement-eligible -- after, not before, unlike the
      write-side pass: list_get's result isn't a named Load yet at the
      point it is produced, it IS the value about to be stored for the
      first time
    Then a function building a one-element list, reading that element
      into a named local, comparing it against a second, transient
      (never stored) read of the same element, and discarding both the
      list and the local at its own terminal, called 50000 times, shows
      zero mismatched comparisons (no corruption from either read) and
      exactly zero heap growth (the string's refcount is correctly
      balanced at 2 -- its own creation plus the read-side increment --
      against the two releases that actually fire: the list's own
      cascade, Phase 4c, and the local's own decrement, now enabled by
      this new producer kind). The transient second read never touches
      the refcount at all, since nothing ever stores it anywhere
      independently tracked.

  Scenario: returning a list's own element while the list itself also dies at the same terminal does not free it out from under the return (docs/plans/general-refcounting.md, Phase 4d)
    Given a function that builds a list, reads ONE element out into a
      named local, and returns THAT LOCAL -- never the list itself, so
      the list's own terminal decrement still fires (Phase 4b),
      cascading into its buffer (Phase 4c) and decrementing the very
      same string the local is about to return
    When this is checked BEFORE Phase 4d's own read-side increment
      exists
    Then the fixture SEGFAULTS, confirmed directly via git-stash back
      to the Phase 4c baseline, not merely prints a wrong value -- the
      list's own cascade decrement (which runs before the final Load
      of the returned local, the same ordering the terminal pass
      already uses to exclude the returned value from its OWN
      decrement) frees the string while it is still about to be handed
      back to the caller: a real, confirmed use-after-free, not a
      missed-reclamation optimization. After Phase 4d's own increment
      lands, the SAME fixture (2000 calls, each kept-alive result
      checked against 2000 more unrelated allocations made afterward
      for real allocation pressure) shows zero corrupted elements.

  Scenario: a borrowed name stored into a new list element and into an object field survives that field being overwritten (GitHub #223)
    Given a helper that pushes [name, 7] onto an object's "syms" list
      where name is the helper's own PARAMETER, and a caller that builds
      name via substr, calls the helper, then sends "set" to store the
      same name into the object's "cur" field
    And the next name's own "set" displaces the previous one from "cur"
    When it is run for 2000 distinct names as a real, fully native
      executable, with an unrelated string allocation after each
    Then every "syms" entry still holds its own original name

  Scenario: object_delete frees the object's fields and table, and send releases its arguments
    Given a function that creates a named object, sends "set" with a
      freshly built string, pushes 20 freshly built strings onto a list
      field, sets a number field, reads the string back, and deletes the
      object
    When it runs 2000 times as a real, fully native executable
    Then the heap grows by under 64 bytes a cycle
    And the string read back before the delete is intact ("label_2000")

  Scenario: string builders and vecs are values the compiler releases
    Given a function that grows a string builder past several doublings,
      reads it part-way and pushes a number, and pushes freshly built
      strings to a vec, sets, extends and snapshots it with vec_to_list
      before changing it again
    When it runs 2000 times as a real, fully native executable
    Then its results are the interpreter's ("[230, 231, [a_7, b_7],
      [c_7, b_7, d, e_7], 4, e_7]"), the snapshot keeps the contents it
      had when taken, and the heap grows by under 64 bytes a run

  Scenario: an interned string is released like any other string
    Given a function that interns a freshly built string and reads it with
      sc_len, sc_code, sc_char and sc_substr
    When it runs 2000 times as a real, fully native executable
    Then its results are the interpreter's ("[13, 116, o, 123]") and the
      heap grows by under 64 bytes a run

  Scenario: object fields and set_var keys are found by hash, and the table owns its keys
    Given 3000 objects with two fields each and 500 set_var keys, all
      named by strings built in a loop
    When every field and key is read back, every other object is deleted
      and recreated with new values, and a list field is pushed to 100
      times, as a real, fully native executable
    Then every read returns what was stored ("bad= 0 items= 100 last= 99")
    And reading one field 20000 times with 3000 objects alive costs under
      3x what it costs with 30
    And the interpreter prints the identical result

  Scenario: a new list element owns its own reference wherever it is stored
    Given a function containing a loop that stores its PARAMETER name into
      a list literal pushed onto an object field
    And a loop body that stores a substr-made local into a list literal
      pushed onto an object field, the local going out of scope at the end
      of the loop body
    And a loop-free function that stores its PARAMETER name via list_push
      into a list kept in an object field
    And each caller's own name is then released by a field the next
      name's "set" displaces
    When it is run for 2000 names per case as a real, fully native
      executable, with an unrelated string allocation after each
    Then every stored element still holds its own original name, in all
      three cases
    And the interpreter prints the identical result

  Scenario: apply with a runtime name and arguments dispatches natively
    Given a program using apply with two, one-statement and zero arguments
    When it is built and run as a real, fully native executable
    Then every applied function runs and returns exactly what the interpreter's own run does

  Scenario: closures dispatch natively, capturing, returning, passing and nesting exactly as the interpreter does (issue #183)
    Given the closure programs of closures.feature, whose closure values are called through apply's runtime dispatch
    When each is built and run as a real, fully native executable
    Then the native output is the same sequence of values as pat --ir-run prints for the identical source

  Scenario: a function defined twice by a diamond include builds natively with the first definition winning (issue #180)
    Given a function defined twice, byte for byte, with an early return inside a loop
    When it is built and run as a real, fully native executable
    Then it builds and prints 3 then 2, as it does when the function is defined once

  Scenario: a function that tail-calls one declared earlier starts in its own body (issue #180)
    Given a function whose whole body is `return app(l, v)` where `app` is declared before it
    When it is built and run as a real, fully native executable
    Then it prints [A], [B] and [x, C], not values built from stale stack contents

  Scenario: two sequential top-level while loops both run to completion and the program ends (issue #180)
    Given two sibling while loops at the top level, each printing its own values, followed by one more print
    When it is built and run as a real, fully native executable
    Then it prints both loops' values once each and the final print, not an infinite repeat of the second loop

  Scenario: bitwise Bin operators compile natively (issue #180)
    Given band, bor, bxor, shl and shr on plain ints
    When it is built and run as a real, fully native executable
    Then it prints 8, 14, 6, 48 and 6, matching the interpreter

  Scenario: a closure call's generated code does not grow with the number of functions in the program
    Given a function that calls its closure parameter twice, in a program padded with 20 and then 80 unrelated functions
    When both programs are translated to native FuncIR
    Then that function has the same instruction count in both, under 200
    And closure calls with one and two arguments, unit-padded extra parameters, captures and continuation-passing recursion still print the interpreter's values

  Scenario: a function's own returned list or string is not freed by its own return (GitHub #228)
    Given single-block functions that return a string and a list they produced, in a program with closures (so returns are packed as [value, globals])
    When 2000 results are kept while unrelated allocations follow each call
    Then every kept result reads back intact

  Scenario: a reassigned list's old value is released only after its new value exists (GitHub #228)
    Given a single-block function doing `let out = list_push(out, [..., f(...)])`, in a program with closures
    When it is called 500 times, each followed by unrelated allocations
    Then all 2000 pushed elements read back intact, rather than the old list being freed while list_push still needs it

  Scenario: sqrt, float division and float comparison follow the numeric tower natively (GitHub #229, #211)
    Given sqrt of perfect-square Ints and Rationals, of 2 and of 2.25, across function calls, float division of a parameter, a rational times a float, and comparisons of a sqrt result
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints: exact Int/Rational roots for perfect squares, Floats otherwise, and correct comparisons

  Scenario: Rationals, floats in lists, string + float and float/int comparisons behave natively as interpreted (GitHub #229)
    Given 1 + -(1/2) computed in a function, a float literal stored in a list and read back, "d=" + a float, and comparisons of a boxed sqrt result with ints, a float literal and other parameters
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints

  Scenario: Rationals keep exact parts of any size natively, promoting to BigInt (GitHub #229)
    Given rational arithmetic whose numerators and denominators pass 2^63 (a product of large exact fractions, 1/3 squared six times)
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints, rather than wrapped 64-bit parts

  Scenario: A list displays each element the way print shows it alone
    Given a list holding an int, a rational, a float, a BigInt, a complex, a string, a bool and a nested list
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints, rather than the rational/complex parts as BigInt digits

  Scenario: A variable assigned both a raw float and a dynamically computed value keeps its value natively
    Given v = 0.0 then v = v * t + c[k] (Horner's scheme) with t and c passed in, and a parameter rescaled by a float
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints

  Scenario: A float mixed with the result of integer arithmetic keeps the exact value's meaning natively
    Given 0.1 - (1/10), a Rational local times cos(0.0), a loop counter times 0.7, a BigInt product and a BigInt-sized literal times 0.5, and that BigInt divided by 3 and by 0.5
    When the program is built and run as a real, fully native executable
    Then it prints exactly what pat --ir-run prints, rather than reading the Rational or BigInt pointer as an int

  Scenario: An element returned from a local list survives the list's release at return
    Given a function returning `ns[f]` from its own local list of lists, with a closure present so callees use the packed return
    When the caller builds a new list from the returned element's values and reads it through several more calls, 900 times
    Then the element is still the list it was and every read matches pat --ir-run, rather than reading the element the list's cascade freed

  Scenario: A call to a declared function ahead of a later local of the same name calls the function
    Given a function that calls `world()` and later in its body declares `let world = ...`
    When the program is built and run as a real, fully native executable
    Then `world()` calls the declared function, printing what pat --ir-run prints, rather than calling through the unassigned local

  Scenario: A local ahead of a call in a returned list literal keeps its reference as an element
    Given a program with closures, and a function returning `[g, count(g)]` where `g` is a local list
    When the program is built and run as a real, fully native executable
    Then `g` survives the function's release of its locals as the returned list's element, printing what pat --ir-run prints

  Scenario: An element read from a list and stored in a new list survives the old list's release
    Given a list built as `[c[0], c[2], 9]` and via `list_push(ys, c[1])` from a list `c` held in a vec
    When the old list is released (vec_set over it) and the program is built and run as a real, fully native executable
    Then the new lists' elements are intact, printing what pat --ir-run prints

  Scenario: A list copied from one local into another survives the original's release
    Given `let out = placed` where `placed` holds a fresh list, in a straight-line function and in a loop body
    When the program is built and run as a real, fully native executable
    Then returning `out` gives the list intact, printing what pat --ir-run prints

  Scenario: A non-integral float prints as its shortest round-trip decimal
    Given non-integral floats needing 1 to 17 significant digits, from 2^-1074 up to 1e15 in magnitude
    When they are printed, and concatenated into text, by a real, fully native executable
    Then each prints the shortest digits that read back as the same double, in plain notation, exactly as pat --ir-run prints them

  Scenario: A user function whose name contains rt_ or mem_ still uses tagged numeric dispatch
    Given user functions named sort_numbers and check_mem_ok that compare, add and multiply ints, rationals and floats
    When the program is built and run as a real, fully native executable
    Then the results are numeric, printing what pat --ir-run prints, rather than raw-word operations on tagged values

  Scenario: An integer literal combined with a local float keeps its value
    Given `1 - v`, `2 * v` and `(1 - v) * (h - 1)` with v a local float, at top level and inside a function
    When the program is built and run as a real, fully native executable
    Then each result is the arithmetic pat --ir-run prints, rather than the literal's float bits converted again as an integer

  Scenario: A Float index truncates to an Int
    Given vec_get, vec_set and list indexing with an index that is a Float, such as floor() of a float
    When the program is built and run as a real, fully native executable
    Then the element at the truncated index is used, as pat --ir-run does, rather than the boxed Float's tagged word

  Scenario: An outer loop counter times a float inside an inner loop
    Given `i * 2.5` with i an outer loop's counter, evaluated inside an inner loop, at top level and inside a function
    When the program is built and run as a real, fully native executable
    Then the products are what pat --ir-run prints, rather than i's integer bits read as a double

  Scenario: argv() reads quoted, escaped and empty arguments as interpreted
    Given arguments holding embedded double quotes, backslashes, spaces and an empty string
    When the program is built and run as a real, fully native executable with them
    Then argv() returns each argument intact, as pat --ir-run does, rather than splitting at every quote mark

  Scenario: exec_capture passes quoted, escaped and empty arguments intact
    Given a native child that prints its argv
    When a native build passes it arguments holding quotes, backslashes, spaces and an empty string through exec_capture
    Then the child prints each one back intact, as when the parent is interpreted

  Scenario: A boxed Float allocated high in the heap is still a Float
    Given a heap grown past 0x150000000, then floor() and a bitwise op on a boxed Float allocated there
    When the program is built and run as a real, fully native executable
    Then both read it as the Float it is, as pat --ir-run does, rather than as an int whose tag test reads a null box

  Scenario: BigInts, rationals with BigInt parts and complex numbers are released
    Given loops whose numbers live on the heap: a total past 2^47, BigInt division and remainder, a rational whose parts are BigInts, and a complex product, each value replacing the last
    When the program is built and run as a real, fully native executable
    Then every result is the interpreter's and no loop grows the heap: a BigInt, Complex or Interval is a counted block, and a Rational, Complex or Interval releases its parts with it

  Scenario: rebuilding an older version of a list leaves nothing behind
    Given a list kept alive while newer versions of it are made with list_set
    When its elements are set and read back 3000 times as a real, fully native executable
    Then every result is the interpreter's and the heap does not grow: the scratch chain of versions used to rebuild the older one is freed

  Scenario: the runtime's remaining raw blocks are released
    Given loops that write a file from a byte list, grow a bool array, build an object holding strings, and run exec_capture_io
    When the program is built and run as a real, fully native executable
    Then every result is right and no loop grows the heap: the byte buffer and the argument array are freed after use, and bool arrays and objects are counted blocks

  Scenario: a freed block of any size is reused
    Given a string grown a character at a time, each version replacing the last
    When it is built to 4000 characters as a real, fully native executable
    Then the heap grows by a few times the final string's size: every freed block goes to the free list of its size class, whatever its size

  Scenario: the runtime's own temporaries are released
    Given a loop that shows lists as text with `+` and through a string builder, formats a rational, and a loop that runs exec_capture
    When the program is built and run as a real, fully native executable
    Then every result is the interpreter's and neither loop grows the heap: the runtime, compiled with the ownership passes, releases the display strings, command lines and argument arrays it made

  Scenario: parallel_map workers each have their own vecs and string builders
    Given parallel_map workers that each build a vec and a string builder at the same time
    When the program is built and run as a real, fully native executable
    Then every worker's results are intact and each worker's vec is a distinct value of type vec, as pat --ir-run gives them

  Scenario: parallel_map workers read globals set before the call
    Given a global set with set_global before parallel_map
    When the program is built and run as a real, fully native executable and the workers read it with get_global
    Then each worker sees its value, as pat --ir-run does, rather than false

  Scenario: A string read from a vec or __vars slot survives the slot being overwritten
    Given a string read with vec_get or get, then its slot overwritten and the heap reused
    When the program is built and run as a real, fully native executable
    Then the string is still what it was, as pat --ir-run prints it, rather than freed under the local that holds it

  Scenario: Native math functions round as the interpreter's do
    Given sin and cos of pi/4
    When the program is built and run as a real, fully native executable
    Then they print what pat --ir-run prints, rather than msvcrt's sin one ulp low

  Scenario: A local carried round a loop gives up the values it supersedes
    Given a function building a 100000-element list with list_push in a loop, and one reassigning a list literal each time round
    When the program is built and run as a real, fully native executable
    Then the heap grows by what the final values need, not by every superseded value

  Scenario: A loop's list returned in a literal from its exit block comes back whole
    Given a loop pushing list literals, with an early return, that returns [list, count] after it
    When the program is built and run as a real, fully native executable
    Then the list is what pat --ir-run prints, rather than freed under the caller

  Scenario: Rows built by list_push in a loop survive being pushed onto an accumulator
    Given a pure function whose inner loop builds a fresh row by list_push and whose outer loop pushes each row onto a result
    When the program is built and run as a real, fully native executable
    Then both transposes print what pat --ir-run prints, rather than freed rows or a build failure

  Scenario: A pure function returning a borrowed element through an inlined tail call hands its caller a reference
    Given a pure wrapper whose inlined tail call returns an element of its argument after a branch, with a local released at that exit
    When it is called in a loop that keeps allocating, built and run as a real, fully native executable
    Then every element read back is the pattern's own, as pat --ir-run prints, rather than released by the caller

  Scenario: A pure function's returned list literal owns its elements
    Given a pure function returning a list literal of its own parameters, called in a loop whose caller releases each result
    When the program is built and run as a real, fully native executable
    Then the caller's own lists are intact, as pat --ir-run prints, rather than released with the returned list

  Scenario: A value read out of a loop-released container keeps its own reference
    Given a loop that pops a pair with a pure function and reads the rest of the stack out of that pair
    When the program is built and run as a real, fully native executable
    Then the stack is reversed as pat --ir-run prints, rather than read from the pair after its release

  Scenario: A fresh value passed straight into a pure call is released when the call returns
    Given a loop passing a pure call's result and a list literal straight into pure calls
    When the program is built and run as a real, fully native executable
    Then the sum is right and the heap grows by under 8 bytes an iteration, rather than keeping every argument

  Scenario: Reading a file in slices keeps the heap flat
    Given a loop reading 1000-byte slices of a file with read_file_bytes
    When the program is built and run as a real, fully native executable
    Then each slice is right and the heap grows by under 16 bytes a read, rather than keeping every buffer and slice

  Scenario: An impure call's result, its pair, and the fresh values it is given are all released
    Given impure functions (they read a global) returning a fresh list, their parameter, and a list_set of a fresh list, called in a loop with results kept, discarded and reassigned
    When the program is built and run as a real, fully native executable
    Then the values are what pat --ir-run prints and the heap grows by under 8 bytes an iteration

  Scenario: list_set storing the value already there still hands its caller a reference
    Given a nested list_set whose outer call stores the value already in place, with the inner result a released temporary
    When the program is built and run as a real, fully native executable
    Then the frame is intact, as pat --ir-run prints, rather than freed with the temporary

  Scenario: Reassigning a local to the same list still releases the old reference
    Given a function reassigning a local to list_set of the value already in place, called in a loop
    When the program is built and run as a real, fully native executable
    Then the sum is right and the heap grows by under 8 bytes an iteration

  Scenario: A fresh value stored in one branch of a loop body is released
    Given a loop whose if/elif branches each store a fresh result in a local of their own
    When the program is built and run as a real, fully native executable
    Then the sum is right and the heap grows by under 8 bytes an iteration

  Scenario: Floats in released lists and arithmetic are freed
    Given lists of floats built and dropped in a loop, and floats passed between functions and accumulated
    When the program is built and run as a real, fully native executable
    Then the sum is right and the heap grows by under 16 bytes an iteration, rather than keeping every float box

  Scenario: Rationals in released lists and arithmetic are freed
    Given multivectors of exact rationals built, scaled and dropped in a loop
    When the program is built and run as a real, fully native executable
    Then the sums are exact and the heap grows by under 16 bytes an iteration, rather than keeping every rational

  Scenario: A tail call's fresh arguments are released by the callee
    Given functions ending in `return f(g(), h())`, `return f(g(), v)` with v a fresh local, and `return f(keep, g())` with keep a parameter, called in a loop
    When the program is built and run as a real, fully native executable
    Then the values are what pat --ir-run prints and the heap grows by under 8 bytes an iteration, rather than keeping every argument

  Scenario: A local copied into another is released by both
    Given a function computing float products into locals and copying them into others (`let lo = p1`, then reassigned in branches), and one copying a list local, called in a loop
    When the program is built and run as a real, fully native executable
    Then the sum is what pat --ir-run prints and the heap grows by under 8 bytes an iteration, rather than keeping every product

  Scenario: Every runtime string producer returns a counted string
    Given strings from read_file, indexing a string, getenv, cwd and exec_capture, each also stored in lists and released 3000 times
    When the program is built and run as a real, fully native executable
    Then each string starts with a reference count of exactly 1 and the releases complete without a count going below zero, rather than retains and releases overwriting the block before an uncounted string

  Scenario: Every operator gives the same result natively
    Given every binary operator the parser produces (+ - * / % == != < <= > >= band bor bxor shl shr) and every unary one (- not bnot), applied to function parameters
    When the program is built and run as a real, fully native executable
    Then each result is what pat --ir-run prints, and the operator names come from block_ir.patlang's one table

  Scenario: A function in a program with closures releases what it makes
    Given a loop slicing a string into one-character pieces, in a program that also contains an unrelated closure literal, called 2000 times
    When the program is built and run as a real, fully native executable
    Then the count is what pat --ir-run prints and the heap does not grow, rather than every function of a program with any closure keeping what it makes

  Scenario: pati runs every operator
    Given the same program
    When it is run by pati, the native interpreter (self_hosting/block_model/pati_main.patlang built with patc1 --x64)
    Then each result is what pat --ir-run prints, rather than the bitwise operators stopping with "unknown Bin op hash"
