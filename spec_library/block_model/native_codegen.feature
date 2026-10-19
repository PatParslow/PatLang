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
    When bm_nc_local_dominates_all_terminals (native_codegen.patlang) is
      asked whether this local's own creation point dominates every
      terminal in the function
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
