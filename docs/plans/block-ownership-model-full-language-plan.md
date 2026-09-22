# Block Ownership Model: full-language expansion plan

**Status (2026-09-22): Phases 10–17 (event dispatch, pattern matching,
design by contract, object orientation, cooperative fiber_yield, logic-
programming facts, numeric tower, system integration) complete and
verified — `self_hosting/block_model/run_block_model_spec_suite.patlang`
reports 83/83 passing, no regressions. Phase 18 (library-level parity)
was genuinely attempted and genuinely fails, as real, checked evidence
of how much further coverage remains — not a completed checkpoint; see
its own section for the exact failure and what it traces to. Phase 17
also corrected a wrong premise in this plan's own text (there is no
generic `CallHost` dispatch in this engine at all — every host function
needs individual recognition, the same as every earlier phase's own
host-function work). Phase 20 (migration/cutover design) is also written
now, ahead of Phase 19 as the plan itself permits — its own real
decisions (a hard switch, gated on both full-suite parity and issues
#145/#113 actually being fixed, not waived) are recorded, and acting on
them is explicitly not yet authorized. Phase 19 (consolidated native x64
+ WASM codegen) was investigated twice this session: an initial 18-opcode
estimate turned out wrong on closer check — 6 of those opcodes
(`fiber_yield`/`fact`/`query`/`type_of`/`read_file`/`write_file`) have
literally zero native x64 support today (confirmed by direct grep, not
assumed from `pat --patc`'s different backend), and Box's own
`heap.patlang` isn't bundled into the one real native-build driver this
project has at all. Corrected scope: 11 achievable opcodes
(`Box*`/`ContractFail`/`Global*`/`Handler*`) plus a real build-plumbing
prerequisite (bundle `heap.patlang`), with the other 7 opcodes deferred
as needing genuinely new runtime primitives — not implemented this
session either way, to avoid rushing untested native-codegen changes
past this plan's own RED/GREEN discipline. Phase 13 also found and
fixed two real,
pre-existing bugs (`HandlerRegister`'s append-only behavior, and its own
downstream exposure of already-filed issue #145's native x64 `list_set`
aliasing bug) — see Phase 13's own section below for the full account.
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
Phases 18–20 below are not built yet.**

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
scenario does. **Not remedied here** — doing so would mean building
List-literal support and generic host-call dispatch, which are Phase 17's
own already-named, separately-scoped follow-ups, not this phase's job.
This phase's own result stands as recorded evidence of how much further
coverage a genuine drop-in claim would need, not a completed checkpoint.

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
