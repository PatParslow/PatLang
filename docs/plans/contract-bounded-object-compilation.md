# Contract-bounded object compilation

**Status (2026-10-25): proposed, not started.** Distilled from a design
note the project owner shared in-session, arguing that PatLang should
define "an object may observe another object only through that object's
contract" as the one non-negotiable rule compilation is built around,
rather than treating independent compilation as an optimization bolted
onto the existing whole-program pipeline. **Nothing in this document
should be started before the in-flight GitHub #223 investigation (the
`rt_str_eq`-vanishes-from-`symbols` corruption, found while re-verifying
#222's own fix during a full Gen B self-compile) is root-caused, fixed,
verified, and committed.** That bug is itself the motivating case for
this plan (see §1) — finishing it first is not just sequencing hygiene,
it is the concrete evidence this design should be judged against.

## 0. Relationship to existing plans

- **Distinct axis from `block-ownership-model-swarm-compilation.md`**:
  that plan is about how the *compiler* parallelizes and caches its own
  work (compile-time artefacts, content-hashed compilation islands,
  worker pools). This plan is about what a *running PatLang program's*
  objects are allowed to know about each other — a language/runtime
  semantics change, not a build-pipeline change. The two are
  complementary, not competing: SwarmCompile's own central proposition
  ("a well-structured PatLang program already exposes its state topology
  through parameters, closures, receiver objects, and narrow
  capability-bearing objects, not ambient mutable globals") is an
  *assumption* SwarmCompile makes about well-structured programs. This
  plan is how PatLang would make that assumption actually true by
  construction, instead of true only when a program happens to be
  written carefully. SwarmCompile's own artefact/work-unit model
  (content-hashed `CompileUnit`s, `ChunkImage` fragments) is the natural
  target architecture for compiling contract-bounded objects in parallel,
  once contracts exist — Phase 4 below is explicitly SwarmCompile's own
  `CompilationRequest`/`CompilerWorker` shape, reused rather than
  reinvented.
- **Builds on** `general-refcounting.md`'s Phase 1-4 (string and list
  refcounting under the native x64 backend) and `block-ownership-
  model.md`/`block-ownership-model-implementation-plan.md` (the
  block/continuation lowering `bm_patc_lower` already performs). A
  contract's `ownership` clause (see §2) is a *language-level surface*
  for exactly the ownership transitions that machinery already computes
  and enforces today, just currently inferred from dominance analysis
  after the fact rather than declared up front and checked against.
- **The motivating bug, concretely**: this session spent many hours
  tracing a single symbol (`rt_str_eq`) silently vanishing from a growing
  `symbols` list inside the self-hosted assembler's `state` object
  (`self_hosting/lib/x64_asm.patlang`'s `xa_declare_symbol`/`xa_record_
  reloc`, backed by `x64_runtime.patlang`'s `rt_ns_push`/`rt_ns_get`).
  `rt_ns_push` itself was proven clean by direct instrumentation (every
  individual push verified internally consistent, exhaustively, across
  tens of thousands of calls) — yet the final read showed the entry gone,
  with mass duplication elsewhere in the same structure. Whatever the
  root cause turns out to be, the *architectural* shape of the bug is
  exactly what §1's quoted design note calls "an entire category of
  hidden whole-program dependency": `xa_new_state`'s own `state` object
  is not actually encapsulated — every field lives in one process-wide
  `__vars` table (`mem_vars_table_addr()`), keyed by a string name, with
  no enforced boundary between "this object's own state" and "every
  other object's own state" other than programmer discipline in choosing
  non-colliding keys. A contract-bounded object would not have a
  *choice* about this: its state would only be reachable through its own
  compiled accessors, never through a shared global table walked by
  linear string comparison.

## 1. Core principle (unchanged from the source note)

```
compile(
    object_implementation,
    own_contract,
    imported_contracts,
    target_contract
) -> compiled_object
```

No compiler operation may inspect an imported implementation — only its
contract. A contract must be complete enough to compile both its own
implementation and every caller against it: provided operations, argument
and result shapes, ownership/mutation rules, effects, and (where stated)
pre/postconditions.

## 2. What a PatLang contract actually needs to express

Adapting the source note's sketch to constructs that already exist or
are already planned in this codebase:

- **provides** — callable operation names and arities. PatLang already
  has this implicitly via `class_def_register`/`class_method_lookup`
  (`x64_runtime.patlang`); a contract makes it an explicit, checkable
  surface instead of "whatever methods happen to be registered."
- **state** — which fields exist, in what representation class (value vs
  reference), without committing to layout. This is new; PatLang objects
  today (`new("ClassName", ...)`) have no declared state shape at all,
  only whatever `rt_ns_set` calls happen to have run against them.
- **ownership** — reuses `general-refcounting.md`'s own vocabulary
  (`rc_inc`/`rc_dec`, exclusive vs shared access) as the contract-level
  surface for what `bm_nc_insert_string_rc_decs` and friends already
  compute today. A contract's `ownership` clause would be what the
  dominance passes are checked *against*, not just inferred from.
  Directly relevant to this bug: a contract for `xa_new_state`'s object
  would have to say which fields are exclusively owned vs shared, making
  "every field lives in one shared table with no ownership distinction
  at all" a contract violation the compiler could reject, rather than an
  invisible design choice nothing checks.
- **effects** — pure vs mutating vs I/O, reusing the same vocabulary
  `general-refcounting.md` and `block-ownership-model.md` already use
  informally in their own comments.
- **requires/ensures** — out of scope for an initial phase (PatLang has
  no contract-check runtime today beyond `contract_check`/`rule_add`'s
  logic-programming machinery, which is a different feature and should
  not be conflated with this).

## 3. Phased plan

### Phase 0 — Design only, no implementation (this document plus a follow-up)

Write the actual contract grammar as a lexer/parser extension proposal
(new keywords: `contract`, `provides`, `state`, `ownership`, `effects`;
possibly reusing `class`'s existing keyword rather than adding `object`
as a second, overlapping concept — **Fork A below, undecided**). No
code changes. Exit criterion: a worked example translating one *real*,
already-existing object in this codebase (candidate: `xa_new_state`'s own
`state` object, precisely because it is this session's own motivating
bug) into contract form by hand, checked against what `xa_declare_symbol`
/`xa_record_reloc`/`xa_push_bytes` actually do with it today.

### Phase 1 — Boundary adapters for ONE existing hot spot, opt-in, parallel to the existing compiler

Pick the single most isolated candidate object in the self-hosted
compiler's own source (not a user-facing language feature yet) and give
it a hand-written contract plus a hand-written boundary adapter, without
touching the lexer/parser/lowering pipeline at all — prove the adapter
shape compiles and links correctly against the *existing* `--x64`
backend as plain PatLang functions, before asking the compiler to
generate anything. `xa_new_state`'s object is again the natural
candidate: replace the shared `__vars`-table-backed `send(state,"push"/
"set",...)` calls with a small set of per-field accessor functions
closing over a locally-allocated, non-shared structure (a real `rt_list_
new`-backed record, not a `rt_ns_*`-indexed string-keyed table entry).
If this alone resolves or changes the character of the current bug,
that is strong independent evidence for the design's central claim, not
just a nice-to-have.

### Phase 2 — Contract syntax in the lexer/parser, checked but not yet enforced at link time

Add the grammar from Phase 0 for real. Compiler validates a contract's
internal consistency (no duplicate provides, ownership clauses reference
real state fields) but does not yet reject a caller that bypasses it —
existing code keeps working unmodified throughout (**hard constraint**:
the self-hosted bootstrap cannot have a flag day where old `.patlang`
files stop compiling).

### Phase 3 — Link-time contract checking

`x64_link`/`x64_pe_link.patlang` (already the place that merges compiled
chunks today) gains a contract-compatibility check alongside its
existing symbol-table merge: a caller's required contract hash must
match a provider's own declared contract hash before a relocation is
allowed to resolve, exactly mirroring this plan's §"proof-carrying
object artefacts" idea but scoped to what `x64_link` already does
mechanically. This is also the natural point to retire the global
`__vars` table for any object that has migrated to a contract, replacing
`rt_ns_push`/`rt_ns_get`'s shared-table lookup with direct, contract-
generated field accessors — removing the exact class of bug this session
chased, not just adding a check on top of it.

### Phase 4 — Parallel/distributed compilation via SwarmCompile's own artefact model

Once contracts exist, a `CompilationRequest` (implementation + own
contract + imported contracts, content-hashed exactly as `block-
ownership-model-swarm-compilation.md` §4-5 already specifies for
`CompileUnit`) becomes the unit SwarmCompile's own worker pool consumes.
No new scheduling design needed here — this phase is "point SwarmCompile
at contract-bounded objects instead of at individual functions," reusing
that plan's existing content-hash/cache-validation discipline unchanged.

### Phase 5 — Migrate existing self-hosted compiler modules

Only after Phases 1-4 are proven on real code: give `x64_asm.patlang`'s
other `state`-shaped objects, `x64_compile_unit.patlang`'s `CompileUnit`/
`ObjCache`, and similarly-shaped ad hoc objects elsewhere real contracts,
removing shared-table (`__vars`) access as the default pattern for new
object-shaped code project-wide.

## 4. Decisions needed (genuinely undecided, not to be guessed)

### Fork A — Extend `class` or add a new `contract`/`object` pair of keywords?

PatLang already has `class`/method/trait support (`class_def_register`,
`class_method_lookup`). A contract could be (a) a new declaration
attached to an existing `class`, or (b) a wholly separate `contract`
construct that any implementation (class-based or not) can satisfy, as
the source note's own examples assume (`object Counter satisfies
Counter`). (b) matches the source note and composes more cleanly with
non-class objects (closures, the `xa_new_state`-style ad hoc records this
plan's Phase 1 targets first) but is a bigger surface-area addition.
**Leaning (b), not yet decided.**

### Fork B — Does Phase 1's boundary adapter need a runtime "contract witness" value, or is it purely a compile-time fiction?

The source note's `compiled_object` output includes a "contract hash" and
"witnesses" as data the *linker* checks. For Phase 1 (hand-written,
pre-grammar), there is no automated link-time check yet, so the honest
answer is "compile-time fiction, nothing to carry at runtime, yet." Needs
a real decision once Phase 3 exists: does every contract-satisfying
object carry a small runtime tag (cheap, but adds a field to every such
object), or is contract compatibility purely a link-time, build-artifact
concern with zero runtime footprint (cheaper, but means a contract
violation introduced by, e.g., dynamically loading a mismatched compiled
unit at runtime can't be caught)? **Undecided — depends on whether
PatLang ever needs to load contract-bounded compiled units it didn't
link itself**, which ties into the deferred cross-machine trust question
already flagged in this project's own ecosystem-vision notes (cert-
based/zero-trust preferred, not yet built).

### Fork C — Scope of Phase 1's first target

This document proposes `xa_new_state`'s object specifically because it
is the live bug. An alternative is to pick a *simpler*, less load-bearing
object for the very first proof (lower risk of the proof-of-concept
itself becoming another multi-day debugging session). **Leaning toward
doing it on `xa_new_state` anyway**, since a toy example would not
generate the evidence this plan's §0 says it should generate — but this
trades a clean first demo for directly testing the hypothesis against
the hardest available case. Revisit once Phase 0's worked example
(§3 Phase 0) makes the actual size of that rewrite concrete.

## 5. Explicitly out of scope for now

- Full `requires`/`ensures` behavioural contracts (a verification
  feature, not a compilation-architecture one — would reuse
  `contract_check`/`rule_add` machinery if ever built, kept separate).
- Any change to the Gen A bootstrap path (`codegen.rs`/`rustc_build_
  chunked`) — contracts are a self-hosted-pipeline concern only, per this
  project's own standing rule that Rust stays a correctness mirror, never
  a design target.
- Distributed/cross-machine compilation workers — Phase 4 reuses
  SwarmCompile's existing single-machine worker-pool assumption; nothing
  here revisits the deferred cross-machine trust question.
