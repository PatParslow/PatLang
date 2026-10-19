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

**Status: done, with no code change needed.** Re-reading `heap.patlang`
while scoping this plan found `bm_alloc`/`bm_rc_inc`/`bm_rc_dec`/
`bm_rc_touch_for_mutation` and the size-keyed free list already take only
a byte size, never a payload shape -- only `bm_box_read`/`bm_box_write`
(simple convenience accessors nothing else calls) assume Box's specific
one-field layout. Proved rather than assumed: a new scenario in
`refcounted_heap_native_check.patlang`/`refcounted_heap.feature`
allocates, shares, drops, and reclaims a 3-field packed struct a Box
never uses, through the exact same functions, with zero new or modified
allocator code -- already committed. Fork F's own decision ("generalize
Fork D's mechanism") turned out to already be satisfied by Fork D's own
original design.

**A second, real bug turned up while re-verifying this checkpoint, fixed
in the same pass.** `heap.patlang`'s own lock-free fast path
(`bm_heap_fixed_ready`: "is the free-list table the heap's first
allocation, so every thread finds it with no lookup at all") depends on
genuinely being first -- but `bm_to_real_funcir` (native_codegen.patlang)
used to call `bm_heap_init()` *after* seeding `main`'s own `[BuildList,
0]` `"__globals"`, which is unconditionally the very first thing any
compiled program's `main` does. That seed had therefore always already
claimed the heap's first allocation, for every real program, making the
fast path structurally unreachable outside `refcounted_heap_native_
check.patlang`'s own standalone, heap.patlang-is-the-only-thing test.
Every `bm_alloc`/`bm_rc_inc`/`bm_rc_dec` call fell through to the slow,
lock-plus-`"__vars"`-lookup path instead -- measured directly at roughly
700x slower per alloc+drop cycle (5,000,000 cycles: 62ms expected-shape
vs. 43,656ms measured). This wasn't yet live/user-facing: the ordinary
`./patc1.exe --x64` CLI path doesn't currently link `heap_chunk.obj` at
all, so `box_new` fails to link outside block-model's own test tooling
(`build_native.patlang`) -- but it would have gone live the moment this
plan's own Phase 2 (or anything else) wired `bm_alloc` into a real
compiler path, so fixing it now rather than inheriting it was the right
call. Fixed by calling `bm_heap_init()` *before* the `__globals` seed;
verified via a deterministic fixture (checks the free-list table's own
magic marker directly, not a timing measurement) and a scaling check
(500k/1M/2M box_set/box_get cycles: 32ms/37ms/49ms, linear).

**A third prerequisite, found starting Phase 2's own first increment:**
Phase 2 needs `bm_alloc`/`bm_rc_inc`/`bm_rc_dec` available to ORDINARY
compiled programs, not just block-model's own test tooling -- and
`box_new`'s own LINK ERROR above is exactly that gap, confirmed directly:
the ordinary `--x64` CLI never links `heap_chunk.obj` at all (only
`build_native.patlang` does). Fixed the cleanest way available:
`build_x64_runtime.patlang` now concatenates `heap.patlang`'s own source
into what it compiles into `x64_runtime.obj` (already linked into every
native program), rather than building new multi-chunk-linking
infrastructure for the ordinary CLI -- zero change to either file's own
content, so `interp.patlang`'s own `include "heap.patlang"` (the
interpreter's path, source-level inclusion, not link-time resolution)
keeps working completely unchanged. `patc1_main.patlang`'s own
independent fingerprint check (which must agree with
`build_x64_runtime.patlang`'s, per that file's own header) updated to
match. `box_new`/`box_get`/`box_set` now work through the ordinary CLI
for the first time; block-model's own now-redundant `heap_chunk.obj`
third-chunk linking (`build_native.patlang`/`build_and_run_native.sh`)
was simplified away. Verified: `native_codegen_check.sh` (39/39,
including a new scenario for this exact capability),
`refcounted_heap_native_check.patlang` (13/13), and the real-threads
stress test (`thread_safety_check.sh`, 5/5) all still pass.

One known, minor, non-blocking gap left open: `patc1_main.patlang`'s own
collision check ("a name defined both by this program and by
x64_runtime.patlang's own shadowing primitives") doesn't know
`heap.patlang`'s content is now folded into `x64_runtime.obj`, so a
program that both `include`s `heap.patlang` AND relies on the runtime's
copy wouldn't be flagged if the two ever diverged in a way that mattered
-- not a live bug today (confirmed: a program's own `include`d copy
simply shadows the runtime's at link time, same as any other symbol,
and `x64_runtime.obj`'s own internal cross-references stay self-
consistent regardless, since it's a pre-linked, self-contained object),
but worth tightening if this pattern grows.

Also adopts a design idea raised at this point, worth keeping in mind
for Phase 2's own implementation (see below): since string producers
should funnel through one canonical low-level constructor rather than
each calling `rt_heap_alloc` directly, the SAME single-choke-point
principle that made this prerequisite tractable applies there too.

**Phase 2's own first increment, started.** `rt_string_new(content_len)`
now exists in `x64_runtime.patlang` as that one canonical constructor --
allocates via `bm_alloc` (not `rt_heap_alloc`) and writes the length
header, returning an untagged pointer the caller fills with content
bytes and tags itself, exactly as every producer already did before
this refactor. All 8 producer functions (`rt_str_concat`, `sb_str`,
`chr`, `substr`, `sc_char`, `rt_unit_to_str`, `rt_int_to_str`,
`rt_limb9_to_str`, `rt_dquote_str`) now call it instead of
`rt_heap_alloc` directly -- confirmed zero remaining direct
`rt_heap_alloc` calls in any of the 8 by grepping every call site back
to its enclosing function.

**A second real bug found verifying this, same shape as the others
caught so far in this plan: a "looks narrow" change again had more
depth than expected.** `bm_nc_program_uses_heap`'s own gate (only call
`bm_heap_init()` when the program contains a real `BoxNew`-family IR
instruction) made sense when only Box used `bm_alloc` -- but now
strings do too, and a program that builds a string without ever
calling `box_new` (nearly every real program) would never initialize
the free-list table at all. Confirmed directly as a real, reproduced
segfault (not a theoretical gap), then isolated precisely through a
long chain of elimination -- plain cross-half function calls from
`x64_runtime.patlang` into `heap.patlang` work fine (confirmed with
`bm_rc_get`, `bm_align8`, `bm_freelist_pop`, each tested individually);
only `bm_alloc` itself crashed, and only because nothing had ever
called `bm_heap_init()` for a program with no Box instruction anywhere.
Fixed by making `bm_heap_init()` unconditional in `bm_to_real_funcir`
again (it was made conditional once before, for issue #181, specifically
to avoid breaking the WASM path -- which turns out never to reach this
function at all, since WASM lowers via plain `lower_program`, never
`bm_lower_program`/`bm_to_real_funcir`, so that original concern never
actually applied here). Verified: `native_codegen_check.sh` (39/39),
`refcounted_heap_native_check.patlang` (13/13), the real-threads stress
test (5/5), and the original failing repro (`print(10)` via
`build_native.patlang`) all pass.

**Phase 2's own detection pass, done for the narrowest slice.**
`bm_nc_insert_string_rc_decs` (native_codegen.patlang) now finds every
eligible local in a function whose entire closure is a single,
branch-free block (no internal `Jump`/`JumpIfFalse` at all -- checked
directly, not assumed, since that guarantees exactly one reachable
terminal `Return`/`ReturnValue`: `bm_nc_flatten_blocks`'s own tail-
fallback `Return`, appended unconditionally after every root, is
provably unreachable dead code in this specific shape). Eligible means:
a direct, syntactic result of one of the 8 known producer calls, stored
exactly once, never the value actually being returned, never named in
any `MakeClosure`'s own captured list. One `rt_string_rc_dec` call
(a new helper in `x64_runtime.patlang`, recovering the exact size
`bm_alloc` was originally called with from the string's own length
header) gets inserted immediately before that one terminal, per
eligible local -- no `rc_inc` needed anywhere in this increment, since
nothing is ever copied into a second binding; the local is the only
reference from creation to this one discard point.

A branching function (an `if`/`else` with its own early return, needing
the decrement duplicated at each exit point) is explicitly out of
scope, deferred to a later, separate increment.

Verified with a zero-tolerance fixture: a branch-free function builds a
string via `chr`, stores it in a local it never touches again, returns
its own parameter instead -- called 50,000 times after one warm-up
call, the real heap's own bump-pointer shows **exactly zero** growth.
Before this pass existed, the same measurement (no warm-up) showed 24
bytes of growth; `rt_string_new` alone (routing allocation through
`bm_alloc`) only avoids *unnecessary* allocation -- it does not, by
itself, reclaim anything without an actual decrement call, confirmed by
this exact before/after comparison, not assumed.

A real, small, separate gap found along the way, filed as its own issue
(#219) rather than fixed here: `build_native.patlang`'s own test
harness never calls `bm_patc_resolve_runtime_calls` the way
`bm_patc_lower` (the ordinary CLI's own path) does, so it can't compile
a block-model fixture that calls an external runtime function directly
by name. Worked around by building the verification fixture through the
ordinary CLI instead, which already resolves this correctly -- low
impact today since no existing `build_native.patlang` fixture needed
this, but worth fixing before relying on that harness for Phase 2's
later increments.

**Phase 2's second increment: internal branching, when it still leaves
exactly one reachable exit.** The eligibility gate (renamed
`bm_nc_closure_has_unambiguous_single_terminal`, from the stricter
`bm_nc_closure_is_branch_free`) now allows internal `Jump`/
`JumpIfFalse` -- a common, safe real-world shape (a merging `if`/`else`
that conditionally computes something but never returns early) was
being rejected outright by the original, stricter check for no good
reason. Generalized by checking something more precise than "no jumps
exist": find the function's own first `ReturnValue`, then verify no
`Jump`/`JumpIfFalse` instruction's own TARGET lands at or after it. A
merging `if`/`else`'s jump targets always land strictly before its one
shared return (confirmed directly: targets of 12, return at index 14);
a genuine early return's jump targets always land at or past its first
return instead (confirmed directly, same method: targets of 10, first
return at index 8) -- correctly keeping that harder case excluded
without a looser check accidentally lumping it in. Nothing else in the
pipeline needed changing: `bm_nc_insert_string_rc_decs` already finds
whatever terminal this gate confirms is unambiguous and inserts the
decrement there, unchanged.

Verified both directions with a dedicated IR dump before touching
anything further, the same discipline used throughout this plan: the
merging-if case gets the decrement inserted once this generalization
landed; the early-return case (tested side by side, same driver)
correctly still does not. Then with a real native fixture: 50,000
cycles through a merging `if`/`else`, alternating which branch runs
each cycle, exactly zero heap growth after warm-up.

**Phase 2's third increment: genuine early returns, via dominance.**
The gate simplified back down (`bm_nc_closure_is_single_block` -- just
"is this one block," no terminal-counting at all); the real work moved
into the detection pass itself, which now asks a sharper, per-candidate
question instead of a single whole-function one: for a local created at
instruction index `p`, does `p` dominate EVERY terminal (real or dead-
tail) in the function? Given this pass only ever runs on a single-block
closure (no loops -- those always cross blocks via `JumpBlock`), two
conditions together are sufficient: `p` sits strictly before every
terminal's own index, and no `Jump`/`JumpIfFalse` positioned before `p`
targets an index after it (nothing can skip `p`'s own creation and
still reach a later exit). Confirmed directly both ways: a string
created unconditionally before any branching dominates every one of
its function's terminals, early return included; a string created only
inside one branch, after an unrelated early return in a different
branch, fails immediately (its own terminal check catches it before the
jump check even runs) and is correctly left untouched entirely.

Per-terminal precision matters here in a way the earlier increments
didn't need: a local can dominate every terminal yet be the value
*actually returned* at only one of them -- checked independently per
terminal (is the instruction right before THIS one a `Load` of THIS
candidate), not once globally, so a function can correctly return a
string on one path while discarding it (decrementing it) on another.

**A real bug found by measurement, not by re-reading the code --
exactly the discipline this whole plan has leaned on.** The first
version of this increment's rewrite inserted decrements at every
eligible terminal but never adjusted *existing* `Jump`/`JumpIfFalse`
targets for the shift its own insertions caused -- any jump whose
target landed at or after an earlier insertion point would land in the
wrong place post-rewrite. The interpreted IR dump this whole plan has
used to design every increment so far only ever *displays* the
instruction list; it never executes a jump, so it structurally could
not have caught this. Only a real native measurement could, and did: a
genuine early-return fixture (alternating which branch runs) first
measured nonzero heap growth (600,000 bytes over 50,000 cycles) where
the whole point of the pass is exactly zero. Fixed with a proper two-
pass rewrite (`bm_nc_cumulative_shift_at`): compute how many
instructions land at each terminal first, then correct every existing
jump's own target using the cumulative shift *at that target* (not at
the jump's own position -- a different question) before emitting it.

Verified with two real native fixtures, not one: 50,000 cycles through
a genuine early return (unconditional string creation, alternating
branches) show exactly zero heap growth after the fix; and, since
growth alone can't distinguish "freed correctly" from "freed too early
but coincidentally reused without visibly crashing," a second fixture
specifically exercises the local-returned-at-one-terminal-discarded-at-
another case and compares native output against `pat --ir-run` on the
identical source directly -- byte-identical across 50 alternating
cycles repeatedly reusing the same freed block, proving no corruption
on either path.

**Not yet started:** call-argument/return-value crossing where the
value is passed to something OTHER than being directly returned (e.g.
stored into a longer-lived structure via another function); list/dict-
element storage; locals that are reassigned (more than one `Store`);
loops (closures spanning more than one block, via `JumpBlock`); and
`main`/handler functions (the pass above only applies to ordinary
callee functions via `bm_nc_build_callee_funcirs`).

**Checkpoint:** both the generalized-allocator proof (above) and the
free-list fast-path's own genuine reachability are confirmed, not
assumed -- `refcounted_heap_native_check.patlang`'s full suite (13/13)
and `native_codegen_check.sh`'s full suite (38/38) both pass.

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
