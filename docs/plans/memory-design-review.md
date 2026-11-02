# Memory design review: plan (for discussion)

Status: proposed 2026-11-02, not started. Section 6 records the decisions
taken so far and the questions still open.

## 1. Why

Phases 1 to 7 of `general-refcounting.md` made native memory
reference-counted, and 6d removed the last raw allocation from the
runtime. The fixes arrived one leak or one double release at a time. Each
was right locally, but most were a single instance of a general rule the
code had broken in its own way:

- the free list kept 64 exact sizes and dropped every other freed block;
- BigInt division returned its own argument as the remainder;
- `rt_int_norm` returned its argument without a reference of its own;
- `let pa = a` followed by a conditional promotion made a local the passes
  could not own;
- a BigInt trimmed after allocation was freed into the wrong size class;
- the library value-local analysis stopped early and missed a copy.

Before more fixes, the review asks whether the design is one design: a
small set of rules that the compiler applies, and that the interpreter and
the native code both follow, with every exception named and justified.

## 2. Two levels

Each rule and each exception is judged at two levels.

- **Language.** Everything is an object, and every value carries its type
  with it. Ownership is invisible to a program: no PatLang program frees
  anything, and none can observe when memory is freed, only that it does
  not run out.
- **Runtime.** For speed, the representation may differ from the object
  model: an unboxed fixnum, a raw float in a register, a family code in
  place of a type name, a block with no count header. Each such shortcut
  is valid only under a condition. A value or variable with events
  attached, for instance, may need its object form kept. The review
  states that condition for each shortcut, and where the object form is
  required.

## 3. What is there now (inventory, 2026-11-02)

Counts are from the sources as they stand. The review classifies each
item; this section only lists them.

### 3a. Ownership written by hand in the runtime (`x64_runtime.patlang`, 449 functions)

| what | count |
|---|---|
| `rt_keep(...)`: "this value now has a reference of its own" | 37 |
| `rt_fresh(...)`: "this tagged block is new, the caller's" | 36 |
| `rt_rc_inc_if_refcounted` / `rt_rc_dec_if_refcounted` called directly | 12 / 30 |
| `bm_alloc` / `bm_rc_dec` / `bm_rc_inc` / `bm_freelist_push` called directly | 34 / 16 / 4 / 4 |
| list node and buffer counting (`rt_list_node_rc_*`, `rt_list_buf_rc_*`) | 13 |
| `mem_poke_qword` (raw stores; some move ownership into a structure) | 162 |

The inferred value-function list has two review lists
(`self_hosting/build/x64_runtime.value_review.txt`):

- 17 value functions that also return a raw word, which then gets a retain
  that does nothing only because the word looks like a fixnum
  (`bm_freelist_table_addr` and the `*_table_lookup` functions among them);
- 8 raw functions that return a parameter.

### 3b. Facts about runtime functions kept as name lists in the compiler (`native_codegen.patlang`)

| list | names |
|---|---|
| `bm_nc_owned_runtime_producer_names` | 23 |
| `bm_nc_runtime_borrows_args` | 23 |
| `bm_nc_is_rc_entry` | 11 |
| string producers | 10 |
| `bm_nc_dispatches_by_name` | 6 |
| list producers | 3 |
| `bm_nc_raw_rc_dec_fn_for_producer` | 3 |

Each list is a second copy of something the runtime's own source already
says, kept in step by hand. CLAUDE.md section 9 records that drift as a
recurring failure.

### 3c. Rules that apply only when compiling the runtime (library mode, 9 branches)

- Value functions are inferred by a least fixpoint: a function is a value
  function if some return is a known producer.
- A local is a value local by the same inference. Only copies of value
  locals take a reference.
- An integer constant counts only within ±2^47.
- A local stored with `mem_poke_qword` is treated as moved, in every block
  of its function (`bm_fam_poked_names`).
- Arithmetic is not fresh, and a raw `Bin` result is not owned.

### 3d. Ownership in emitted asm (`codegen_x64.patlang`)

- 81 references to `rt_heap_alloc`, `rt_scratch_alloc` or `bm_alloc`
  (phase 6c's sites among them).
- Inline decisions in `x64_rc_call_asm` and `x64_rc_retain_asm`: a fixnum
  needs no count; a raw float is boxed or skipped.
- Box-release frame slots for raw floats passed as arguments, and the
  overflow promotion's own release (`x64_dynamic_promote_both_asm`).

### 3e. Representation shortcuts (runtime level)

- A fixnum is any word whose top 16 bits sign-extend: 48-bit integers are
  immediate.
- Floats are raw bits when a function's analysis proves them float, and
  boxed elsewhere.
- A string literal lives in `.data` with no count header.
  `rt_rc_payload_in_heap` tells literals from heap blocks by address range.
- Numeric dispatch compares `x64_family_code` codes, not `type_of` names.
- A string builder cell's fields are raw (length, capacity, buffer).

### 3e2. Where memory comes from

PatLang manages its own memory and makes no system call per allocation.
The heap reserves a large address range once (`VirtualAlloc`,
`MEM_RESERVE`; `x64_dynamic_heap_growth.md`). `bm_alloc` reuses a block
from its size class's free list (`heap.patlang`), else bumps a pointer with
one atomic add (`rt_heap_alloc`). Pages are committed from the system only
when the bump pointer passes the committed mark, up to the next 256 MB
boundary (`mem_heap_ensure_committed`). Freed blocks go back to PatLang's
free lists, never to the system, so a program's footprint is its peak.
Every allocation and free takes the free list's one ticket lock, which
threads contend for.

The new version keeps this: one reservation, chunked commits, its own
free lists. Its two-word values (decision 6) need no block for an int or a
float. It removes the shared lock from ordinary allocation:

- **Each thread has its own free lists**, a table found through a
  thread-local slot (the runtime already uses TLS for fibers). Allocating
  from and freeing to them takes no lock and no atomic operation.
- **Each thread bumps within its own chunk.** It takes a chunk (for
  instance 1 MB) from the shared reservation with one atomic add, then
  allocates from it with plain arithmetic, touching shared state once per
  chunk.
- **A block freed by another thread goes onto the freeing thread's lists.**
  Within a size class any block serves, so this needs no lock. Schemes
  that send a block back to the thread that allocated it rely on
  compare-and-swap queues, and the runtime's only atomic is fetch-and-add.
- **Imbalance is returned in batches.** When one thread mostly frees what
  another allocates, the freeing thread's lists grow while the other keeps
  taking new chunks. Past a threshold, a thread hands a batch of blocks to
  a shared pool, and a thread with an empty list takes a batch from it.
  That takes a lock once per batch, not once per block.
- **Counts stay atomic** (`lock xadd`), since a value may be shared between
  threads. Where the ownership analysis proves a value never leaves its
  thread, its count could be a plain add. That is an optimisation to
  consider, not a requirement.

### 3f. The two engines

- The interpreter (`rust-runtime`, `hosts.rs`) holds values in Rust memory:
  lists as `Arc<Vec<Value>>`, string builders and vecs as shared cells
  compared by identity (as native cells are), and objects as a
  `HashMap` copied by value.
- The native runtime's `rt_object_new` objects are mutable cells compared
  by identity, and native lists change in place when the newest version has
  room.
- Bool arrays (`bool_array_*`) and `rt_object_*` exist only natively.
- An integer from 2^47 to 2^63 is an `int` in the interpreter and a
  `bigint` natively, and `type_of` reports the difference.

The aim is that the two are one language reached by two routes, with the
interpreter eventually running on the native PatLang runtime.

## 4. Method

With decision 5 (section 6), these steps feed a new version of the compiler
and runtime instead of edits to the current one. The classification in
step 2 tells the new version what to infer, what to state as a contract,
and what to leave out. Step 3's single source of truth is a design
requirement of the new version. Steps 4 and 5 compare the new version
against the current one as well as against the interpreter.

1. **Write the rules as a short normative spec** (a new
   `spec_library/block_model/ownership.feature` plus a prose page). Draft:
   - every call borrows its arguments and returns a reference the caller
     owns;
   - a structure owns what it stores, and releases it when it is freed or
     overwritten;
   - a local owns what a producer gave it, and a copy takes a reference;
   - a value is freed with its last reference;
   - plus each representation shortcut with its condition (section 2).
2. **Classify every item in section 3**, each to one of:
   - (a) follows from the rules, so the compiler should infer it, and the
     marker or list entry can go;
   - (b) a genuine low-level operation the rules cannot express (the free
     list itself, a string builder's raw buffer), which stays, documented
     at the site;
   - (c) a bug or a leftover.
   For (a), the question is what the compiler would need to infer it.
3. **Replace the name lists (3b) with one source of truth.** Either the
   runtime declares its functions' ownership (a declaration the compiler
   reads), or the compiler derives it from the runtime's code, as value
   functions are derived now. Then every list in 3b, and most of 3a's
   markers, become derived facts, which cannot drift.
4. **Compare the engines by behaviour.** Write scenarios that can tell the
   object models apart, and run them on both engines:
   - aliasing after `list_set` and `list_push`;
   - an object changed through one name and read through another;
   - `object_delete`;
   - identity of builders and vecs;
   - bool arrays.
   Any difference is a spec decision (section 6), then a fix on one side.
5. **Measure after each removal.** Use the benchmarks in
   `general-refcounting.md` Phase 7 step 7, and the leak fixtures in
   `native_codegen_check.sh`.

## 5. Already known to be worth a look

- Retains of raw words in the 17 "value_mixed" functions. They are no-ops
  only because heap addresses are below 2^47.
- `bool_array_push` changes the array in place while it has room, and
  returns a new one when it grows, so the old one's other holders miss
  the new element. Decided as identity semantics (section 6, decision 8).
- `rt_object_new` objects are mutable and compared by identity natively,
  but the interpreter's `Value::Object` is a map copied by value. Decided
  as identity (decision 8).
- A loop counter pays a release check on every rebinding, because an int
  can overflow into a counted BigInt. A range analysis could prove a
  local always fits a fixnum.
- Phase 6g (closures), 6h (Boxes and cycles) and 6j (world tables) are
  still open, and should be designed against the spec this review writes,
  not before it.

## 6. Decisions and open questions

Decided (2026-11-02):

1. **The runtime is compiled by the PatLang compiler with no special cases,
   except ones expressed in PatLang itself.** The compiler holds no list of
   facts about runtime functions. Anything it must know about a runtime
   function's ownership is written in that function's PatLang source, or
   follows from it. This applies to section 3b (removed), 3a (each marker
   kept only if it is a PatLang construct the language defines) and 3c
   (library-mode rules allowed only as general rules, none naming a
   function).
2. **Everything is an object at the language level; the runtime
   optimises underneath, in the manner of Ruby.** Ruby has one object
   model, and the VM stores small integers, `nil` and booleans as
   immediates. A program never sees a value lose its class, while the VM
   never allocates for those values. Section 3e's shortcuts are judged
   against that.
3. **The fixnum is visible to programs, and whether a value is an `int` or
   a `bigint` is one clear rule both engines share.** The engines must not
   disagree, as they do now: for `140737488355327 + 10` (2^47 + 9),
   `type_of` says `int` in the interpreter and `bigint` natively.
4. **The interpreter moves onto the native runtime after this review's
   problems are sorted out**, not as part of it.
5. **The compiler and the runtime are written again as a new version, not
   edited into shape.** The current code stays as the reference, to compare
   against and to bootstrap from, until the new version passes the same
   gates. Everything in the new version is protected by contracts
   (`require`/`ensure`/`assert`): each ownership rule in the spec becomes a
   condition the code checks, so a broken rule fails where it is broken,
   where today it shows up later as a leak or a double release.
6. **Values carry their type in a word of their own (the new version's
   representation).** Today the type is packed into a value's top 16 bits.
   That costs 48-bit integers (#233), the raw/boxed float split, the
   address-range test that tells string literals from heap strings, and
   any place to record metadata. In the new version a value is two words:
   a type-and-metadata word and a full 64-bit data word. Ints and floats
   sit inline at full range with no allocation; strings, lists and objects
   put a pointer in the data word. Lists and arguments double in size,
   which is accepted. One bit of the type word is reserved for per-value
   metadata if a use appears; none is designed now.
7. **Every value answers methods and raises events through its type.**
   `3.to_s` and `3.14.to_s` are lookups on the type, which is always
   present. An operation is a message: `3 + 5` sends `+` to 3 with 5. It
   can raise events through the types and the operation: "I was added to
   5" for 3, "I was added to 3" for 5, "I added 3 and 5" for `+`. They are
   ordinary PatLang events, raised and handled like every other event
   (`emit`, `when`), with nothing specific to operators; like any event,
   each is named where it is declared. Handlers are
   registered on a type or an operation, not on an individual value, so an
   int needs no per-value state to take part. With no handler registered,
   an operation costs at most one flag test, and none where the compiler
   can see there is no handler.
8. **Objects and bool arrays have identity semantics.** An object is
   mutable and can raise and handle events, so a change or a handler made
   through one name is seen through every other. The interpreter's
   `Value::Object`, a map copied by value, changes to match. A bool array
   is a mutable container like a vec: a cell holding its buffer, so
   `bool_array_push` keeps the same array even when the buffer grows, where
   today it returns a new one. The interpreter gains bool arrays.
9. **#233 (int vs bigint between 2^47 and 2^63) is not fixed in the current
   code.** The new version's 64-bit ints remove it.
10. Rebuilding the compilers (`patc1_x64`, the Gen B fixpoint) should become
   reliable as a consequence of getting this architecture right. Their
   current fragility is treated as a symptom to recheck afterwards, not
   worked around now.

Open: nothing at present.

## 7. The new version's structure: swarm-shaped from the start

`block-ownership-model-swarm-compilation.md` and `swarm-compiler.md` plan
artefact-based, parallel compilation as a new driver around `patc1`'s
existing stages, changing nothing they compute. That constraint made them
hard: lowering keeps program-wide state in `__vars`, and most of
`swarm-compiler.md`'s Phase 3 is untangling it. The new version (decision
5) is built in that shape from the start.

- **Stages are pure jobs.** Each takes explicit input artefacts and
  produces an output artefact, and reads or writes no `__vars`. The
  program-wide facts are the swarm plan's three barriers, each an
  explicit input:
  - B0, the program's `syntax` definitions;
  - B1, the symbol index;
  - B2, the program facts (uses Box, the roots reached only by name).
- **Names come from declarations.** A synthesized name is the
  declaration's identity plus a counter local to it, never a shared
  counter. Any order of work then gives the same output.
- **Registrations are recorded, not rediscovered.** `when` handlers, rules,
  and functions reached only by name (`apply`, `fiber_new`, `parallel_map`,
  `budgeted_run`) are entries in the program facts. CLAUDE.md section 9's
  keep-the-registry-exhaustive rule becomes a check a validator runs.
- **Ownership summaries are per-function artefacts, and contracts.** The
  swarm plan's Forks C and D want each function's ownership transfer
  (consumes, borrows, retains, escapes) as an explicit artefact. That is
  what replaces the compiler's name lists here (section 3b, decision 1):
  derived from the function's PatLang source, recorded per function, and
  stated as its contract (`require`/`ensure`), so a caller depends on the
  summary and the function is checked against it.
  `contract-bounded-object-compilation.md`'s rule (an object observes
  another only through its contract) is the same idea for objects.
- **The runtime is compiled by the same pipeline**, as one more program
  whose functions are cached per function.
- **The parity gate is behavioural.** Two-word values (decision 6) mean the
  new version cannot match `patc1`'s output byte for byte, so the swarm
  plan's byte-parity gate becomes:
  - the spec suites;
  - the native fixtures;
  - the interpreter's output;
  - the current compiler, kept as a behavioural reference.

  Byte parity still holds within the new version, between a sequential
  and a parallel build of the same input (the swarm plan's determinism
  test).
- **Threads become an option.** The swarm plan chose worker processes
  because stages write `__vars`. Stages that write none can run on threads,
  with the per-thread allocation of section 3e2.
- **Staging.** The stages run sequentially through the job queue first.
  Parallel workers come only after the new version passes the behavioural
  gate, so the new representation and the parallelism are never debugged
  together.
