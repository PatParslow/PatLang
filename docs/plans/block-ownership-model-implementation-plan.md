# Block Ownership Model: implementation plan

Companion to [`block-ownership-model.md`](block-ownership-model.md) (the design
document, Forks A–E). That document decided *what*; this one decides *how to
build it incrementally*, based on four architecture calls made on 2026-09-22:

1. **First checkpoint:** Fork D (refcounting on the native heap), built and
   proven standalone before anything touches blocks or jumps.
2. **Self-hosted first:** every new piece is written in PatLang under
   `self_hosting/`, matching [[feedback_patlang_is_canon]] — no Rust
   prototype to port later.
3. **Fully parallel:** a new `self_hosting/block_model/` tree. Nothing in
   `self_hosting/lib/{lower,codegen_x64,x64_runtime,interp}.patlang` is
   edited until the new path is proven — matching the design doc's own scope
   note ("a fresh, separate execution path").
4. **Gate:** each phase's checkpoint is a real Gherkin `.feature` file run
   through the existing `self_hosting/lib/test.patlang` runner (the same
   machinery `run_language_spec_suite.patlang` uses), not an ad hoc
   selftest. New features live under `spec_library/block_model/`, run by a
   new `self_hosting/block_model/run_block_model_spec_suite.patlang` —
   deliberately **not** wired into the standing `spec_library/language/`
   gate, since this path changes nothing about current language semantics
   until/unless it's merged.

**Branch:** `feature/block-ownership-model`, cut from `main` before Phase 0's
first file. Nothing here lands on `main` before it is built and proven,
per the design doc's own branch-discipline note.

**Standing rule for every phase below:** RED (write the `.feature` first,
confirm it fails) → GREEN (implement, matching the scenario's actual prose,
not just whatever passes) → verify against real runtime output → report the
command run and its output. This is the project's own BDD discipline, not a
new process invented for this plan.

---

## Phase 0 — Scaffolding

**Realizes:** nothing yet — proves the harness itself works before any real
scenario depends on it.

- Cut branch `feature/block-ownership-model`.
- Create `self_hosting/block_model/` and `spec_library/block_model/`.
- Add `self_hosting/block_model/spec_steps_block_model.patlang` (empty
  `register_*_steps()` stub) and
  `self_hosting/block_model/run_block_model_spec_suite.patlang`, mirroring
  `self_hosting/tools/run_language_spec_suite.patlang`'s own structure
  (`include test.patlang`, register steps, `t_report()`).
- Add one throwaway smoke `.feature` (a single trivial `Given/When/Then`)
  to prove the runner executes and reports pass/fail correctly.

**Checkpoint:**
`rust-runtime/target/release/pat.exe --ir-run self_hosting/block_model/run_block_model_spec_suite.patlang`
reports the smoke scenario passing. Remove the smoke scenario once Phase 1
has a real one.

---

## Phase 1 — Fork D: a standalone reference-counted heap

**Realizes:** Fork D (both jobs, one field) — memory reclamation and the
mutate-in-place-vs-clone check — with zero dependency on blocks, jumps, or
`mut` syntax.

- `self_hosting/block_model/heap.patlang`: a refcounted allocator, modeled
  on (never editing) `self_hosting/lib/x64_runtime.patlang`'s existing bump
  allocator — adds a count header word, `rc_inc`/`rc_dec`/`rc_free`, and a
  `rc_get(ptr)`/`rc_touch_for_mutation(ptr)` pair that returns "in place" at
  count `1` and "clone first" otherwise.
- `self_hosting/block_model/heap_codegen.patlang`: emits the x64 for the
  above, modeled on (never editing) `codegen_x64.patlang`.
- A low-level driver, `self_hosting/block_model/x64_heap_rc_driver.patlang`,
  in the same style as the existing `self_hosting/x64_heap_driver.patlang` —
  needed because refcount behavior at this phase is a memory-layout property
  with no PatLang-syntax surface yet, so it can't be expressed as ordinary
  program source the way later phases can.
- `spec_library/block_model/refcounted_heap.feature`: scenarios expressed
  against the driver's own observable outputs (a count readout, a
  heap-bytes-used readout), not against PatLang syntax:
  - allocate → count is 1
  - copy the pointer → count is 2
  - drop one copy → count is 1
  - drop the last copy → the object's memory is returned (heap-bytes-used
    after a loop of N alloc+drop cycles stays flat, not growing with N —
    the actual proof that reclamation is real, not just that a decrement
    happened)
  - mutate at count 1 → same address, contents changed
  - mutate at count 2 → a new address, original's contents unchanged

**Checkpoint:** the feature file above passes; a bounded-memory run (e.g.
100,000 alloc+drop cycles) shows flat heap-bytes-used rather than linear
growth — the direct fix for the bump-allocator problem from §1 of the
design doc, checked, not assumed.

**Explicit non-goals for this phase:** no `mut` parameter syntax, no block
dispatch, no interaction with the *existing* native heap or `Value`
representations at all. This phase is deliberately inert with respect to
anything that runs today.

Run a short retrospective after this phase specifically — it's the
highest-risk, least-precedented piece (a new allocator + refcount codegen
from scratch), and the project's own standing practice calls for one after
any dev spike, especially the first one in a new area.

---

## Phase 2 — Fork A: a minimal block/jump execution skeleton

**Realizes:** Fork A ("turtles all the way down") at the smallest possible
scale — jump-with-a-pointer as the actual dispatch mechanism, no ownership
checks wired in yet.

- `self_hosting/block_model/block_ir.patlang`: the new IR shape — a block is
  `[params, inherited, instrs]`; a jump instruction carries the target block
  and the field values to populate its pointer.
- `self_hosting/block_model/lower.patlang`: lowers a **restricted** subset of
  today's AST (arithmetic, `if`, function calls — no `while`, no closures,
  no `new`/`send` yet) into the new block IR. Reuses the existing parser
  (`self_hosting/lib/parser.patlang`) unchanged — only lowering and
  execution are new, matching Fork A's own "front to back" scope (execution
  engine, not source syntax).
- `self_hosting/block_model/interp.patlang`: a tree-walking/block-walking
  interpreter for the new IR (self-hosted first — no native codegen for the
  block engine itself yet; that's Phase 9).
- `spec_library/block_model/block_dispatch.feature`: scenarios against small
  restricted-subset programs — two blocks joined by one jump, values arrive
  correctly, no block sees a value it wasn't explicitly handed.

**Checkpoint:** a program using two or more jumped-between blocks produces
the correct output on the new interpreter, and a scenario asserting a block
*cannot* see a variable it wasn't explicitly handed (attempting to reference
it is a runtime "unbound" error, not silent access) passes — the structural
guarantee from §3.2, proven, not just designed.

---

## Phase 3 — Wire Phase 1 into Phase 2: `mut` parameters, for real

**Realizes:** §3.4 (`mut` extended to parameters) and Fork D's ownership-check
job, now actually reachable from block dispatch.

- Extend `block_ir.patlang`'s param entries with a `mut` flag (mirrors the
  existing per-local `mutables` tracking in today's `lower.patlang`, per
  §7's table — read for reference, not edited).
- Wire `heap.patlang`'s `rc_touch_for_mutation` into the interpreter's
  handling of a mutating primitive call on a `mut` parameter.
- `spec_library/block_model/mut_parameters.feature`: a block with a
  non-`mut` parameter rejects a mutating call at the violation point (the
  guaranteed-fail `contract_check`-style behavior from §3.4's original
  proposal); a `mut` parameter permits it, in place at refcount 1 and via
  clone otherwise (§3.5), observably (the caller's own copy is unaffected
  when aliased).

**Checkpoint:** both scenario families above pass on the same restricted
subset used in Phase 2 — this is the first point where the design doc's
central claim (a provable exclusivity check via refcounting) is real,
end-to-end, on however small a slice of the language.

---

## Phase 4 — Fork B: eliminate ambient state

**Realizes:** Fork B (full elimination) — globals-view threading, and the
`new`/`send` two-way split.

- Globals: teach `lower.patlang` (the block-model one) to thread a
  globals-view section through every block's pointer automatically, and
  insert it as a hidden argument at `set_var`/`get` call sites — no change
  to the PatLang source a program author writes.
- `new`/`send`, ephemeral majority: lower directly to a real refcounted
  reference (Phase 1's heap), no name, no counter.
- `new`/`send`, deliberate minority: design and build the explicit object
  handler (`handler_register`/`handler_lookup`) as ordinary PatLang, tested
  independent of the block engine.
- `spec_library/block_model/globals_elimination.feature`,
  `spec_library/block_model/object_handler.feature`.

**Checkpoint:** a restricted-subset program using `set_var`/`get` runs
identically to before, with the globals-view section demonstrably part of
the block's own pointer (inspectable in a test hook) rather than reached
ambiently; a deliberate-name scenario (register two handles under different
names in the same handler, look each back up) passes; an ephemeral-`new`
scenario shows two `new("Dict", ...)` calls with the *same* literal name
now produce independent objects (the bug class Fork B's writeup named as
closed).

---

## Phase 5 — Nested blocks: loops as back-edge blocks

**Realizes:** §4.1 — `while` bodies as blocks with their own `inherited`
section; confirms `if`/`match` stay flat (already true; this phase adds a
regression scenario, not new mechanism).

- Extend the restricted subset's lowering to include `while`.
- Loop body's own `inherited` section is populated by whatever Phase 6's
  free-variable analysis exists at this point — for this phase, wholesale
  capture is an acceptable placeholder (Fork E's own middle-ground note),
  swapped for the real analysis in Phase 6.
- `spec_library/block_model/loop_blocks.feature`: a loop reading an outer
  local not part of its own threaded accumulator sees the correct value on
  every iteration; a scratch variable declared inside the loop body does
  *not* survive to the next iteration unless explicitly threaded forward
  (§4.2's flat-namespace finding, now checked against the new engine
  instead of just read off today's `lower_block`); an `if`/`match` inside
  either a function or a loop body stays flat (no extra block boundary
  created).

**Checkpoint:** all three scenario families pass.

---

## Phase 6 — Fork E: real free-variable analysis

**Realizes:** Fork E's actual decision, replacing Phase 5's wholesale
placeholder.

- `self_hosting/block_model/free_vars.patlang`: walk a closure or loop
  body, collect free references, subtract self-bound names, recurse through
  nested closures/match arms.
- Re-point closure lowering and Phase 5's loop lowering at this pass instead
  of wholesale capture.
- `spec_library/block_model/free_variable_capture.feature`: a closure or
  loop body's `inherited` section contains only variables it actually
  references (checked by inspecting the section's own field list, not just
  behavior) — the concrete, checkable form of Fork E's "contract clarity"
  axis; a large unrelated heap value in the same enclosing scope keeps
  refcount `1` (i.e. stays uniquely owned) when the closure never touches
  it, distinguishing this from wholesale capture behaviorally, not just by
  inspection.

**Checkpoint:** both scenario families pass; a targeted before/after
comparison (Phase 5's wholesale version vs. this phase's version) on a
capture-heavy test program shows the memory-retention and exclusivity-cost
differences the design doc's Fork E table predicted, not just "it still
works."

---

## Phase 7 — Fork C: the flight check

**Realizes:** Fork C's hybrid decision — static proof wherever provable,
runtime check (already built, Phase 3) as fallback.

- `self_hosting/block_model/flight_check.patlang`: the bounded points-to/
  shape analysis (§9's explicit boundary: sized to `mut`-exclusivity, not
  general type inference).
- Wire it to run once ahead of a restricted-subset program, and again at
  every point the block-model engine dynamically compiles a fragment
  (the block-model equivalent of `run_ir`, once one exists — if Phase 2–6
  never needed a `run_ir` analog, note that explicitly rather than silently
  dropping this requirement).
- `spec_library/block_model/flight_check.feature`: a program provably safe
  statically skips the runtime check entirely (observable via a counter of
  runtime checks actually performed, before/after); a program the flight
  check can't resolve still falls back to Phase 3's runtime check rather
  than being rejected outright; a genuinely unsafe program is rejected
  before it runs at all, with a diagnostic naming the two aliasing
  references (Fork C's own named diagnostics-cost concern, checked as a
  real requirement here, not deferred).

**Checkpoint:** all three scenario families pass, including the "runtime
checks actually performed" counter dropping to near-zero on a
provably-safe test program versus Phase 3's baseline.

---

## Phase 8 — Debugger/tooling parity

**Realizes:** Fork A's one identified real gap — the jump-history trail
replacing a call-stack view.

- Extend the block-model interpreter to record a bounded jump-history trail
  in debug builds, freed via Phase 1's own refcounting (Fork D making this
  "a straightforward thing to build," per the design doc).
- Confirm `fiber_yield`-based pause/resume (unchanged, per Fork A) still
  works against the new interpreter's snapshot shape.
- `spec_library/block_model/debugger_parity.feature`: pausing mid-execution
  and querying "how did we get here" returns a real trail of the last N
  jumps, not a stale or empty one.

**Checkpoint:** the feature passes against a program that jumps through at
least 3 distinct blocks before pausing.

---

## Phase 9 — Native codegen for the block engine (deferred)

**Realizes:** the native half of Fork A's "front to back," once the
self-hosted interpreter path (Phases 1–8) has fully proven the design.

Explicitly the optional/deferred Rust-native twin in spirit (matching
[[feedback_patlang_is_canon]]) even though everything here is PatLang, not
Rust — the self-hosted interpreter is canon-first; native codegen for this
engine is a second backend to add once the design is settled, not a
requirement for declaring the model proven. Scoped in detail only once
Phase 8 is complete.

---

## What this plan deliberately does not cover

- Merging any of this into `main`, or touching
  `self_hosting/lib/{lower,codegen_x64,x64_runtime,interp}.patlang` — those
  stay untouched through every phase above, per the "fully parallel"
  decision. A separate migration plan is a later, explicit decision, not an
  automatic conclusion of Phase 9 passing.
- GitHub issue tracking for these phases — worth doing (an epic + one
  sub-issue per phase, joined to the project board per standing practice)
  but not created as part of this plan without confirming the breakdown
  above is the one to track.
- Restricted-subset coverage of every language feature — each phase only
  extends the lowering subset far enough to prove that phase's own
  scenario family; full-language coverage on the new engine is implicitly
  Phase 9+'s job, not this plan's.
