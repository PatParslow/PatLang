# Generalizing refcounting beyond Box: a staged plan

**Status (2026-10-19): proposed, not started. Nothing in this document is
implemented yet.** Companion to the Block Ownership Model's own
`docs/plans/block-ownership-model.md` (Fork D) and
`block-ownership-model-implementation-plan.md` (Phase 1), which this reuses
and extends rather than replaces.

## 1. Why

The native x64 runtime's general-purpose heap (`rt_heap_alloc`,
`x64_runtime.patlang`) is a pure bump allocator: a global offset,
atomically advanced per allocation, with more virtual memory committed via
`VirtualAlloc` as the offset grows past what's already committed. It never
reuses memory. Every ordinary List, String, Dict, closure, and boxed
numeric-tower value a native program creates adds to that offset forever,
regardless of how long the object actually lives. For a short CLI script
this is invisible (the process exits before it matters); for anything
long-running it is the same problem Fork D's own write-up names for Box
specifically (`block-ownership-model.md` §1) -- just not fixed for
anything *other* than Box.

Only Fork D's own `heap.patlang` has real reclamation today, and only for
Box objects: a refcount header, `rc_inc`/`rc_dec`, and a size-keyed free
list that keeps the heap's high-water mark flat across repeated
alloc-then-drop cycles. Confirmed while scoping this (not assumed):
`rt_list_push`'s own "mutate in place when safe" optimization is a
*different*, narrower mechanism -- a shared-buffer "node" with its own
aliasing flag, not a refcount, and specific to Lists' own amortized-growth
story. Strings have no equivalent scheme at all: `rt_str_concat` is a
flat `rt_heap_alloc` call with a length header, nothing clever, and
strings are immutable (every concatenation allocates a fresh result, never
mutates one in place). Generalizing Fork D's mechanism to more types is
therefore not "extend an existing broad thing" -- it's "build the same
narrow thing again, once per type, each with its own real design
questions," and should be staged exactly that cautiously.

## 2. Decisions

### Fork F -- generalize Fork D's own mechanism, or build a parallel one

**Decided: generalize.** `heap.patlang`'s refcount header and size-keyed
free list are already proven (Phase 1 of the BOM implementation plan,
re-confirmed working throughout this branch's own later phases). Making
`bm_alloc`/`bm_rc_touch_for_mutation`/the free list take an arbitrary
payload shape instead of Box's fixed one-value shape is lower-risk than
inventing a second allocator with its own bugs to find.

### Fork G -- does this touch Lists' own node/aliasing scheme

**Decided, for now: no.** Lists already have a working, subtle,
amortized-growth-preserving scheme that has nothing to do with
refcounting. Converting Lists to refcounting proper would mean reconciling
two different "is this safe to mutate/reclaim" mechanisms in the same
type -- real work, real risk, and not needed to get the bulk of the
benefit. Lists are explicitly **out of scope** for this plan's own phases;
revisit only after Strings (the first real type below) is proven, and
only as its own separate, later plan if it's still wanted then.

### Fork H -- where do `rc_inc`/`rc_dec` get inserted

**Decided: reuse the existing per-instruction taint-propagation shape**
`x64_analyze_dynamic_bins`/`x64_analyze_float_bins` already use (fixed-
point forward propagation over a function's own instructions,
`codegen_x64.patlang`) to find which specific locals are provably
string-valued, rather than inventing a new analysis style. For *where*
within that a decrement belongs, reuse the same last-use/move-eligibility
question `codegen.rs`'s own `FnPrecomputed::move_ok` already answers for
a different purpose (found and used directly in this session's #214
fix) -- "is this the last read of this local before it's overwritten or
the block ends" is the same question a correct `rc_dec` insertion point
needs answered. Two already-proven analyses in this codebase, reused for
a third purpose, not a new kind of static analysis risk.

## 3. Phases

Mirrors the BOM implementation plan's own structure deliberately: each
phase proves one thing, standalone, before the next phase depends on it.
RED (a `.feature` scenario first) before GREEN (implement), same standing
discipline as everywhere else in this codebase.

---

### Phase 0 -- Scaffolding

Branch, a `spec_library/refcounting/` + `self_hosting/refcounting/` tree
(or extend `self_hosting/block_model/` directly -- an open question for
whoever starts this, not decided here), one smoke scenario proving the
harness runs. Realizes nothing yet.

---

### Phase 1 -- Generalize `heap.patlang`'s allocator, no real type touched

Take `bm_alloc`/`rc_inc`/`rc_dec`/`bm_rc_touch_for_mutation` and the
size-keyed free list, and make them accept an arbitrary byte size instead
of Box's fixed shape. Proven via a standalone driver (mirroring
`x64_heap_rc_driver.patlang`'s own pattern), with scenarios identical in
spirit to Fork D's own Phase 1 checkpoint: allocate at various sizes,
share, drop, confirm flat heap-bytes-used across many cycles at each size
class. **Zero change to `codegen_x64.patlang`, `x64_runtime.patlang`'s
existing String/List functions, or anything a real program currently
exercises** -- this phase is purely additive, the lowest-risk step in the
whole plan.

**Checkpoint:** the generalized allocator passes the same class of proof
Fork D's own Phase 1 did, at multiple size classes, not just Box's one.

---

### Phase 2 -- Strings, the first real type

Strings are the narrowest real target: immutable (no "job 1," the
mutate-in-place-vs-clone question, ever applies -- only "job 2,"
reclamation), and no competing scheme to reconcile with (unlike Lists).

- `x64_analyze_dynamic_bins`-style taint pass, scoped to find
  provably-string-valued locals within one function (reusing the existing
  shape per Fork H, not a new analysis).
- `rc_inc` at every point a string value is copied into a new binding
  (Store to a different local, pushed as a call argument, returned,
  stored into a List/Dict element) **that this pass can prove is a copy**
  -- anywhere it can't prove it, fall back to the current behavior
  (no refcounting, current bump-forever semantics), the same "prove it or
  fall back, never guess" shape Fork C's own flight check already
  established for `mut`-exclusivity.
- `rc_dec` at the last-use point `move_ok`-style analysis identifies, and
  at ordinary function-local scope exit for anything not already
  decremented.
- `rt_str_concat`/wherever else strings are currently allocated via plain
  `rt_heap_alloc` switch to the Phase 1 allocator.

**Checkpoint:** a benchmark building and discarding many short-lived
strings in a loop (string-concatenation-heavy code, the same shape
`bench_strconcat.patlang` already exercises) shows flat heap-bytes-used
instead of linear growth, the direct, measurable proof -- not just "it
still prints the right thing," though that must hold too, checked against
`pat --ir-run` on the same source for every scenario.

**Explicit non-goal for this phase:** anything beyond provably-local
string values within one function. A string captured by a closure,
stored in a global, or passed through `apply`/`CallDynamic` falls back to
current behavior -- narrower coverage, not a correctness risk, matching
this session's own #215 fix pattern (conservative by construction
whenever something can't be proven statically).

---

### Phase 3 -- Closures

Closures are a plausible second target: frequently allocated inside hot
loops (a closure literal created fresh each iteration), fixed-size once
captured, never mutated after creation. Whether this phase is worth doing
at all depends on Phase 2's own measured benefit and real profiling of a
representative program -- not assumed necessary here, scoped only as "the
next candidate if Phase 2 proves the mechanism worth extending."

---

### Phase 4 and beyond -- Lists, Dicts, numeric-tower boxed values

Each would be its own phase, each requiring its own design pass (Lists
specifically need Fork G's own deferred question answered first). Not
scoped in detail here; this plan stops at "the mechanism is proven and one
real type benefits from it," matching the BOM plan's own precedent of
treating "native codegen for the engine" (its Phase 9) as deferred detail
until the earlier phases justified it.

## 4. What this plan deliberately does not cover

- Lists' own node/aliasing scheme (Fork G) -- a real, separate design
  question, not answered here.
- A general type-inference or escape-analysis system. Phase 2's own taint
  pass answers one narrow question ("is this local provably a string")
  the same bounded way the flight check answers "is this reference
  provably unique," not a general soundness-for-everything system.
- Any change to `pat --ir-run`'s or `pat --patc`'s own heap behavior --
  scoped to the native x64 backend specifically, same boundary this
  session's #214/#215 fixes already drew.
- Merging any of this into `main` before it's built and proven, per the
  same branch-discipline note the original BOM plan opened with.
