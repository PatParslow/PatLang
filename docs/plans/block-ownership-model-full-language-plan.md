# Block Ownership Model: full-language expansion plan

**Status (2026-09-24): Phases 10–19 and 21 are complete, and Phase 18's
checkpoint is met** — six real, unmodified library selftests (`schema_bdd`,
`pset`, `pmap`, `step_match`, `zs_expr`, `zs_schema`; 177 checks) run under the
block-model engine with output identical to `pat --ir-run`, gated by
`spec_library/block_model/library_selftest_parity.feature` (Phase 23 below).
Native x64 call-with-return (`Call`/`ReturnValue`/`CallDynamic`, #173) and the
WASM path (#174, #181) are done. Phase 20 (migration/cutover design) is written,
with real decisions recorded (a hard switch, gated on both full-suite parity and
issues #145/#113 actually being fixed, not waived); acting on it is explicitly
NOT authorized (#180). Everything still open — methods/inherits/traits,
`budgeted`/threads, GOAP rules, `signal_*`, the `zs_explore` port, the lowering
cost — is tracked on the project board under epic #160.

*Earlier status, kept for the record (2026-09-22):* Phases 10–17 verified at
83/83; Phase 18 genuinely attempted and genuinely failing, recorded as checked
evidence of how much coverage remained rather than as a completed checkpoint.
The sections below tell that story in order, including the corrections.

**Phase 19 is now fully complete (2026-09-23)** — every opcode this
phase scoped (`ContractFail`/`FiberYield`/`Fact`/`Query`/`TypeOf`/
`ReadFile`/`WriteFile`/`GlobalGet`/`GlobalSet`/`HandlerNew`/
`HandlerRegister`/`HandlerLookup`/`BoxNew`/`BoxGet`/`BoxSet`/
`BoxSetUnchecked`/`BoxShare`/`Emit`) now has a real, verified native x64
translation (`native_codegen_check.sh`: 22/22 passing). Proving this end
to end found and fixed several real bugs along the way, not just added
dispatch cases: a project-wide ASLR/relocation bug (missing
`-Wl,--disable-dynamicbase`, fixed at every linker call site in the
shared `x64_build.patlang`, benefiting every native build in the
project); a latent `lower.patlang` bug where twelve different builtins'
bare-statement calls never discarded their own unused return value
(affects the interpreter too, not just native); an `rt_list_push`
argument-order bug in the hand-emitted Global*/Handler* loops; a missing
`bm_heap_init()` call causing a real Box* segfault; and, for `Emit`, a
new architectural piece (`bm_to_real_funcir` now returns a LIST of
FuncIRs — one per handler, plus `main` — instead of always exactly one)
that turned out to need no new call-with-return mechanism or
compile-time-literal restriction, contrary to an earlier, more
pessimistic read. See Phase 19's own section below for the full,
corrected account of every finding. Phase 13 also found and fixed two
real, pre-existing bugs
(`HandlerRegister`'s append-only behavior, and its own downstream
exposure of already-filed issue #145's native x64 `list_set` aliasing
bug) — see Phase 13's own section below for that account.
Phase 14 found its own flagged refcount-thread-safety fork to be moot for
the slice it actually covers (fiber_yield is cooperative, never real
parallelism). Phase 15 found `rule`/`goal`/`pursue`/`activate`/`plan`
genuinely need list-literal support this engine doesn't have yet, and
scoped down to `fact`/`query` accordingly — see each phase's own section
below for the real scope left deferred. Phases 0–9 (the restricted-subset
design, proof, and native/WASM verification) were already complete on
`feature/block-ownership-model` — see
[`block-ownership-model-implementation-plan.md`](block-ownership-model-implementation-plan.md)
for that record, which this document continues rather than replaces.
(An earlier version of this note said Phases 18–20 were not built yet; see
the status paragraph at the top for where each stands now.)**

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

**Done (2026-09-22).** Answer: no, never — the flight check's bounded
points-to/shape analysis is sized to proving box_set mutation-exclusivity
specifically and has nothing to say about an arbitrary boolean condition;
the two are orthogonal concerns, not a "not yet wired up" gap. Implemented
via the existing ContractFail instruction behind a JumpIfFalse rather than
a real `contract_check` host call (this engine has no generic host-
function-call expression support yet, Phase 17's job) — same observable
behavior, not yet the same host-call shape, named plainly. 4/4 scenarios
pass; full suite 63/63, no regressions.

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

**Done (2026-09-22), scoped down to fields only** — checked before
writing code, not discovered as a gap afterward: methods and inheritance/
traits are explicitly rejected (naming which one), since real methods
need call-with-return dispatch this engine's only such mechanism (Emit)
is deliberately too narrow for, and methods-as-closures need first-class
closures this engine has never built. An object is a Box wrapping a
Handler-shaped assoc-list — no new heap layout, and deliberately not the
real engine's own name-keyed `new`/`class_def` mechanism (which Fork B
already wants to move away from). Answer to the mut-on-fields question:
**yes**, exactly — a field write literally calls `box_set` on the whole
record, so it inherits Phase 3's refcount-checked mutate-in-place-vs-clone
behavior with zero new mechanism.

Debugging this phase found and fixed two real, pre-existing bugs, neither
introduced here but both first exercised here:

1. **`HandlerRegister` (Phase 4) was append-only.** Re-registering an
   already-used key left a stale duplicate entry; `HandlerLookup`'s
   forward scan kept returning the FIRST (stale) match, so no field write
   through a Handler ever became visible. `object_handler.feature` never
   caught it because it only ever registered two *different* names.
   Fixed by routing through `bm_rt_assoc_set` (a real check-and-replace)
   instead of a bare `list_push`.
2. **That fix then directly exposed already-filed issue #145** (native
   x64's `list_set` aliasing bug): `bm_rt_assoc_set`'s own in-place
   `list_set` could corrupt an assoc-list's backing storage before
   `BoxSet`'s clone-vs-mutate decision ever mattered — observed as an
   aliased object's clone correctly getting the new value while the
   *original* alias also showed it, instead of staying at the old value.
   Fixed by rebuilding the assoc-list via `list_push` only, never
   `list_set`, avoiding the buggy primitive rather than patching around
   it. Also fixes latent, never-yet-exercised exposure in `GlobalSet`
   (built on the same helper) for the same-key-set-twice case.

4/4 scenarios pass; full suite 71/71, no regressions.

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

**Done (2026-09-22), scoped down to fiber_yield only — the refcount-
thread-safety fork above turned out to be moot for this slice, checked
before writing code rather than assumed:**
`self_hosting/examples/fiber_demo.patlang`'s own header states plainly
that fibers are "implemented on real OS threads under the hood... but
never actually running concurrently — a mutex+condvar pair ensures only
one fiber's thread is ever unparked at a time... distinct from
`parallel_map`, which IS real parallelism." Cooperative fiber-based
yielding is deterministic and single-threaded in effect, so there is no
refcount race to design around for it at all — the fork above applies
only to genuine OS-thread parallelism (`thread_spawn`/`parallel_map`),
which this phase does **not** cover.

What shipped: a block-model *source program* can call `fiber_yield(x)` as
an ordinary mid-block instruction (an outside driver wraps running the
whole program in a fiber and resumes it step by step, observing real,
changing progress) — Phase 8's own debugger already proved the mechanism
works at this engine's level from the outside; this phase lets a program
use it from the inside. 2/2 scenarios pass; full suite 76/76, no
regressions.

**Explicitly deferred, not silently dropped:**
- The full `Expr::Budgeted` sugar syntax (`budgeted(ms) { ... }` with
  automatic while-loop yield injection and `existing`-based resumption) —
  `fiber_yield` is the load-bearing primitive underneath it and is now
  proven; the syntactic sugar on top is a smaller, separable follow-up,
  not attempted in this pass.
- Real OS-thread parallelism (`thread_spawn`, `parallel_map`) and the
  refcount-thread-safety fork it actually requires — genuinely untestable
  under this whole plan's self-hosted-interpreter backend cadence anyway,
  since Box (the thing that would race) is native-x64-only. Revisit when
  Phase 19's native codegen makes it exercisable, not before.

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

**Done (2026-09-22), scoped down to `fact`/`query` only** — checked
against `rust-runtime/src/ir/hosts.rs` before writing code: both take
exactly 3 scalar arguments, not a list, so neither needed this engine's
missing list-literal/`BuildList` support. `rule`/`goal` declarative sugar
(`RuleDecl`/`GoalDecl`) genuinely do build compound `[pred,[args]]` lists
via the real engine's own `BuildList` instruction, which this engine has
no equivalent of — explicitly deferred alongside Phase 17's own generic
host-call/list-literal work rather than attempted with half the needed
machinery. `pursue`/`activate`/`plan` (the GOAP orchestration layer built
on top of rules/goals) are deferred for the same reason.

A real, previously-unnoted finding: `fact`'s own backing store
(`FACTS` in `hosts.rs`) is a `thread_local!` HashMap, entirely outside
PatLang's `__vars`/`set_var`/`get` mechanism and therefore outside this
engine's own `__globals` threading (Fork B, Phase 4) — a fact asserted in
one block is visible from any other block *not* because `__globals`
carried it there, but because it was never scoped by Fork B's own
mechanism at all. The design doc's own Fork B never named this ambient
mechanism (it only covers `set_var`/`get` and `new`/`send`) — a genuine
gap in that document's own coverage, recorded here rather than silently
treated as already handled.

**Answer to this phase's own checkpoint question:** capability discovery
(issues #131–133) does **not** yet have a real structural pre/
postcondition to plan against — `fact`/`query` alone give it a queryable
store of binary relations, not the `rule`/`goal` declarative structure
issue #131's own framing implies. That remains genuinely deferred work,
not something this slice completes. 2/2 scenarios pass; full suite 78/78,
no regressions.

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

**Done (2026-09-22) — needed no new mechanism at all, checked before
writing anything:** a probe run under `--ir-run` confirmed the self-
hosted `parser.patlang` produces a single `"Num"` AST tag for every
numeric literal (no separate `BigNumber`/`Float` shape), carrying only
raw decimal text that `bm_lower_expr` already passes straight through to
a `Const` instruction, evaluated via the real `to_num` — which already
performs the full auto-promotion the real language defines.
`bm_apply_bin`'s own `l + r` etc. are genuine PatLang operators too. Only
`type_of(x)` was added, purely to make that claim independently
checkable from a block-model program's own output.

**Answer to the heap-allocation/refcount checkpoint question:** no
refcount scenario is needed, and this isn't a gap — bigint/rational/
complex values are ordinary PatLang runtime values living on the block
model's own operand stack, never wrapped in *this engine's* Box/refcount
mechanism (Phase 1) at all, since nothing ever calls `box_new` on them.
More fundamentally, numbers are immutable value types: arithmetic always
produces a *new* value rather than mutating one in place, so there is no
exclusivity question to prove for them the way there is for `List`/
`String`/objects — the same "sharing something nobody can change is
always safe" property the design doc already states for read-only
parameters. 4/4 scenarios pass; full suite 82/82, no regressions.

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

**Done (2026-09-22) — the plan's own premise here needed correcting,
checked against real code before trusting it:** "already supported since
Phase 2's function-call lowering" turned out to be wrong. Phase 2's own
call lowering (`bm_lower_jump_call`) only handles calls to *other
declared blocks* (via `JumpBlock`) — this engine has **no generic
`CallHost` dispatch at all**; every recognized host function needs its
own individually-named `Call` case in `bm_lower_expr`/`bm_lower_stmt`
(the same pattern Print/Emit/FiberYield/Fact/Query/TypeOf already use).
So this phase is not pure verification as planned — it's the same kind of
one-function-at-a-time work every earlier host-function addition needed.

Scoped down to `read_file`/`write_file` accordingly (both genuine, fixed-
arity host functions), with the rest of this phase's own planned scope
named as real, separable follow-ups rather than attempted with
insufficient machinery:
- `spawn`/`exec_capture` take a **variadic** argument list, which this
  engine's fixed-arity recognized-call pattern doesn't accommodate
  without real design work (an argc-carrying instruction, mirroring how
  `JumpBlock`'s own param count already varies per call site).
- `queue_publish`/`consume`/`ack` turned out **not to be Rust host
  functions at all** (checked directly) but ordinary PatLang library
  functions (`self_hosting/lib/queue.patlang`) — callable the same way
  once that file is `include`d, but a real library dependency this pass
  doesn't pull in.
- `signal_*` is deferred for the same library-dependency reason.
- TCP networking and `argv` weren't attempted this pass either.

1/1 scenario passes (a file write/read round-trip through two different
blocks); full suite 83/83, no regressions.

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

**Attempted (2026-09-22), genuinely fails — a real, checked result, not a
skipped phase.** Ran `self_hosting/lib/zs_schema.patlang` itself (the
`zs_*` DSL's own parser/implementation file — real, unmodified library
code, not a synthetic test) through `bm_lower_program`/`bi_run`.
Result: `bm_lower(): does not support: expression shape 'Call'` — a
generic, unrecognized function call, immediately, before any schema-
specific logic is even reached.

**Traced to specific, already-named earlier-phase gaps, per this
checkpoint's own instruction — not a new, unexplained failure:** real
library files use List literals (no `bm_lower_expr` support at all,
named as a real gap since Phase 11's PGlob/PList exclusion), generic
host-function calls beyond the individually-recognized set Phases 10–17
built up one at a time (named repeatedly, most explicitly in Phase 17's
own premise-correction), and very likely closures/classes-with-methods
(Phase 13's own named exclusion) once past the first failure. This is
exactly the signal the phase's own checkpoint anticipated: the language
surface built so far (Phases 10–17) is real but still narrow, and real-
world library code exercises far more of it than any single hand-picked
scenario does.

**The two named Phase 17 follow-ups are now built (2026-09-23) — List
literals and generic host-call dispatch both work — but the checkpoint
still does not fully pass; the REAL remaining blocker, found by
re-attempting it, is a third, deeper, pre-existing gap this phase's own
scope never covered.**

- `["BuildList", n]` (a new block-model bytecode instruction: pops `n`
  values pushed in written order, pushes a fresh List) and a generic
  `["CallHost", name, argc]` fallback (for any `Call` whose callee isn't
  one of this engine's own individually-recognized builtins, and isn't a
  declared block-model function either) are both implemented in
  `lower.patlang`/`interp.patlang`, mirroring the REAL self-hosted
  `lower.patlang`'s own equivalent "List"/"Index"/"Call" cases exactly,
  not invented from scratch. `["Index"]` (`lst[i]`) needed no separate
  instruction at all — it lowers straight to `["CallHost", "list_get",
  2]` through the same new mechanism.
- The generic dispatch reuses `self_hosting/lib/interp.patlang`'s own
  `interp_call_host(name, args)` — a real, already-"feature complete" (for
  every stateless utility chunk: core, strings_ext, collections_handles,
  files, io_misc, math) host-function-by-name dispatcher — rather than
  reinventing one. Confirmed no name collisions with this file's own
  `bm_-`/`bi_-`prefixed functions before including it, via a throwaway
  smoke test, not assumed safe.
- A call to a DECLARED block-model function used as a sub-expression
  (not in tail/return position) is explicitly rejected with a clear,
  named message rather than silently misrouted into the generic
  CallHost fallback (which would otherwise fail downstream with a
  confusing "unknown host function", obscuring the real cause).
- A real bug was found and fixed proving this, not designed around in
  advance: `bm_hash_rewrite_instrs` (the opcode-hash-dispatch rewrite
  every block's own instrs go through before native codegen ever sees
  them) has an explicit per-opcode operand whitelist; anything not
  listed falls into a bucket that assumes NO operand at all. Both new
  instructions carry operands (`BuildList`'s own count, `CallHost`'s own
  name+argc) that would have been silently DROPPED — not just
  miscompiled, gone entirely — had this not been caught by tracing the
  code path before shipping, rather than after a confusing runtime
  failure.
- Verified via a new `spec_library/block_model/library_parity.feature`
  (List literal + indexing + `list_len`/`list_push`, never individually
  recognized by name, + `hash_string`, a genuine stateless-chunk host
  function — all cross-checked against `pat --ir-run`'s own output for
  the identical source) and the full interpreter suite, zero
  regressions. Also given real, if disclosed-incomplete, native x64
  support (Phase 19's own `native_codegen.patlang`): both instructions
  are direct passthroughs to `codegen_x64.patlang`'s own already-real
  `BuildList`/`CallHost` — `BuildList` always works, `CallHost` only for
  whatever names happen to fall inside that backend's own separate
  "OS-boundary allowlist" (confirmed for `list_len`/`list_get`, not
  claimed for every name `interp_call_host` covers).

**Re-attempting Phase 18's own original checkpoint with this new support
in place, empirically, not assumed:** lowering `self_hosting/lib/
zs_schema.patlang` now gets further (past the original "expression
shape 'Call'" failure) before hitting a DIFFERENT, deeper, PRE-EXISTING
restriction from Phase 2 itself: **"`return EXPR` where EXPR isn't a
call to a declared block (no call stack to return a value up through
yet)"**. A block-model function can only ever "return" via a TAIL call
to another declared block (`JumpBlock`); it has no mechanism at all for
returning a plain computed value (`return 5`, `return x + 1`, or the
result of calling a helper mid-expression) — which real library code
needs constantly, and which is NOT one of Phase 18's two named gaps.
This is Fork A's own foundational "no call stack" design choice (design
doc section 3.1), not an oversight this phase's own scope covers: fixing
it would mean designing a genuine call-with-return mechanism for
ORDINARY functions (this engine has exactly one such mechanism today,
`Emit`, deliberately narrow and reserved for event handlers specifically
— see `block_ir.patlang`'s own Phase 10 header) — a separate, materially
larger architectural decision, correctly out of scope for "fill in an
already-named follow-up" work, and **not attempted here without an
explicit decision to do so.**

**Not remedied here, still genuinely incomplete as a checkpoint:** this
phase's own two named gaps are done and verified; the checkpoint's own
broader goal (real, unmodified library code running end to end) is not
met, and the actual remaining blocker is now precisely diagnosed —
ordinary non-tail function calls with return, not "closures/classes-
with-methods, probably" as this section's own earlier, less precise
guess had it. This phase's own result stands as recorded evidence of
exactly how much further coverage a genuine drop-in claim would need,
not a completed checkpoint.

**Re-attempted after Phase 21 (2026-09-23) — got further, found two more
real blockers, one fixed, one newly diagnosed and NOT yet fixed:**

1. **A real, previously-undisclosed leak in Phase 18's own generic
   CallHost fallback, found and closed.** `set_var`/`get`/`send` are
   genuine, real host functions (`interp_call_host` already supports all
   three), so the generic fallback would dispatch them straight through
   to REAL, process-wide ambient state — completely bypassing Fork B's
   own "full elimination of ambient globals" guarantee for any program
   calling them directly instead of the blessed `set_global`/
   `get_global`/`handler_*` sugar. Confirmed exploitable via a direct
   repro before fixing it. `bm_lower_expr`'s own generic-CallHost branch
   now rejects these three names explicitly
   (`bm_lower_is_ambient_state_name`), with a message naming the
   rationale — verified via a new scenario in `library_parity.feature`.
2. **`self_hosting/lib/zs_schema.patlang`'s own `zs_registry()`, and two
   sibling files' own equivalent patterns, used `new("Dict", name)` +
   ambient `set_var`/`get` — exactly the "ephemeral majority" pattern
   Fork B (design doc section 6) names as what it eliminates, and which
   block-model's own `new(...)` genuinely cannot run (Phase 13 only
   supports the `class`-declared form). Ported to `get_global`/
   `set_global`/`handler_new`/`handler_register`/`handler_lookup`
   instead, across THREE files, not one — `self_hosting/lib/{zs_schema,
   schema_bdd}.patlang`'s own registries, and `zs_expr.patlang`'s own
   scalar ambient state, each traced by re-running the checkpoint and
   finding the NEXT failure, not assumed from reading the code. Real,
   non-obvious correctness trap found and avoided before shipping: an
   empty List is FALSY in PatLang (confirmed directly), so a naive
   `if existing then` "does the registry already exist" check would have
   silently recreated a fresh, empty registry on every call forever,
   never accumulating anything — fixed by checking `type_of(existing) ==
   "list"` instead. A new shared file, `self_hosting/lib/
   block_model_compat.patlang` (real-function implementations of block-
   model's own sugar names, transparent under block-model since its own
   lowerer always intercepts these exact names by an earlier, hardcoded
   match), holds the wrappers — needed as its own file, not bundled into
   any one of the three consumers, because `schema_bdd.patlang` and
   `zs_expr.patlang` are ALSO each included independently elsewhere
   without `zs_schema.patlang`. Verified with zero regressions against
   ALL SIX real-engine test suites that exercise these files
   (`run_zs_selftests.patlang`'s own 14, plus `zs_expr_selftest.patlang`
   81, `schema_bdd_selftest.patlang` 5, `schema_synthesis_hook_selftest
   .patlang` 3, `library_loans_schema_demo.patlang` 7, and `zs_refine_
   selftest.patlang` 62 — 172 checks total, none broken) and the full
   block-model suite (91/91, zero regressions there too).
3. **The blocker named above IS now fixed (2026-09-23, same day) — real
   scope, not the smaller estimate first given, and it found TWO more
   real, pre-existing bugs along the way.** `bm_lower_top_level_stmt_list`
   now takes an explicit CONTINUATION parameter (a tagged value, `["none"]`
   or `["jump", target_name, captured, jump_params]`, applied via a new
   `bm_apply_continuation` at whatever point turns out to be a statement
   list's own actual natural end) instead of assuming "the natural end is
   always just stop" — the earlier estimate ("each nesting level needs
   its own captured-variable threading... not a small patch") undersold
   just how deep this went: it's a genuine CPS-style restructuring, not a
   localized patch.
   - A new `bm_lower_if_with_nested_while` handles an `if` whose
     then/else contains a `while` (checked via a new
     `bm_stmt_list_contains_while`, recursive to arbitrary depth): the
     code after the `if` becomes a synthesized "after" block, reached by
     an unconditional `JumpBlock` at the end of BOTH branches (dead code
     when a branch already transferred control unconditionally of its
     own, the same reasoning `bm_lower_while`'s own exit block already
     relied on).
   - **A real, PRE-EXISTING bug, confirmed via a minimal repro with NO
     `if` involved at all** (a plain `while` directly nested inside
     another `while`, with any statement after the inner one): the outer
     loop's own back-edge/exit-transfer code was appended by
     `bm_lower_while`'s own CALLER-side code, immediately AFTER its call
     into `bm_lower_top_level_stmt_list` returned — which works fine
     when that call returns normally, but is silently skipped entirely
     the instant the body's own last reachable statement is ITSELF a
     further split (a nested `while`, or now an `if` containing one),
     since that call then returns EARLY via `bm_lower_while`/`bm_lower_
     if_with_nested_while` directly. Crashed with "unbound in this
     block's own pointer" the moment such a shape actually ran — not
     something either existing loop fixture happened to exercise. Fixed
     by the continuation mechanism above, not a targeted workaround.
   - **A second, real, PRE-EXISTING bug**, found immediately after fixing
     the first: a loop's own exit path lives, textually, INSIDE its own
     head block's own scope (the false-path of its own condition check),
     so it needs access to whatever the code AFTER the loop needs too —
     not just the loop BODY's own free variables, which is all `captured`
     (Phase 6/Fork E's own precision analysis) ever computed. A value
     referenced only after a loop, never inside its own body, crashed
     the same way, for the same underlying reason. Fixed by unioning the
     body's own free vars with free vars of "everything after the loop"
     (via two new helpers, `bm_list_slice_from`/`bm_union_preserving_
     order`) and whatever the enclosing continuation itself needs —
     confirmed this union still correctly EXCLUDES a value referenced
     nowhere at all, by re-running `free_variable_capture.feature`'s own
     dedicated precision scenarios unchanged, not merely reasoning that
     it should.
   - **A third, real, MISSING case**, found immediately after re-running
     the checkpoint past the nested-while fix: `zs_lines()` also calls
     `sb_push(...)` as a BARE STATEMENT — Phase 18's own generic CallHost
     fallback only ever covered VALUE-context calls (`bm_lower_expr`);
     `bm_lower_stmt`'s own separate bare-statement dispatch chain never
     got the analogous fallback at all. Fixed the same way, at the same
     shared dispatch point, discarding the return value via the
     established `Store "__bm_discard"` convention.
   - **Milestone: `self_hosting/lib/zs_schema.patlang` — the exact file
     Phase 18's own checkpoint named — now lowers COMPLETELY** through
     `bm_lower_program`, confirmed directly (a new permanent regression
     scenario in `library_parity.feature` lowers the real, unmodified
     file end to end and checks for zero unsupported-construct errors),
     not a synthetic excerpt. Verified with zero regressions: the full
     block-model interpreter suite (96/96, up from 93), native codegen
     checks (24/24, unaffected), and all real-engine test suites that
     touch these files (unaffected — the fixes are entirely inside
     `self_hosting/block_model/lower.patlang`, which the real engine
     never consults).
   - **Still not attempted, a separate, further undertaking:** actually
     RUNNING the full, original `zs_schema` selftest suite (`self_
     hosting/tools/run_zs_selftests.patlang`) through the block-model
     engine, as the checkpoint's own broader goal describes — that needs
     `self_hosting/lib/test.patlang` (the Gherkin runner itself) and
     several more files (`zs_refine`, `zs_explore`, `zs_generate`,
     `zs_infer`, `pset`, `pmap`, ...) to ALSO lower, which will very
     likely surface further, currently-unknown blockers of its own —
     lowering ONE library file completely is real, necessary progress,
     not the same claim as "the whole selftest suite runs end to end."

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

**Scoped and partially verified (2026-09-22); not completed this
session — a real, sized remainder, not a vague "still TODO."**

The true remaining scope, checked directly against
`native_codegen.patlang`'s own header before estimating it, is larger
than "the Phases 10–18 additions alone": that file's own header already
named `BoxNew`/`BoxGet`/`BoxSet`/`BoxSetUnchecked`/`BoxShare`/
`ContractFail`/`GlobalGet`/`GlobalSet`/`HandlerNew`/`HandlerRegister`/
`HandlerLookup` as explicitly un-translated back in Phase 9 itself — this
phase inherits that pre-existing gap on top of the 7 new opcodes Phases
10–17 added (`Emit`, `FiberYield`, `Fact`, `Query`, `TypeOf`, `ReadFile`,
`WriteFile`). **18 opcodes total need real x64 translation**, comparable
in size to Phase 9's own original undertaking, which itself needed
several real bug fixes along the way (the `JumpIfFalse`/`Jump` target-
fixup bug, the `main`-collision issue, the `g_apply_table` gap) — not
attempted in the same pass as writing this plan update, to avoid rushing
untested native-codegen changes past this document's own established
RED/GREEN/verify discipline.

**One genuine open question was resolved before any implementation, so
the next session can start directly rather than re-deriving it:** the
real self-hosted `lower.patlang`'s own ordinary `Call` lowering
(`lower_expr`'s `"Call"` arm) confirms args are pushed in **written
order** (`args[0]` first, `args[1]` second, ...), consumed by
`["Call", callee, argc]` — the same "push in the order the callee
expects" convention this engine's own Box/Handler instructions already
follow internally. This settles how each new opcode's translation should
push its own args before calling the real underlying function.

**Correction (2026-09-22, same day, before any implementation was
written): the per-opcode table below this note (kept for the record) was
wrong about which opcodes are actually easy, found by checking each
claim directly rather than trusting the pattern-match to `Print`'s own
precedent.** Two real, verified findings that change the picture:

1. **`fiber_yield`/`fact`/`query`/`type_of`/`read_file`/`write_file` have
   ZERO native x64 support today — not "already proven to compile
   natively," which was flatly wrong.** `fiber_demo.patlang`'s own header
   claim ("works... natively compiled") refers to `pat --patc` (the
   Rust-native `codegen.rs` backend) — a *different* native path from
   `patc1.exe --x64` (`codegen_x64.patlang`), which this whole plan's own
   backend-preference order treats as the real target. Checked directly:
   grepping `codegen_x64.patlang` and `x64_runtime.patlang` for any of
   these six names returns nothing at all. Compiling them to
   `patc1.exe --x64` would need genuinely new x64 runtime primitives
   (real file I/O, a native fact-store, a real fiber-yield mechanism)
   built from scratch in `x64_runtime.patlang` — a materially larger,
   separate undertaking, not a same-pattern `Call` translation.
2. **Box's own heap.patlang is not bundled into the existing native
   build path at all.** `self_hosting/block_model/tools/
   build_native.patlang` (the one real native-build driver this project
   has) only links against the pre-built `x64_runtime.obj` via
   `extern_names` — it never `include`s `heap.patlang`, and no other
   driver in this tree does either (checked directly, zero matches).
   Box-instruction translation needs that wired up first — either
   bundling `heap.patlang`'s source into the same compilation unit
   (Phase 1's own native check, `refcounted_heap_native_check.sh`, does
   exactly this, so the pattern exists to copy) or pre-building it into
   its own `.obj` and externing it the same way `x64_runtime.obj`
   already is — untested either way as of this note.

**Real, achievable Phase 19 v1 scope, given these corrections:**
`BoxNew`/`BoxGet`/`BoxSet`/`BoxSetUnchecked`/`BoxShare`/`ContractFail`
(needs the heap.patlang bundling fix above first) plus
`GlobalGet`/`GlobalSet`/`HandlerNew`/`HandlerRegister`/`HandlerLookup`
(ordinary list operations, no heap.patlang dependency — `BuildList` is
already a real, working `codegen_x64.patlang` instruction, confirmed by
`native_codegen.patlang`'s own existing `init_instrs` use of it for
`__globals`). **`Emit`, `FiberYield`, `Fact`, `Query`, `TypeOf`,
`ReadFile`, `WriteFile` are deferred as a distinct, larger follow-up**
needing new `x64_runtime.patlang` primitives, not attempted alongside the
achievable slice above. The original per-opcode table is kept below for
the parts that still hold (`ContractFail`'s real `contract_check`
convention, the Handler/`list_push`-not-`list_set` note), but its
"already proven to compile natively" claims for the six host-function
opcodes should be read as superseded by this correction.

Original table, for the record (see the correction above for what's
actually still trustworthy in it):

| Opcode(s) | Real function | Notes |
|---|---|---|
| `BoxNew` | `bm_alloc(8)` then `bm_box_write(ptr, v)` | two calls; needs a synthesized temp to hold `ptr` between them (the same `Store`/`Load`-temp pattern this session's own lowering work already uses repeatedly); needs heap.patlang bundled into the build first (correction above) |
| `BoxGet` | `bm_box_read(ptr)` | one call; same heap.patlang-bundling prerequisite |
| `BoxSet` / `BoxSetUnchecked` | `bm_rc_touch_for_mutation(ptr)` + `bm_box_write` (checked) or `bm_box_write` alone (unchecked) | mirrors the interpreter's own branching logic, now as emitted `JumpIfFalse`/`Jump` around two `Call` paths instead of a PatLang `if`; same prerequisite |
| `BoxShare` | `bm_rc_inc(ptr)` | one call, pointer unchanged; same prerequisite |
| `ContractFail` | `contract_check(func_name, kind, text, false)` | a 4-arg `CallHost` — confirmed as the real convention lower.patlang itself already emits for `Assert`, not guessed |
| `GlobalGet` / `GlobalSet` | plain list operations (`list_get`/`list_set`-equivalent on the globals value) | no heap.patlang involvement, ordinary list manipulation already proven to compile |
| `HandlerNew` / `HandlerRegister` / `HandlerLookup` | ordinary list construction/lookup, mirroring `bm_rt_assoc_get`/`bm_rt_assoc_set`'s own logic (**note the Phase 13 fix**: use the `list_push`-rebuild form, never `list_set`, to avoid re-triggering issue #145 on native x64) | |
| `Emit` | **deferred** — recursive call structurally mirrors `interp.patlang`'s own approach but needs a REAL native call mechanism where `interp.patlang` had none (Fork A) — the one opcode here that may need actual new design, not just a `Call` translation |
| `FiberYield` | **deferred, needs a new native primitive** — no `codegen_x64.patlang`/`x64_runtime.patlang` support exists (correction above) |
| `Fact` / `Query` | **deferred, needs a new native primitive** — same finding |
| `TypeOf` / `ReadFile` / `WriteFile` | **deferred, needs a new native primitive** — same finding |

**Not started:** the WASM re-verification pass, and the "watch for the
same class of gotcha Phase 9 already hit" checkpoint item — both wait for
the native x64 translation above to exist first, per the plan's own
established sequencing (native before WASM, self-hosted-interpreter
proof before either).

**Second correction, same day, after actually implementing (2026-09-22):
the correction immediately above was ALSO wrong.** `FiberYield`/`Fact`/
`Query`/`TypeOf`/`ReadFile`/`WriteFile` do NOT need new native
primitives — they already exist as real, complete, already-compiled
`x64_runtime.patlang` functions (confirmed present in the linkable
`x64_runtime.build/x64_runtime.funcs` manifest). The earlier "zero
support" claim came from grepping for quoted host-call-name strings
(the `CallHost` dispatch pattern), not for each function's actual
`make a function called NAME` definition — a real methodology error,
caught by redoing the search correctly before implementing rather than
after. All six now translate as ordinary `Call`/`CallHost` instructions,
implemented and verified via real native builds (10/10 scenarios in
`native_codegen_check.sh`, including the whole existing suite re-run
with zero regressions).

**A real, project-wide bug was found and fixed proving this end to
end, not designed around in advance.** Without `-Wl,--disable-
dynamicbase`, Windows can relocate a linked image away from the fixed
`0x140000000` base `x64_family_code_asm`'s own classification logic
hardcodes (needed to distinguish a `.data` string literal's address
from a plain int). Confirmed via a hand-instrumented raw address dump:
the actual runtime address landed far outside `[0x140000000,
0x150000000)`, silently misclassifying every string constant as
"other"/"int" and corrupting `print()`'s own dispatch for it, while
`patc1.exe`'s own single-object-file builds happened not to trigger it.
Fixed at every linker call site in `self_hosting/lib/x64_build.patlang`
(the shared helper, so this benefits every native build in the project,
not just the block model) and in `build_and_run_native.sh`
independently.

**A second, real, latent bug was found in `lower.patlang` itself while
debugging the above** (affects the interpreter too, not native-
specific): bare-statement calls to `box_set`/`box_share`/`box_new`/
`box_get`/`get_global`/`handler_new`/`handler_register`/
`handler_lookup`/`type_of`/`read_file`/`write_file`/`query` never
discarded their own unused return value, corrupting whatever the block
did next. Fixed at the one shared delegation point, matching the real
compiler's own `Store "__discard"` convention. Never previously
exercised because no earlier fixture chained two of these bare-
statement calls in one block.

`fiber_yield` compiles but segfaults with no active fiber context
established — a real, separate, deliberately out-of-scope finding (a
bare smoke test with no fiber machinery isn't a valid usage pattern for
it), not silently papered over.

**`GlobalGet`/`GlobalSet`/`HandlerNew`/`HandlerRegister`/`HandlerLookup`
done (2026-09-22).** No new build plumbing needed — `HandlerNew` is just
`BuildList 0` (already a real, working `codegen_x64.patlang`
instruction); `GlobalGet`/`HandlerLookup` and `GlobalSet`/
`HandlerRegister` reduce to the SAME two assoc-list walks
(`interp.patlang`'s own `bm_rt_assoc_get`/`bm_rt_assoc_set` logic),
hand-emitted directly as real `Jump`/`JumpIfFalse` loops calling
`rt_list_get`/`rt_list_len`/`rt_str_eq`/`rt_list_push` — all four already
present in `x64_runtime.funcs`, confirmed rather than assumed. This
needed one new mechanism in `bm_to_real_funcir`: `__RawJump`/
`__RawJumpIfFalse`, for a jump target synthesized entirely within one
instruction's own expansion (never a real block-model `Jump`), resolved
with `+base` only, bypassing `index_map` (which would otherwise
misinterpret it as an original, pre-expansion instruction index and
remap it to the wrong position). A real bug was found and fixed proving
this, not designed around in advance: `rt_list_push(l, v)` (list
argument first, value second) had its two arguments backwards in three
call sites inside the hand-emitted set-loop, corrupting the handler's
own backing list via `rt_list_push`'s own address/length read against
the wrong operand — a genuine segfault the moment the loop actually ran
with at least one real entry (an empty-handler smoke test had passed by
accident, masking it). Found by narrowing a minimal repro (a single
`handler_register` then `handler_lookup`) and reading the generated
`.asm` directly, not by inspection alone. Verified via
`native_codegen_check.sh` (13/13) and the full interpreter suite (83/83,
zero regressions).

**`BoxNew`/`BoxGet`/`BoxSet`/`BoxSetUnchecked`/`BoxShare` done
(2026-09-23).** The prerequisite this section originally named —
`heap.patlang` isn't bundled into the native build path — is now solved
via a real, separate, THIRD compilation chunk (mirroring
`x64_runtime.obj`'s own established fingerprint-cache convention, not a
new invention): `tools/build_heap_chunk.patlang` lowers the
CONCATENATION of `x64_runtime.patlang` + `heap.patlang`'s own source
together (so `lower_program` can see every real function name and
correctly emit `Call` rather than a broken `CallHost` placeholder for
`heap.patlang`'s own calls into `rt_heap_alloc`/`mem_peek_qword`/
`mem_poke_qword`), then filters the resulting function list down to only
`heap.patlang`'s own functions before emission (avoiding a duplicate-
symbol link error against the already-built `x64_runtime.obj`), producing
`heap_chunk.obj`/`heap_chunk.funcs`. `build_native.patlang` and
`build_and_run_native.sh` now read/extern/link all three chunks.
Translation itself: `BoxNew` → `bm_alloc(8)` + `bm_box_write`, pushing
the pointer; `BoxGet` → a bare `Call "bm_box_read", 1` (the pointer is
already on top of the native stack from a prior instruction, exactly
like `FiberYield`/`Fact`'s own single-`Call` translation — no `Store`/
`Load` needed at all); `BoxSet`/`BoxSetUnchecked` → a hand-emitted
`__RawJumpIfFalse` branch around two `Call "bm_box_write", 2` paths
(mutate-in-place vs. allocate-and-write-fresh), branching on
`bm_rc_touch_for_mutation(ptr) == 1` for the checked form, always taking
the mutate-in-place path for the unchecked form (matching
`interp.patlang`'s own branching exactly); `BoxShare` → `bm_rc_inc(ptr)`
(return discarded) with the same pointer re-`Load`ed afterward so it
survives the `Call`'s own arg-consuming convention, unchanged.

A real bug was found and fixed proving this, not designed around in
advance: `heap.patlang`'s own free-list table
(`bm_freelist_table_addr`'s backing `"__vars"` entry) is populated by
`bm_heap_init`, which `interp.patlang`'s own `bm_ensure_heap_ready` calls
lazily, once, before the first `BoxNew` — the native path had no
equivalent call at all, so the first `bm_alloc` walked
`bm_freelist_pop -> bm_freelist_slot_offset -> bm_freelist_table_addr`
through an uninitialized table address, segfaulting immediately (exit
139, confirmed directly running the new fixture, not predicted from
reading the code). Fixed by calling `bm_heap_init()` unconditionally at
native program start (`bm_to_real_funcir`'s own `init_instrs`, alongside
the existing entry-block `__globals` init) rather than lazily
flag-gating it like the interpreter — simpler and equally correct, since
a native program has exactly one start (unlike `bi_run`'s shared
interpreter process, reset per call), and cheap even for a program that
never touches a Box at all.

Verified two ways: `native_codegen_check.sh` (16/16, zero regressions)
and, since Box is native-x64-only (`heap.patlang`'s `rt_heap_alloc`/
`mem_peek_qword`/`mem_poke_qword` are not host functions under
`pat --ir-run` at all — a plain interpreter cross-check is structurally
impossible, confirmed directly), a real independent cross-check instead:
the SAME block-model program run through `bi_run` (`interp.patlang`'s
own bytecode interpreter) compiled to native code via
`./patc1.exe ... --x64` agrees exactly with the direct
`native_codegen.patlang` translation: both print `30`, `999`, `100` —
the last two proving real copy-on-write (a Box shared before mutation
keeps its original value; the mutated one gets the new value) — two
independent code paths over the identical IR, both genuinely native.

**Also noted, not yet acted on (2026-09-23):** every Block Ownership
Model native build script (`build_heap_chunk.patlang`,
`build_native.patlang`'s helpers via `x64_build.patlang`'s
`x64_assemble`/`x64_link`/`x64_build_linked*`, `build_and_run_native.sh`)
calls `nasm`/`gcc` directly and never consults
`x64_build_use_native_toolchain()` — the self-hosted PatLang assembler+
linker (`x64_asm.patlang`/`x64_pe_link.patlang`) that `patc1.exe --x64`'s
own CLI dispatch already defaults to. Deliberately left as-is for this
phase (confirmed ~68x slower per the project's own real measurement —
9 min vs. 8s — which would slow every remaining Phase 19 iteration), a
disclosed choice, not an oversight. **When Block Ownership Model's own
build tooling reaches a stage where routing through the self-hosted
toolchain matters, it needs updating too** — it does not happen
automatically just because `x64_build_use_native_toolchain()` exists
elsewhere in the project.

**`Emit` done (2026-09-23) — Phase 19 is now fully complete: all 18
opcodes this phase originally scoped translate through real native x64
codegen, nothing left deferred.** The two restrictions floated in the
note above it (compile-time-literal-only event names, and needing a
brand-new call-with-return mechanism) both turned out to be avoidable
once actually designed, not required — found by working through the
design rather than assumed from the initial "this looks hard" read:

- **No new call-with-return mechanism needed at all.** By the time
  Emit's own dispatch runs, every handler registered anywhere in the
  program has already been compiled as its own real, separate FuncIR
  (previously every block — function or handler — was flattened into
  ONE shared "main" FuncIR; `bm_to_real_funcir` now returns a LIST of
  FuncIRs instead of always exactly one). Emit itself then only needs an
  ordinary native `Call`/`Return` to reach a handler and get its final
  `__globals` back — the SAME mechanism every other real function call
  in this backend already uses, not a new one. No `MakeClosure`/
  `CallValue` needed either: the compile-time event table already names
  every handler a given event can reach, so dispatch is a straight-line
  runtime `rt_str_eq` chain over known names, never an indirect
  function-pointer call.
- **No compile-time-literal restriction on event names.** A runtime-
  computed event name (e.g. a `Var`) works exactly like a literal string
  at the dispatch site — both are just a value compared with `rt_str_eq`
  — so the general case was no harder to support than the literal-only
  one would have been.

The one real new piece of machinery: partitioning `bi_program_blocks
(prog)` into `main` (everything NOT owned by a handler) and one family
per handler root, via a genuine reachability closure over `JumpBlock`
edges (`bm_nc_collect_block_closure`) — proven correct rather than
assumed, since a synthesized descendant block's name (a loop head/exit,
etc.) is always a fresh, globally-unique value referenced from nowhere
except the one body that created it, so a handler's own closure can
never accidentally pull in a block belonging to `main` or a different
handler. Each handler's own family is flattened via the SAME core pass
Phase 9 always used (factored out as `bm_nc_flatten_blocks`, reused for
both `main` and every handler), ending in `Load "__globals"` + `Return`
instead of `main`'s own `Const unit` + `Return` tail.

Verified via `native_codegen_check.sh` (22/22, zero regressions) and the
full interpreter suite (83/83, zero regressions). Since Emit/Global* (unlike
Box*) need no native-only primitive, cross-checked the simpler way: the
SAME source run through `pat --ir-run`'s own `bm_lower_program`/`bi_run`
directly agrees exactly with the native translation on all five printed
values (`100`, `200`, `42`, `2`, `3`) — two handlers registered for the
same event both fire in declaration order, a handler's own `set_global`
is visible in the emitting block immediately after `emit()` returns, and
`emit()` genuinely returns control (the statement after it, and the
enclosing function's own subsequent `return`, both still run).

**Noted follow-up, not yet acted on:** `run_block_model_spec_suite
.patlang`'s own 55 `exec_capture`-spawning scenarios run strictly
sequentially on one core, even though this machine has 20 logical
cores — the multi-minute full-suite runs this session repeatedly needed
are one core doing serial work while 19 sit idle. Parallelizing
independent scenarios (via concurrent `exec_capture` calls or
`thread_spawn`) is a real, worthwhile speedup for this specific
recurring pain point, flagged for later rather than changed mid-run
while this exact suite was being used as the correctness gate for
Emit's own verification.

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

**Done (2026-09-22).** Written now, deliberately not waiting for Phase
19 — this is a document, not code touching the old pipeline, and Phase
18's own genuine, checked failure this session makes the real distance
between "current coverage" and "drop-in replacement" concrete enough to
decide against honestly, rather than a hypothetical to reason about in
the abstract.

**Decision — Acceptance gate.** The block-model engine is a genuine
drop-in replacement only once **both**: (1) it passes the entire existing
`spec_library/language/*.feature` suite (all 37 files) unmodified,
matching what `run_language_spec_suite.patlang` already runs against
today's pipeline, and (2) issues **#145 and #113 are actually fixed**,
not waived. Not sufficient on its own: this session's own Phase 18
result shows real library code (not just hand-picked scenarios) needs
list-literal support, generic host-call dispatch, and almost certainly
closures/classes-with-methods before (1) is even attemptable — so (1)
alone, even if it somehow passed, would not yet mean real programs run.
Waiving #145/#113 was considered and rejected: the entire motivating
premise of this design (design doc §1) is fixing exactly those bugs: a
"drop-in replacement" that still carries a known, silent aliasing
correctness bug would be a regression dressed as a migration, not a
genuine one.

**Decision — Cutover shape.** A **hard switch**, once the acceptance gate
above is met — not a dual-path window, and not permanent parallel
existence. This project already carries one recurring maintenance
burden of exactly this shape (the mirror-sync debt between
`codegen.rs`/`runtime_rs.patlang` and the self-hosted grammar, per the
`mirror-check` skill) purely from having two implementations that must
agree. A dual-path window between the old pipeline and the block-model
engine would open a *second*, structurally identical burden — keeping
`codegen_x64.patlang` and `native_codegen.patlang` (once it exists,
Phase 19) in sync indefinitely — for exactly as long as the window
lasts. Given that this project has already lived the cost of one such
burden, deliberately opening a second one as the default cutover shape
isn't justified; a hard switch, gated on the acceptance criteria above
actually being met, avoids it entirely.

**Decision — Debugger, REPL, and `run_ir`.**
- **Debugger**: carries over **unchanged**, not merely "expected to." Fork
  A's own claim (pause/resume via `fiber_yield` is representation-
  agnostic) is not a projection here — Phase 8 already built and proved
  it directly on this engine's own `interp.patlang`, and Phase 14 proved
  a block-model *program* can drive the same mechanism from the inside
  too. Nothing further is needed for this piece specifically.
- **REPL / playground `run_ir` fragment path**: does **not** carry over
  automatically, and is a named **precondition for cutover**, not
  something to discover missing afterward. `run_ir` compiles and runs a
  fragment of IR *during* an already-running program with no whole-program
  flight check ever having covered it (Fork C's own "before either path
  begins" note already flagged this as a real gap). Before cutover, the
  block-model engine needs its own equivalent: an on-demand
  `bm_lower_program`-then-`bi_run` (or block-level equivalent) path,
  with the flight check re-run for that fragment specifically, exactly as
  Fork C originally specified. Until that exists, REPL/playground users
  would silently lose fragment-level interaction at cutover — unacceptable
  for a "drop-in" claim, so it blocks cutover rather than following it.

**Decision — Sequencing.** This document is written now (see above), but
**acting** on it — actually retiring anything under `self_hosting/lib/*`
— is not authorized by anything above and does not start until: Phase
19's three-way (interpreter/native x64/WASM) parity bar is met for the
full language, the REPL/`run_ir` prerequisite above is built, and the
acceptance gate's own two conditions are independently verified true.
Given Phase 18's own result this session, that point is genuinely further
away than "one more phase" — stated plainly here rather than implied to
be imminent.

---

## Phase 21 — Call-with-return for ordinary functions

**Realizes:** the real blocker Phase 18 found and precisely diagnosed —
a block-model function can only "return" via a tail call to another
declared block (`JumpBlock`); there is no mechanism for returning a
plain computed value, which real library code needs constantly. This
phase builds that mechanism, generalizing the exact design Phase 19's
own `Emit` already proved (a handler compiled as its own real, separate
FuncIR, reached via ordinary native `Call`), rather than inventing a
new one.

**Correction (2026-09-23, same day, before implementation): the
classification/dual-mechanism design immediately below this note (kept
for the record) was more complex than necessary — found by tracing the
INTERPRETER's own actual execution model concretely instead of
designing purely from the native x64 side's constraints.** The
interpreter (`bi_run`/`bi_run_block`) never concatenates blocks into one
flat array at all — that flattening is a NATIVE-codegen-only artifact
(Phase 9's own optimization). `bi_run`'s own top-level loop is already
exactly "run a block, follow `jump` outcomes, stop at `halt`" — so a
function call with return, for the interpreter, is just an ordinary
RECURSIVE invocation of that same loop (generalized into a new helper,
`bi_run_from`), with recursion handled for free by the host interpreter
(Rust)'s own real call stack — the same mechanism Emit's own recursive
`bi_run_block` call already uses for handlers, just generalized past a
single call. This means, for the interpreter specifically, there is **no
flattened-vs-separate distinction to classify at all** — a function's
`BlockIR` is the same whether reached via `JumpBlock` (existing tail
calls, left completely unchanged) or via a NEW `Call`/`ReturnValue`
instruction pair (value-context calls and non-call `return EXPR`,
respectively) — so the interpreter-side design is purely ADDITIVE, not a
fixed-point classification over the whole program.

**A real, previously-undiagnosed bug was found proving this, not
designed around in advance:** Emit's own existing handler dispatch
(Phase 19) does exactly ONE `bi_run_block` call and treats anything
other than an immediate `"halt"` outcome as an error — but
`block_ir.patlang`'s own header claims "a while loop IS still reachable
inside a handler body for free". Checked directly: a handler containing
a `while` loop hits the FIRST `JumpBlock` (the loop's own back-edge) and
returns a `"jump"` outcome, not `"halt"`, which Emit's own single-call
code then rejects as "attempted to jump to another block -- unsupported"
— a genuine, previously-shipped, silently-wrong claim in that header,
confirmed via a direct repro (a `when` handler with a 3-iteration
`while` loop), not assumed. The new `bi_run_from` helper this phase adds
fixes this for free (it follows `jump` outcomes to completion instead of
erroring on the first one) — Emit's own handler dispatch is rewired onto
it as part of this same phase, not left broken alongside the new,
correctly-built mechanism.

**Revised plan for the interpreter slice (native x64 remains the
dual-mechanism design below, deferred to its own later pass, matching
this project's own established interpreter-before-native cadence):**

- New `bi_run_from(prog, block, locs) -> [value, final_locs]`: repeatedly
  calls `bi_run_block`, following `"jump"` outcomes, until `"halt"`;
  `bi_run` itself becomes a thin wrapper over it starting from the
  program's entry block (an internal refactor, not a behavior change);
  Emit's own handler dispatch calls it instead of a single bare
  `bi_run_block` call (the bug fix above).
- New `ReturnValue` instruction: pops one value, returns `["halt",
  value, locs]` immediately, usable anywhere a block's own instrs
  reach it (mid-body, including nested inside if/else) — `bm_lower_stmt`'s
  own "Return" case falls back to this for any `EXPR` that ISN'T a call
  to a declared block, instead of `bm_lower_unsupported`.
- New `Call` instruction (block-model bytecode, distinct from
  `JumpBlock`): pops args + current `__globals` (in the same "written
  order" convention as `JumpBlock`'s own params), calls `bi_run_from` on
  the named function's own entry block with a FRESH locals set, pushes
  the returned value onto the CALLER's stack, and updates the caller's
  own `"__globals"` local to the callee's returned final globals —
  `bm_lower_expr`'s own "Call" case emits this (instead of rejecting the
  callee as unsupported) whenever the callee is in `block_names`,
  superseding this phase's own earlier defensive-rejection message from
  Phase 18.
- Existing `JumpBlock`-based tail-call sites (`return F(...)`, a bare
  `F(...)` statement) are left COMPLETELY UNCHANGED — zero regression
  risk, since nothing about them needs to change for this to work; a
  function ever ALSO called via the new value-context `Call` mechanism
  is simply the same `BlockIR`, reachable both ways, with no dual
  compilation or classification needed on the interpreter side at all.
- Recursion (direct or mutual) between functions called via the new
  `Call` instruction is expected to work for free, the same way Emit's
  own existing recursive `bi_run_block` call already does (bounded only
  by the HOST interpreter's own real call stack) — a genuine, incidental
  capability gain over the flat model's own inability to recurse at all.
  Verify directly once built, not assumed.

**Native x64 (deferred, not attempted in the interpreter-first pass
above) — original design, kept as still the right shape for when this
is picked up:** classification by call SITE (`bm_lower_expr` vs
`bm_lower_jump_call` reachability, closed under one additional rule: a
function tail-called FROM an already-real function must also become
real, since a separate FuncIR cannot `JumpBlock` into `main`'s own
array — this fixed-point requirement does NOT apply to the interpreter,
only to native's own flattened-vs-separate compilation choice). A
function in that set is compiled ONCE, uniformly, as a real, separate
call/return FuncIR (reusing Emit's own `bm_nc_collect_block_closure`/
`bm_nc_flatten_blocks` machinery) — including at its own tail-call
sites, not compiled twice — returning a real 2-element List `[value,
updated_globals]` via Phase 18's own `BuildList`, destructured at each
call site via `Index`/`CallHost "list_get"`.

**Checkpoint (interpreter slice):** a real, previously-rejected program
shape — a declared function called as a sub-expression, its result used
in further computation (`let x = helper(5) + 1`) — runs correctly
through `bm_lower_program`/`bi_run`, cross-checked against `pat --ir-run`
on the identical source; a `when` handler containing a `while` loop now
runs correctly too (the bug fix above, verified via its own scenario,
not just claimed fixed); recursion between two functions works; zero
regressions in the full interpreter suite. Native x64 codegen for the
new instructions, and re-running Phase 18's own checkpoint (`self_
hosting/lib/zs_schema.patlang`) to find the NEXT real blocker (very
likely closures/classes-with-methods) are this phase's own explicitly
separate, later follow-ups, not attempted in the same pass as the
interpreter slice.

**Interpreter slice done (2026-09-23) — matches the corrected design
above exactly, no further surprises found during implementation.**

- `bi_run_from(prog, block, locs) -> [value, final_locs]` added to
  `interp.patlang`; `bi_run` is now a thin wrapper over it.
- Two new block-model instructions: `Call` (pops args + current
  `__globals`, recurses via `bi_run_from`, pushes the result, updates
  the caller's own `__globals`) and `ReturnValue` (pops one value, ends
  the current `bi_run_block` call immediately with it). `bm_lower_stmt`'s
  own "Return" case now falls back to `ReturnValue` for any `EXPR` that
  isn't itself a tail call to a declared block; `bm_lower_expr`'s own
  "Call" case now emits `Call` for a declared function used as a value,
  superseding this same day's earlier defensive-rejection message.
- Emit's own handler dispatch (Phase 19) is rewired onto `bi_run_from`,
  fixing the real, previously-shipped bug found while designing this
  (a handler containing a `while` loop used to be rejected — see the
  correction note above).
- A real bug was found and fixed in `bm_hash_rewrite_instrs` while
  adding `Call`'s own hash case, the same class already fixed twice this
  session for `BuildList`/`CallHost` (Phase 18) — caught before it
  shipped, not after a confusing runtime failure, by checking every new
  instruction against that function's own per-opcode whitelist as a
  matter of habit now.
- One real bug was found in my OWN first test of this, not in the
  implementation: declaring the helper function before `start` in a
  throwaway repro made the HELPER the program's own entry
  (`bm_lower_program` picks the first declared `Func`), producing a
  confusing "unbound: n" failure that looked like a real bug in `Call`'s
  own arg-binding until traced to the test's own declaration order —
  recorded here as a reminder, not because it affected anything shipped
  (the committed fixtures all declare `start` first, matching every
  other fixture in this tree).

Verified: `native_codegen_check.sh` still 24/24 (native correctly and
cleanly rejects `Call`/`ReturnValue` via the existing `bm_nc_unsupported`
path, confirmed directly rather than assumed — native support remains
explicitly deferred, per the design above); the full interpreter suite
91/91 (up from 87 — the 4 new checks this phase adds, zero regressions).
A declared function called as a sub-expression (`let x = helper(5) +
1`), a direct-recursion factorial, and a `when` handler containing a
`while` loop all now run correctly, cross-checked against `pat --ir-run`
on the identical source where applicable.

*(Update 2026-09-24: both items below are now done — native x64 codegen for
`Call`/`ReturnValue`/`CallDynamic` under #173, and re-running Phase 18's
checkpoint, which is met; see Phase 23. The text is kept as it was written.)*

**Not started, explicitly deferred (unchanged from the design above):**
native x64 codegen for `Call`/`ReturnValue` (the classification-and-
separate-FuncIR design), and re-running Phase 18's own checkpoint
(`self_hosting/lib/zs_schema.patlang` through `bm_lower_program`) to
find the next real blocker (very likely closures/classes-with-methods,
per Phase 18's own remaining named exclusion).

---

## Phase 22 — Re-attempting Phase 18's checkpoint one level further out: `apply()`, a compat-shim bug, a methodology gap, and a foundational blocker found (2026-09-23)

**Goal:** push `self_hosting/lib/zs_schema.patlang` past merely lowering
(Phase 18's checkpoint) toward actually RUNNING its own selftest suite
through block-model — the real, further-out goal named at the end of
Phase 18's own re-attempt. Reached partway; a genuine new architectural
blocker was found and is reported below rather than fixed unilaterally.

**`apply()` / `CallDynamic` — a third, genuinely new call mechanism.**
`self_hosting/lib/test.patlang`'s own Gherkin runner (`run_feature`)
dispatches a matched step to its registered handler via `apply(fname)`,
where `fname` is a STRING computed at runtime (looked up from a
registry), not a literal known at lowering time. Neither `JumpBlock`
(Fork A's own tail-call mechanism) nor Phase 21's new `Call` instruction
can express this — both require a compile-time-literal callee name baked
directly into the instruction. Confirmed `interp_call_host` does not
already support `"apply"` either (isolated test: `["Err", "host function
'apply' not supported..."]`) — this needed a genuinely new instruction,
not another `CallHost` name. Added `CallDynamic` (hash `915129`, no
collision — see `bench/hash_check.patlang`): pops `(fname, __globals)`,
resolves `fname` to a block via `bi_find_block`, runs it with a fresh
locals set via `bi_run_from`, pushes the result, updates the caller's
`__globals`. Deliberately scoped narrowly to match every real call site
of `apply()` in this codebase: zero extra arguments, callee takes zero
declared params beyond `__globals`.

**Compat-shim body-lowering bug (found, fixed).**
`self_hosting/lib/block_model_compat.patlang` (from Phase 18's re-attempt)
provides real-function equivalents of block-model's own sugar names
(`get_global`, `set_global`, `handler_new`, `handler_register`,
`handler_lookup`) — transparent under block-model because every real
call site is always intercepted by a hardcoded name match before any
declared-function lookup runs. `bm_lower_program` was still unconditionally
lowering the BODY of these 5 functions anyway (they're still ordinary
declared `Func` nodes), and their bodies necessarily use raw ambient
`set_var`/`get` — which the Phase 18 ambient-state denylist correctly
rejects. Fixed via new `bm_lower_is_compat_shim_name`, excluding these 5
names from both passes of `bm_lower_program` (block-name collection and
body lowering) — their bodies are provably dead code under block-model.
This incidentally also fixes a latent entry-point bug: with proper
include expansion (see below), these shim functions — textually first via
transitive includes — would otherwise become the wrongly-chosen program
entry (`bm_lower_program` picks the first declared `Func` as entry).

**Ambient-state ports completed for the framework itself.**
`self_hosting/lib/test.patlang` and `self_hosting/lib/gherkin_contracts.patlang`
(the Gherkin runner and its `require`/`ensure` contract-clause handling —
i.e. the framework that actually RUNS `zs_schema.patlang`'s own selftest
suite) are now fully ported from ambient `set_var`/`get("__vars", ...)`
onto `block_model_compat.patlang`'s `set_global`/`get_global`, including
`test.patlang`'s own exact-step registry (previously
`new("Step", text)` + `send(text, "set", "fn", fname)`, now the same
shared Handler-based registry pattern `zs_registry()` already uses).
`self_hosting/schema_bdd_selftest.patlang`'s 5 remaining
`get("__vars", ...)` call sites were renamed to `get_global(...)` to
match; re-verified 5/5 on the real engine (observably identical — these
are thin wrappers over the same `set_var`/`get` calls).

**Verification:** full language spec gate 150/150; block-model spec
suite 96/96 (zero regressions from either `CallDynamic` or the
compat-shim fix); native x64 codegen check still 24/24. Committed as
`5b22750`.

**Methodology finding — an honest correction to earlier claims in this
document.** Every "X.patlang lowers completely" test run this session
(Phase 18's own re-attempt included) used the self-hosted lexer/parser
(`self_hosting/lib/{lexer,parser}.patlang`) directly via
`tokenize(read_file(path))` — which has ZERO handling of `include`
directives. Confirmed via a direct AST dump: `include "foo.patlang"`
parses as `[Expr, [Var, include], 1]` immediately followed by a
parse-error node for the trailing string literal, and `bm_lower_program`
silently ignores both (it only recognizes top-level `"Func"`/`"When"`
statements). This means every prior "lowers completely" claim in this
plan document never actually exercised the CONTENT of that file's own
included files — a real methodology gap in how this phase's own checks
were run, not a claim about the block-model engine's own correctness.
The fix: `self_hosting/lib/includes.patlang`'s existing
`expand_includes(source, base_dir)` (a self-hosted mirror of
`rust-runtime/src/preprocess.rs`, built for exactly this reason — see
that file's own header) must run on the raw source BEFORE
`tokenize`/`parse_program`. Re-verified with real include expansion:
`zs_schema.patlang` and `test.patlang` both still genuinely lower
completely end-to-end (not just their own top-level statements) — Phase
18's own core claim holds, but was previously under-tested.

**Member-access (`.length` and friends) unconditionally assumed a
Box+Handler receiver — found, then fixed the same day, smaller in scope
than first assessed.**
Re-verifying `schema_bdd_selftest.patlang` with real include expansion
got as far as actually attempting to RUN it (not just lower it) — and
caught, via this project's own "verify success signals" discipline, a
false positive: `bi_run_from` on the selftest entry point returned
`RESULT: true` with zero Gherkin output printed. Dumping `t_pass`/
`t_fail` from the returned globals showed `t_pass=0, t_fail=0` — nothing
had actually run; "0 failures" was vacuous, not 5 genuine passes. Tracing
this found the real blocker: `bm_lower_expr`'s `"Member"` case
(`obj.prop`) unconditionally lowers to `Const "prop"` + `Load obj` +
`BoxGet` + `HandlerLookup` — i.e. it always assumes the receiver is a
Box-wrapped Handler-shaped object (the representation Phase 13 built for
class-field access). For an ordinary STRING or LIST (`s.length`, an
extremely common, pervasive PatLang idiom), this is wrong: `BoxGet` calls
`bm_box_read`, which calls `mem_peek_qword(s, 0)` — treating the string's
own tagged value as a raw memory address. `mem_peek_qword` is
native-x64-only (not implemented under `pat --ir-run` at all, an
already-established project fact), so this crashes with `IR runtime
error: host fn 'mem_peek_qword' not found`. Confirmed via a minimal,
standalone repro: `let s = "hello"; print(s.length)` crashes identically
under block-model, independent of `zs_schema.patlang`/`schema_bdd_selftest.patlang`
entirely.

This affects essentially any real PatLang code that uses `.length` (or
any other bare `.prop` access) on a non-Box value, not a narrow edge
case — but it turned out NOT to need the open-ended design decision
first assessed here (a static heuristic? a runtime type tag check?
separate syntax?). Checking the existing, non-block-model compiler
pipeline first (rather than assuming block-model needed to invent
something new) found it had already solved exactly this: the real
self-hosted `lower.patlang`'s own `"Member"` case
(`self_hosting/lib/lower.patlang`, `lower_expr`'s `ty == "Member"` arm)
already special-cases `.length`/`.len` as `CallHost "len"` —  a genuine,
already-"feature complete" host function — falling back to the
Box/Handler-equivalent (`CallHost "get"`, ambient object-field access)
only for every other property name; `codegen_x64.patlang` mirrors this
identically for native. Checking the native x64 string/list memory
layout directly (`x64_len_asm`, `self_hosting/lib/codegen_x64.patlang`)
also confirmed both already carry a real 8-byte length field at their
own `[addr+0]` — native strings are NOT bare pointers needing a
representation change; this was purely a block-model LOWERING gap, one
this project's own existing compiler had already correctly solved
elsewhere, not a foundational representation problem to design from
scratch.

**Fixed the same day**: `bm_lower_expr`'s `"Member"` case now
special-cases `.length`/`.len` to lower straight to `CallHost "len"`
(mirroring `lower.patlang`/`codegen_x64.patlang` exactly), keeping
`BoxGet`+`HandlerLookup` unchanged for every other property name. A real
capability gain incidentally falls out of this too: `.length` now works
under the INTERPRETER for the first time (`CallHost "len"` runs fine
there), where genuine `obj.field` access still correctly requires native
compilation (`BoxGet` remains native-x64-only, unchanged). RED/GREEN
fixtures added (`spec_fixtures/member_length_primitives.patlang` + its
`_reference.patlang` twin), wired into
`spec_library/block_model/library_parity.feature`. Verified: block-model
spec suite 98/98 (up from 96, +2 for the new scenario), full language
spec gate 150/150, native x64 codegen check still 24/24.

A genuinely unrelated, systemic finding turned up while re-verifying
this fix: TWO separate background suite runs this session left an
orphaned `pat.exe` process behind — each still bound to real TCP ports
(one, one; the other, four) — after their own top-level wrapper reported
"completed." This caused real, reproducible port-contention flakiness in
the language spec suite's own signal-claim test (a `FAIL` that
disappeared once the orphans were killed and confirmed gone via
`Get-Process`/`Get-NetTCPConnection`, not assumed from re-running alone).
Matches this project's own documented "Killing backgrounded processes"
gotcha (a wrapper spawning a child that outlives it) — worth flagging as
a recurring pattern for any spec suite involving `spawn()`/cross-process
fixtures, not a one-off fluke, since it happened twice independently in
the same session.

**A fourth, more severe finding — bare-statement declared-function
calls silently dropped every statement written after them.** Re-running
`schema_bdd_selftest_full_run.patlang` (the checkpoint harness built to
push past the `.length` fix) with `t_pass`/`t_fail` correctly read from
the returned `__globals` (not via `get_global` in the driver's own
scope — a completely separate ambient store from block-model's own
internal `__globals` List, a mistake caught before it produced another
false positive) still showed `t_pass=0, t_fail=0` with nothing printed
at all — not even `run_schema_bdd_selftest`'s own first line. Traced to
`bm_lower_stmt`'s own bare-statement dispatch for a call to a declared
function: it ALWAYS lowered via `JumpBlock`, a one-way, non-returning
transfer — correct only when that call is genuinely the very last thing
that ever runs. `run_schema_bdd_selftest` calls `t_init()`,
`register_library_loans_schema()`, `register_library_loans_steps()`,
`run_feature(...)`, `t_report()` as ordinary bare statements in
sequence — reaching the FIRST one (`t_init`) permanently transferred
control away and never returned, silently discarding all four
statements after it, with no error of any kind. Confirmed as a general
bug (not specific to this file) via two minimal, standalone repros:
`a(); b(); print(999)` printed only `a`'s own output; `if true then
helper() end; print(999)` never reached the `print` after the `if`
(the SAME bug, reached through `bm_lower_stmt_list`, which threads no
continuation information through an ordinary if/else branch at all).

Fixed (commit `6ab8efe`): `bm_lower_stmt`'s bare-call dispatch now
always uses the same `Call`+discard convention already established for
`apply()`/the generic `CallHost` fallback; a new special case in
`bm_lower_top_level_stmt_list` (checked before falling through to
`bm_lower_stmt`) keeps using `JumpBlock` for the ONE genuinely safe
shape — a bare call that is provably the very last statement of a
top-level list with no enclosing continuation pending either. Checked
directly, before implementing, that no currently-passing
`native_codegen_check.sh` fixture relies on the removed bug (every
multi-function native fixture already uses `return F(...)`, a genuine
tail call via the other, already-correct call site) — confirmed
empirically after the fix too: still 24/24. Block-model spec suite:
105/105 (two new scenarios added,
`spec_library/block_model/call_with_return.feature`). Full language
spec gate re-confirmed 150/150 in isolation, unaffected.

With this fix, `schema_bdd_selftest_full_run.patlang` gets meaningfully
further — past `t_init()` and into the Gherkin runner itself — but now
hits a NEW, different, NOT-yet-diagnosed error: `contract violation:
assertion failed in bm_interp(): unbound in this block's own pointer:
n`. This is the next real blocker for Phase 18's own checkpoint,
reported here plainly rather than investigated further in this same
pass — each fix so far has revealed exactly one new blocker, and this
is the pattern continuing, not a sign of an ever-receding goal.

**Three more real bugs found and fixed chasing that `unbound: n`
(commit `46c98cc`).** Traced to `bm_lower_while`'s own captured-variable
computation never scanning the loop's own CONDITION expression, only
its BODY — a variable referenced ONLY in the condition (`run_feature`'s
own `let n = sc_len(h); while i <= n do ... end`) was missing from the
head block's forwarded params. Fixed by unioning the condition's own
free variables in too, via the same `bm_fv_expr` analysis already used
elsewhere. Re-running the checkpoint then hit a second, unrelated bug:
`and`/`or` were lowered like every other `Bin` op — eagerly evaluating
BOTH sides, then a plain `Bin` instruction with no case in
`bm_apply_bin` at all — doubly wrong since real PatLang short-circuits;
confirmed via a repro where the RHS's own division-by-zero ran despite
the LHS alone determining the `or`'s result. Fixed by mirroring
`lower.patlang`'s own short-circuit lowering exactly. Re-running the
checkpoint a third time found the deepest of the three: `bm_fv_expr`
itself (the shared free-variable analysis) had no case for `"Index"`
(`obj[idx]`) or `"List"` (`[a, b, c]`) AST nodes at all, so a loop-body
variable referenced only via indexing or only inside a list literal was
invisibly missing from EVERY caller's own captured set, not just this
one checkpoint's own code — found via `self_hosting/lib/list_copy
.patlang`'s own `l[i]` and `self_hosting/lib/pmap.patlang`'s own
`[key, value]`. Fixed by adding both cases (plus `"Member"`,
opportunistically, same root cause). Verified: block-model spec suite
114/114 (up from 105), native x64 codegen check still 24/24, language
spec gate 150/150 in isolation.

**A fourth, materially larger finding — `apply()` with extra
arguments.** With all three bugs above fixed, the checkpoint now runs
past `t_init`, into the Gherkin runner, and genuinely processes its
first scenario (`Feature: Library loans` / `Scenario: Borrowing an
available book` both print for real) before hitting: `CallHost 'apply'
failed: host function 'apply' not supported by interpret_ir`.
`self_hosting/lib/schema_bdd.patlang` calls `apply(invariant_fn,
state_before)`, `apply(require_fn, state_before, inputs)`, and similar
— dynamic dispatch WITH extra arguments beyond the function name, in
VALUE context. This is exactly the extension Phase 22's own
`CallDynamic` design explicitly named as out of scope at the time
("`apply(name, arg1, ...)` is a real, separate, NOT-yet-supported
extension... named here rather than silently assumed covered") — that
scoping check was done before `schema_bdd.patlang` specifically was in
view. Supporting it needs `CallDynamic` (or a new sibling instruction)
to accept N extra argument values, resolve the callee block, read ITS
OWN declared parameter names, and bind each argument positionally
before `__globals` — a real, moderate-complexity feature addition (the
interpreter needs to inspect a resolved block's own parameter list at
runtime, not just its name), not a one-line correctness fix like the
bugs above. Not attempted in this pass — named plainly as the next
piece of real design work, matching this document's own established
practice.

---

## Phase 23 — Closing Phase 18's checkpoint, native call-with-return, and WASM re-verification (2026-09-24)

**Results**

- **Phase 18's checkpoint is met.** Six real, unmodified library selftests —
  `schema_bdd`, `pset`, `pmap`, `step_match`, `zs_expr`, `zs_schema` (177 checks
  between them) — run to completion through `bm_lower_program`/`bi_run_from` with
  real `include` expansion, each printing exactly what `pat --ir-run` prints, with
  pass/fail counts read out of the run's own returned `__globals`. The standing
  gate is `spec_library/block_model/library_selftest_parity.feature` (one scenario
  per selftest, one generic driver, `spec_fixtures/selftest_under_block_model.patlang`).
- **Native x64 call-with-return is done** (#173): `Call`, `ReturnValue` and
  `CallDynamic` now build and run natively.
- **The WASM path is re-verified and repaired** (#174, #181): every opcode set
  except `Box*` and `FiberYield` builds for `wasm32-wasip1` and prints what the
  native build prints; those two are native-only by design and fail at build time
  naming why.

Gates at the end of this phase: block-model suite 166/166, native check 28/28,
WASM check 15/15, language spec gate 150/150, step-text uniqueness check clean.

**Every defect found was filed, reproduced RED, fixed GREEN, and closed under its
own issue** (epic #160):

| Issue | Defect | Found by |
|---|---|---|
| #148 | `.length` on a String/List routed through Box+Handler | first run past `t_init` |
| #149 | bare call to a declared function dropped every later statement | `run_schema_bdd_selftest` did only its first call |
| #150 | while-condition-only variable not captured | `test.patlang`'s `run_feature` |
| #151 | `and`/`or` evaluated both sides, no short-circuit | `run_feature` |
| #152 | free-variable analysis blind to `Index`/`List`/`Member` | `list_copy`, `pmap_put` |
| #153 | `apply(fn, args…)` in value context unsupported | `schema_bdd.patlang` |
| #154 | `""`, `0`, `[]` truthy as a condition (`JumpIfFalse` tested `== false`) | stray `[]` in scenario output |
| #155 | top-level statements silently ignored | every script-style selftest |
| #157 | tail-position bare call returned the wrong shape | `pset`/`pmap` selftests |
| #158 | free-variable analysis blind to `While`/`Assert`/`Match`/`MemberAssign` | `zs_expr` (`ze_msort`) |
| #159 | `sc_substr` missing from the host table | `step_match`, `zs_schema` |
| #181 | WASM path broken since Phase 19 (unconditional `bm_heap_init`) | running the standalone WASM check |
| #156 | lowering is O(n²) in a body's statement count (measured, not blocking) | scaling benchmark |

Four of these are worth stating as lessons rather than just fixes:

- **#157 was a regression I introduced in #149's fix, in a branch no test
  reached.** I kept `JumpBlock` for the provably-safe tail-position case, wrote
  that special case to return a bare instruction list instead of the
  `[instrs, pending]` pair every other return path returns, and shipped it
  described as "a deliberate optimization" with no fixture that ended a body in
  a bare call. The native suite staying green proved nothing about it, because
  no native fixture reaches that branch either. Every special case now gets a
  fixture that reaches it.
- **#158 came from comparing two lists that should have matched.** The
  free-variable analysis covers `Let`/`If`/`Expr`/`Return`; the lowerer handles
  seven statement kinds plus `While`. Diffing the two lists found four uncovered
  kinds at once. #152 had fixed the expression half one node type at a time and
  never made that comparison; when an analysis mirrors a lowerer, check coverage
  of the whole set, not only the case that just failed.
- **#154 was found by comparing output text, not by a failing check.** Both
  engines "passed" the same selftest; only a line-for-line diff of their output
  showed `Scenario: X  []` against `Scenario: X`. The parity gate compares every
  line for that reason.
- **#181 is what an unrun gate looks like.** The WASM check is a standalone
  script, outside the suite and the language gate, and it had been failing every
  scenario since Phase 19 without anyone noticing. Standalone checks are now part
  of the pre-commit gate below, and the check script removes its previous output
  before building, because a stale `.wasm` once made a failed build look like a
  passing run.

**Design decisions made on the way**

- *Top-level statements* (#155): every non-declaration top-level statement is
  collected, in order, into a synthesized zero-parameter `__main`, lowered like
  any function body, and made the entry only when such statements exist.
  Anything at top level the lowerer cannot handle fails loudly; an un-expanded
  `include` gets its own message, since that was the real way content used to
  vanish.
- *Host functions* (#159): `interp_call_host` lives in
  `self_hosting/lib/interp.patlang`, one of the four files this plan protects
  until the cutover. A host function it lacks is added to a block-model-local
  table (`bi_call_host_extension`), consulted only after the shared table returns
  an error so the success path pays nothing. The table grows only on evidence.
- *Free-variable analysis of `Match`* over-approximates (pattern-bound names are
  not removed from the free set): it can capture something unneeded, never miss
  something needed, and captures are intersected with the enclosing scope anyway.
- *Native call-with-return* (#173), generalizing what `Emit` already does for
  handlers: every function that is the target of a `Call` gets its own separate
  FuncIR (`bm_fn_<name>`) holding its whole `JumpBlock`-reachable family of
  blocks and returning `[value, final_globals]`, which the call site unpacks (the
  value stays on the stack; the globals go back into the caller's own
  `__globals`, so Fork B's threading survives a real call boundary). Inside a
  callee every block ends with an explicit halt returning
  `[unit, its own __globals]`, because a block running off its own end is a halt
  in the interpreter and must never fall through into whichever block happens to
  follow in the flattened array. `CallDynamic` dispatches on the runtime name
  with an `rt_str_eq` chain, like `Emit`'s event dispatch.
  Building it exposed one thing the plan's design did not anticipate: `main` held
  every block not owned by a handler, harmless while every function was reached
  by `JumpBlock` (whose stores bind the callee's parameters) but wrong for a
  function reached only by a `Call`, whose parameters are bound at no site inside
  `main` — `codegen_x64`'s undefined-variable check correctly rejected `main`'s
  dead copy of it. `main` now holds exactly the blocks reachable from the entry.
- *WASM retargeting* (#174): one rewrite pass at the end of flattening, applied
  only when the translator targets the Rust-source backend, maps each x64-runtime
  call (`rt_list_len`/`get`/`push`, `rt_str_eq`, and the runtime-defined `fact`,
  `query`, `type_of`, `read_file`, `write_file`) to its ordinary host equivalent,
  one instruction for one so no jump target moves. `Box*` and `FiberYield` stay
  native-only and fail at build time.

**Tooling added.** `self_hosting/block_model/run_one_feature.patlang` runs one
feature file (with one or several comma-separated step registrations) for fast
per-issue verification, since the full suite takes about 35 minutes, mostly native
compiles. `self_hosting/block_model/tools/check_step_texts_unique.sh` guards a
silent hazard in the Gherkin runner: the exact-step registry is keyed by step
text, and re-registering a text replaces the earlier registration with no error,
so two features sharing a phrase quietly run the wrong check. That nearly
happened twice while adding these scenarios. Each new step registration is now
self-contained (it registers the shared `st_noop` steps it uses) so a feature can
be run alone.

**Pre-commit gate** (all must be green; the first is the slow one):

1. `rust-runtime/target/release/pat.exe --ir-run self_hosting/block_model/run_block_model_spec_suite.patlang`
2. `bash self_hosting/block_model/tools/native_codegen_check.sh`
3. `bash self_hosting/block_model/tools/wasm_codegen_check.sh`
4. `rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/run_language_spec_suite.patlang`
   (run it alone — it holds real TCP ports, and running it beside another suite
   made its signal test fail spuriously)
5. `sh self_hosting/block_model/tools/check_step_texts_unique.sh`

**Practice worth keeping.** The full suite spawns a fresh process per fixture, and
each reads `lower.patlang`/`interp.patlang`/`free_vars.patlang` from disk when it
starts, so editing them mid-run silently contaminates the run (feature files too:
each is read when the suite reaches it). Development during a long run goes in a
scratch copy of the engine files, and results are ported back afterwards as a
reviewed set of hunks, diffed with `--strip-trailing-cr` because the working tree
is CRLF.

**Not in the parity gate, and why.** `zs_refine_selftest`: its `zs_explore`
dependency keeps a visited-set `Dict` and abort/progress flags in ambient state.
The flags are a mechanical port; the visited set is a design question (an
assoc-list would make exploration quadratic in the real engine as well), tracked
in #179.

**GOAP rule and goal declarations (#177, first slice).** Phase 15 deferred `rule`
and `goal` because they build compound `[pred, [args…]]` lists, which needed
`BuildList` (Phase 18). Both now lower exactly as the real lowerer's own arms do
— every argument a compile-time string token, ending in `CallHost rule_add 3` /
`CallHost goal_def 2` — and `rule_add`, `goal_def`, `solve`, `plan`, `pursue` and
`action_add` are served from the block-model host extension table (#159), since
the shared table lists logic among its exclusions. A program declaring a rule and
a goal, then calling `solve` and `pursue`, prints the same solution count, binding
and plan length as `pat --ir-run`. As with `fact`/`query`, the rule/goal/action
stores are process-wide thread-locals outside `__globals`, the gap Phase 15
recorded. `activate` and `action_bind` are covered in the closures paragraphs
below. Interpreter only: native `CallHost` enforces an OS-boundary allowlist that
these names are not in.

**First-class closures (#182).** Methods (#175), `budgeted` (#176) and `activate`
(#177) all needed closures, so they came first. The real engine snapshots the
whole enclosing scope at creation, which is by-value capture and fits Fork B
naturally: `let snap = 100; let show = |u| { return snap }; let snap = 200` then
`show(0)` is 100 under both engines. A closure is the list
`["__closure", block_name, [captured…]]`. Creating one synthesizes a function
block `__closure_N(__captured, params…, __globals)` whose prologue unpacks each
captured name with `list_get`; the captured set is the body's free variables
intersected with the names the enclosing function binds. Blocks synthesized inside
an expression go in a compile-time registry that `bm_lower_program` drains, the
pattern `bm_class_registry` already uses. A call `f(a)` where `f` is a parameter or
`let` of the current function lowers to `apply(list_get(f, 1), list_get(f, 2), a)`
over the existing `CallDynamic`. The free-variable analysis gained a `Closure`
case, and it now counts a call's callee name as a variable reference, since a
closure held in a local and only ever called was otherwise never captured or
forwarded through a loop. Verified against `pat --ir-run` (`15 7 21 100 7`, and a
loop total of 309). Native and WASM followed in #183: native `CallDynamic` dispatches
over declared functions, and a synthesized `__closure_N` block is now callable there
too (`bm_nc_is_callable_name`), getting its own callee FuncIR and a slot in the
`rt_str_eq` chain; every other `__` block stays non-callable. Both closure programs
print the same values natively and under wasmtime as under `pat --ir-run`.

**`activate` (#177, second slice).** The real lowerer does not treat `activate` as
a host call, because host functions cannot call back into the interpreter. It
synthesizes ordinary `Let`/`While`/`If`/`Call` AST that walks the plan, finds each
step's bound closure with `action_lookup`, and calls it through a variable.
Block-model applies the same rewrite to a body before lowering, for the two shapes
the real lowerer recognizes (`let x = activate(P)` and a bare `activate(P)`), and
serves `action_bind`/`action_lookup`/`action_base_name`/`action_label_args` from the
host extension table. Result: `true` when every bound closure returns true, `false`
when one is re-bound to fail, as under `pat --ir-run`.

**Still open, all tracked on the board (epic #160):** methods, inherits and traits
(#175, blocked on an owner decision about mutation semantics, since real objects are
ambient named references and block-model values are records); `budgeted`/threads
(#176); `signal_*` (#178); the `zs_explore` port (#179);
lowering's O(n²) statement-count cost (#156); and the cutover itself
(#180), which is designed but not authorized.

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
