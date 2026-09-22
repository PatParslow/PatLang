# Block Ownership Model: full-language expansion plan

**Status (2026-09-22): Phase 10 (event dispatch) and Phase 11 (pattern
matching) complete and verified —
`self_hosting/block_model/run_block_model_spec_suite.patlang` reports
54/54 passing, no regressions. Phases 0–9 (the restricted-subset design,
proof, and native/WASM verification) were already complete on
`feature/block-ownership-model` — see
[`block-ownership-model-implementation-plan.md`](block-ownership-model-implementation-plan.md)
for that record, which this document continues rather than replaces.
Phases 12–20 below are not built yet.**

Companion to [`block-ownership-model.md`](block-ownership-model.md) (the
design doc, Forks A–E) and the Phase 0–9 implementation plan. Those decided
the mechanism and proved it on a deliberately restricted subset (arithmetic,
`if`, function calls, `while`, closures, globals elimination, the `new`/`send`
split, the flight check, debugger parity, native x64, and WASM). This
document plans covering the rest of the language on the same engine.

**Three architecture calls made for this round (2026-09-22):**

1. **First new phase:** event dispatch (`when`/`emit`) — picked over object
   orientation, contracts, and GOAP/logic as the cheapest real validation
   that the phase-sizing approach still works, since the design doc (§8)
   already established the `EventIR` table is close to free under this
   model.
2. **Backend cadence:** self-hosted interpreter coverage pushes across the
   *entire* remaining language first; native x64 + WASM codegen is one
   consolidated pass at the end (Phase 19), exactly mirroring how Phase 9
   was deferred until Phase 8 finished. Not per-paradigm parity.
3. **Migration scope:** this document *does* include a migration/cutover
   design (Phase 20) — deciding how, whether, and when
   `self_hosting/lib/{lower,codegen_x64,x64_runtime,interp}.patlang` would
   be retired or replaced — rather than deferring that as a separate later
   decision the way the original implementation plan explicitly did.

**Standing rules, carried forward unchanged from Phases 0–9:**

- Self-hosted first, matching [[feedback_patlang_is_canon]] — everything
  below is PatLang under `self_hosting/block_model/`, no Rust prototype.
- Fully parallel — nothing in `self_hosting/lib/{lower,codegen_x64,
  x64_runtime,interp}.patlang` is touched until Phase 20 explicitly says so.
- Gate: a real Gherkin `.feature` file under `spec_library/block_model/`,
  run through `self_hosting/block_model/run_block_model_spec_suite.patlang`,
  per phase — RED (write it, confirm it fails) → GREEN (match the scenario's
  actual prose) → verify against real runtime output → report command +
  output.
- Branch: continues on `feature/block-ownership-model`. Nothing here lands
  on `main` before it's built and proven, same branch-discipline note as
  before.

Real, already-confirmed AST node kinds this plan lowers (checked against
`rust-runtime/src/ast.rs`'s `Stmt`/`Expr` enums directly, not assumed):
`When`, `Assert`, `RuleDecl`, `GoalDecl`, `Fact`, `Query`, `ClassDecl`
(fields, methods-as-closures, traits), `Match` (with pattern guards),
`Budgeted`. Each phase below names which of these it covers.

---

## Phase 10 — Event dispatch (`when`/`emit`)

**Realizes:** design doc §8's own observation that event dispatch "already
fits this model almost for free" — `EventIR`'s `[event_name,
handler_fn_name]` table is static, baked into the compiled program's
structure, not a runtime-mutable registry. A fired event is already "jump to
a known block with a pointer carrying the event's payload," the same
mechanic loops turned out to be (§4.1).

- Extend `block_model/lower.patlang` to lower `Stmt::When { event, body,
  line }` into a registered block plus an `EventIR`-equivalent table entry
  in the block-model program shape, and `emit` (an ordinary `Call`/
  `CallHost`, confirm which in the real lowering) into a jump to the
  matching block(s) carrying the payload as the incoming pointer.
- Extend `block_model/interp.patlang` to dispatch on that table.
- `spec_library/block_model/event_dispatch.feature`: an `emit`'d payload
  reaches its handler block with exactly the fields it declared, and no
  others; multiple handlers for the same event both fire; a handler body's
  own locals don't leak back to the emitting block (the same isolation
  guarantee §3.2 already proves for ordinary jumps, checked again here
  since this is a different call site producing the jump).

**Checkpoint:** the feature above passes; this is also the first real test
of whether the Phase 0–9 restricted-subset engine generalizes cheaply the
way the design doc predicted, or whether the "almost free" claim needs
revising before the rest of this plan is trusted.

**Done (2026-09-22): the "almost free" claim did NOT hold as originally
stated, checked against real interpreter behavior before writing any
code, not assumed.** `rust-runtime/src/ir/interpreter.rs`'s own
`CallHost("emit", ...)` handling calls each registered handler via
`run_function` — a genuine call-with-return, not a jump-and-never-return —
and the real self-hosted `lower.patlang` has itself since moved `when`
from a static `EventIR` table to a runtime-registered closure
(`register_event_handler`), specifically to fix a bug where an isolated
handler couldn't see enclosing scope. Neither matches the design doc §8
framing this phase started from. The block-model engine has no call stack
at all (Fork A), so `Emit` was built as a narrowly-scoped, explicit
exception rather than either of those: a handler block runs as a bounded,
non-tail sub-execution (a recursive `bi_run_block` call, safe only because
the lowerer guarantees a handler body can never itself `JumpBlock`), and a
handler is isolated to its own two auto-bound params plus `__globals` —
not a real closure over outer scope, a v1 restriction named plainly in
`block_ir.patlang`'s own header rather than silently passed off as parity
with production `when` semantics. 5/5 scenarios pass (payload delivery,
isolation, multi-handler ordering, control genuinely returning to the
emitting block, and a handler's global write being visible immediately
afterward); full suite 43/43, no regressions. Real first-class closures
for the block model (needed for actual production-equivalent `when`) are
not built by this phase and are not currently scheduled in Phases 11–20
below — flagged here as a gap this plan doesn't yet cover, not silently
absorbed into "done."

---

## Phase 11 — Full pattern matching (`match`/`case`, with guards)

**Realizes:** extending §4.1's "forks don't need their own boundary" finding
(verified there only for `if`) to `Match`, including guard expressions and
recursive list patterns.

- Extend `block_model/lower.patlang` to lower `Stmt::Match { scrutinee,
  arms, line }` the same way `rust-runtime/src/ir/lowering.rs`'s own
  `lower_match` desugars it today (per that file's comment: "desugars every
  arm to ordinary Expr/Instr this backend already knows how to lower — no
  new Instr variant") — reuse the existing desugaring, don't reinvent
  pattern compilation.
- Cover all five `Pattern` variants (`Wildcard`, `Bind`, `Lit`, `Cmp` guard-
  as-pattern, `Glob`, `List`) — confirm each lowers correctly, not just the
  common `Bind`/`Lit` cases.
- `spec_library/block_model/pattern_matching.feature`: each pattern kind
  matches correctly including a guard clause (`case > 10 then`); a `match`
  inside a loop body or closure stays flat (no extra block boundary), per
  the same regression style Phase 5 used for `if`/`match` inside loops.

**Checkpoint:** the feature passes for all five pattern kinds plus the
guard case.

**Done (2026-09-22), scoped down from "all five pattern kinds" to four,
checked before writing code, not discovered as a gap afterward:** PGlob
and PList need expression primitives (a generic host-function call for
`glob_match`, `Member`/`Index` plus real List values) that
`bm_lower_expr` doesn't have yet — legitimately Phase 17 territory, not a
shortcut. PWild/PBind/PLit/PCmp (with `when` guards) reuse the real
`compile_pattern`/`lower_match` shape directly. 5/5 scenarios pass; full
suite 54/54, no regressions.

---

## Phase 12 — Design by contract (`require`/`ensure`/`assert`)

**Realizes:** `Stmt::Assert { kind, expr }`, which already lowers to a
`contract_check(func_name, kind, text, ok)` host call today — the question
this phase actually answers is how that interacts with the flight check
(Fork C, Phase 7) already built for `mut` exclusivity, not whether the
statement itself can be lowered.

- Extend `block_model/lower.patlang` to lower `Assert` at block boundaries
  (a `require` at a block's entry, an `ensure` at its exit) the same way
  today's lowering places it relative to a function call.
- Check whether the flight check can subsume any `require`/`ensure` the
  same way it subsumes some runtime `mut` checks — a provably-true contract
  should skip its own runtime check, mirroring Phase 7's own "runtime
  checks actually performed" counter methodology. If it can't (contracts in
  general are a much bigger static-analysis question than exclusivity,
  see the design doc's own §9 non-goal), say so explicitly rather than
  silently scoping it down.
- `spec_library/block_model/contracts.feature`: a failing `require` aborts
  before the block body runs; a failing `ensure` aborts after the body runs
  but before the jump to the next block; `assert` fails at the exact point
  written. All three checked against real `contract_check`-style error
  output, not just a boolean return.

**Checkpoint:** the feature passes; the flight-check-subsumption question
above is answered one way or the other, not left ambiguous.

---

## Phase 13 — Object orientation (`class`, fields, methods, traits)

**Realizes:** the design doc's own stated direction (§1: the closure layout
was "deliberately chosen to generalize toward 'everything is a function,
everything is an object'") — the biggest single phase in this plan, since
`ClassDecl` brings mutable fields, method-as-closure dispatch, and
inheritance/trait resolution all at once.

- Extend `block_model/lower.patlang` for `Stmt::ClassDecl { name, parent,
  fields, methods, traits }`: fields become a refcounted, mutable object
  (reusing Phase 1's heap directly — an object is structurally close to
  Fork E's `inherited` section: named fields, refcounted as a whole).
  Methods lower to real closures at class-definition time (per the AST
  comment: "`send(obj, "method", args...)` can invoke real user code —
  host fns can't call closures themselves, so dispatch lives in the
  interpreter's/compiled backend's own `CallHost("send", ...)` handling").
- Trait/inheritance resolution order is already decided at the language
  level (own class > traits, last-listed wins on collision > parent) —
  this phase implements that resolution against the block-model's own
  object representation, it does not re-decide the order.
- **A real question this phase must answer, not assume:** does `mut` on an
  object parameter (§3.4) extend to field *writes* (`obj.prop = value`,
  `Stmt::MemberAssign`) the same way it already covers `list_push`/`list_set`
  on a `mut` list parameter? Check `MemberAssign`'s existing lowering
  against a fresh object vs. an aliased one before assuming yes — this is
  the same clone-vs-mutate-in-place decision from §3.5, now against a
  different mutating primitive than the ones Phase 3 already covers.
- `spec_library/block_model/object_orientation.feature`: field defaults are
  applied at construction; a method mutates `self`'s own field correctly at
  refcount 1 and clones at refcount >1 (mirroring Phase 3's mut-parameter
  scenarios, now against object fields); trait resolution order matches the
  documented own > traits (last wins) > parent rule; inheritance reaches a
  parent's field defaults and methods.

**Checkpoint:** all four scenario families pass, including the
mut-on-fields question resolved with an explicit answer (not silently
left as "works for lists only").

---

## Phase 14 — Concurrency (`budgeted`, fibers, real threads)

**Realizes:** cooperative time-budgeted execution (`Expr::Budgeted`, the
mechanism behind the project's own signal-based long-running-program
discipline) and, separately, real OS-thread concurrency (`thread_spawn`,
`parallel_map`).

**A genuinely open design question, not resolved by anything already
decided — flag and resolve it before writing code, the same way Forks A–E
were resolved before Phase 1 started, not discovered mid-implementation:**
Fork D's refcounting (Phase 1) was designed and proven single-threaded.
Real OS threads executing block-model blocks concurrently can, in
principle, race on a shared object's refcount field the same way any
non-atomic shared counter would. Before this phase starts, write a short
design note (mirroring the existing doc's own Fork format) deciding one of:
(a) refcount increment/decrement becomes atomic (a real cost on every
single-threaded operation too, paid everywhere for a case that's rare), (b)
objects crossing a `thread_spawn` boundary get a distinct, thread-safe
refcount path while single-threaded blocks keep the cheap one (two code
paths to maintain, but no across-the-board cost), or (c) something else —
name it, don't default to (a) or (b) by assumption.

- `budgeted(ms) { ... }` lowering: a budgeted block is structurally a loop
  with an injected yield check (per the `Expr::Budgeted` doc comment) —
  extend Phase 5's loop-as-block treatment rather than building a third
  loop mechanism.
- Real threads: confirm what a `thread_spawn`'d block actually needs from
  the block-model engine — likely just "start executing this block on a new
  OS thread, honoring the refcount-safety decision above."
- `spec_library/block_model/concurrency.feature`: a `budgeted` block yields
  and resumes correctly across multiple time-slices (mirroring the CLAUDE.md
  §6 "verify against a realistically-sized workload" requirement — check a
  real `signal_query` mid-run, not a toy case); two threads mutating
  independent (unaliased) objects never block each other; two threads
  racing to mutate the *same* aliased object are serialized safely per
  whichever refcount-safety design was chosen above, not merely "doesn't
  crash in this run."

**Checkpoint:** the design note exists and states a real decision before
any code in this phase is written; the feature passes, including the
race scenario run enough times to be credible evidence rather than a
single lucky pass (concurrency bugs are exactly the kind that pass most of
the time by accident).

---

## Phase 15 — Logic programming / GOAP (`fact`, `rule`, `goal`, `plan`)

**Realizes:** `Stmt::Fact`, `Stmt::Query`, `Stmt::RuleDecl`,
`Stmt::GoalDecl`, and the `pursue`/`activate` expression forms — all
documented as sugar lowering to a small number of host calls
(`fact_add`/`rule_add`/`goal_def`/`plan`) already.

- Extend `block_model/lower.patlang` to lower each declarative form to its
  corresponding host call, threading the globals-view section (Fork B,
  Phase 4) through correctly — facts/rules are exactly the kind of ambient,
  shared state Fork B's elimination was built for, so this phase is largely
  a check that Phase 4's globals threading already covers it rather than
  new mechanism.
- `spec_library/block_model/goap.feature`: a declared fact is queryable
  from a different block than the one that asserted it (via the globals
  section, not ambient reach); a `goal`/`pursue`/`activate` sequence plans
  and executes correctly; a scenario confirming facts/rules declared inside
  one block are visible in a sibling block only through the explicit
  globals-view section, not by accident.

**Checkpoint:** the feature passes; explicitly confirm (per the design
doc's own §8 connection to issues #131–133) whether this phase gives
capability discovery a real structural pre/postcondition to plan against,
or whether that remains future work beyond this phase's scope — state
which, don't imply the connection is now complete unless it demonstrably is.

---

## Phase 16 — Numeric tower completeness

**Realizes:** full coverage of int/bigint/rational/float/complex/interval
auto-promotion under the new engine, not just the plain-int arithmetic the
restricted subset exercised.

- Confirm which of these are heap-allocated (bigint, rational, complex are
  likely candidates; check directly rather than assume) and therefore
  subject to Phase 1's refcounting the same as `List`/`String`/objects.
- `spec_library/block_model/numeric_tower.feature`: reuse
  `gherkin_contracts.patlang`'s `ensure <var> == <literal>` pattern against
  `numeric_kind(x)` for auto-promotion correctness (int+int stays int,
  overflow promotes to bigint, division promotes to rational, etc.) — the
  same representation-invariant testing style
  `spec_library/language/*.feature` already uses, applied to this engine.

**Checkpoint:** the feature passes; any numeric type found to be
heap-allocated has a refcount scenario analogous to Phase 1's, not just an
arithmetic-correctness one.

---

## Phase 17 — System integration and messaging breadth

**Realizes:** `spawn`/`exec_capture`, file I/O, TCP networking, `argv`,
`queue_publish`/`consume`/`ack`, and the `signal_*` family — expected to be
mostly ordinary `CallHost` invocations already supported since Phase 2's
function-call lowering, so this phase is primarily verification, not new
lowering mechanism.

- Confirm each of the above actually is a plain `CallHost` under the
  block-model lowering, with no special block-boundary treatment needed —
  if any turns out to need one (e.g. a value crossing a queue boundary
  needs its refcount handled specially on serialization), name it
  explicitly rather than discovering it as a bug later.
- `spec_library/block_model/system_integration.feature`: a `spawn`+
  `exec_capture` round-trip; a file write/read round-trip; a
  `queue_publish`/`consume`/`ack` cycle preserves a heap-allocated payload's
  contents correctly across the boundary.

**Checkpoint:** the feature passes; the "is this really just CallHost"
question is answered per primitive, not assumed uniformly.

---

## Phase 18 — Library-level parity (no new lowering, verification only)

**Realizes:** confirmation that `zs_*` declared schemas, the
synthesis/GOAP-composition engine, and `task_registry.patlang` — all
ordinary PatLang libraries built on the paradigms above, not new language
surface — run correctly once Phases 10–17 are done, with no block-model-
specific code written for them at all.

- Run the existing `zs_schema` spec suite and the synthesis engine's own
  tests against the block-model engine instead of `pat --ir-run`, unmodified.
- If something fails, the fix belongs in whichever of Phases 10–17 exposed
  the gap, not a special case bolted onto this phase — this phase should
  ideally require zero new lowering code, and if it doesn't, that's a
  signal one of the earlier phases wasn't actually complete.

**Checkpoint:** the existing suites pass against the new engine unmodified,
or every failure is traced back to a specific earlier phase and fixed
there.

---

## Phase 19 — Consolidated native x64 + WASM codegen

**Realizes:** the native half of Fork A's "front to back," now for the
entire language surface covered by Phases 10–18, in one pass — mirroring
exactly how Phase 9 followed Phase 8 rather than being built incrementally
per paradigm (per this round's backend-cadence decision).

- Extend `self_hosting/block_model/native_codegen.patlang` for every new
  block/IR shape Phases 10–18 introduced (event tables, object
  field access, fiber/thread primitives, etc.).
- Re-run the WASM verification path (`build_wasm_check.patlang`,
  `wasmtime run`) against the full language surface, not just the Phase 9
  benchmark program.
- Watch for the same class of gotcha Phase 9 already hit once
  ([[reference_patlang_gotchas]], the `patlang-development` skill §7):
  hardcoded raw-asm runtime calls invisible to IR-level renaming, the
  `print` Call-vs-CallHost convention split between backends, and
  `lower_program`'s synthesized empty `main` when bundling compilation
  units. Check for each again rather than assuming Phase 9's fixes
  automatically generalize.

**Checkpoint:** every `spec_library/block_model/*.feature` file from
Phases 2–18 passes identically on interpreter, native x64, and WASM —
the same three-way parity bar Phase 9 already met for the restricted
subset, now for the whole language.

---

## Phase 20 — Migration/cutover design

**Realizes:** this round's explicit decision to plan cutover now rather
than defer it — a real design document, not code, deciding how (or
whether, and on what timeline) `self_hosting/lib/{lower,codegen_x64,
x64_runtime,interp}.patlang` get retired in favor of the block-model
engine.

This phase's deliverable is a document, structured like the original
design doc's own Forks A–E: named options, tradeoffs, a decision, not a
leaning. At minimum it must decide:

- **Acceptance gate.** What "the block-model engine is a genuine drop-in
  replacement" actually means, checkable — the obvious candidate is the
  block-model engine passing the *entire* existing
  `spec_library/language/*.feature` suite (all 37 files) unmodified, the
  same gate `run_language_spec_suite.patlang` already runs against today's
  pipeline. State whether that's sufficient or whether something more is
  needed (e.g. the two known native-x64 bugs, #145 and #113, being fixed
  as a precondition, or explicitly waived).
- **Cutover shape.** A hard switch (one commit retires the old pipeline) vs.
  a dual-path window (both exist, a flag or build target selects, old path
  deprecated on a stated timeline) vs. permanent parallel existence (the
  block-model engine becomes the recommended path but the old one is never
  removed). Each has a real cost/benefit already implicit in this project's
  own history of mirror-sync debt (see the `mirror-check` skill) — a dual-
  path window recreates exactly that maintenance burden for as long as it
  lasts, which should be weighed explicitly, not ignored.
- **What happens to the debugger, REPL, and playground's `run_ir`
  fragment-compilation path** — each has its own coupling to the current
  pipeline (per Fork A and Fork C's own "before either path begins" note)
  that a cutover decision needs to name, not silently carry over.
- **Sequencing relative to Phases 10–19.** Whether migration-design work can
  start in parallel with the later paradigm phases (Phase 20 is a document,
  not code touching the old pipeline, so there's no hard dependency) or
  whether it should wait until Phase 19's three-way parity bar is met, so
  the acceptance-gate decision above is being written against a completed
  reality rather than a projected one.

**Checkpoint:** the document exists, makes a real decision on each bullet
above (not a leaning), and is reviewed before anything in it is acted on —
per the branch-discipline note, nothing about this document authorizes
touching `self_hosting/lib/*` on its own; that's a separate, later,
explicit step even after this document is written.

---

## What this plan deliberately does not cover

- Actually retiring or modifying `self_hosting/lib/{lower,codegen_x64,
  x64_runtime,interp}.patlang` — Phase 20 produces a *design*, not the
  cutover itself.
- GitHub issue tracking for Phases 10–20 — following the same discipline
  the original implementation plan used, issues (an epic continuation of
  #134, plus one sub-issue per phase, joined to the project board per
  standing practice) are created once this breakdown is confirmed as the
  one to track, not preemptively.
- Resolving Phase 14's refcount-thread-safety fork in this document — it's
  named as a real open question with real options, deliberately left
  undecided here rather than guessed at, to be resolved as its own short
  design note immediately before Phase 14 starts.
