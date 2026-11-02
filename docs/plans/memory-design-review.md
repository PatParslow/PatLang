# Memory design review: plan (for discussion)

Status: proposed 2026-11-02, not started. Nothing here is a decision yet;
section 6 lists the questions that need one.

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
- `bool_array_push` grows in place, so a second holder of the same array
  sees the change. Lists copy when an older version is changed. Bool
  arrays have no interpreter counterpart to decide which is right.
- `rt_object_new` objects are mutable and compared by identity natively,
  but the interpreter's `Value::Object` is a map copied by value.
- A loop counter pays a release check on every rebinding, because an int
  can overflow into a counted BigInt. A range analysis could prove a
  local always fits a fixnum.
- Phase 6g (closures), 6h (Boxes and cycles) and 6j (world tables) are
  still open, and should be designed against the spec this review writes,
  not before it.

## 6. Questions for a decision

1. Should runtime ownership be declared in the runtime's source, or
   inferred, with the name lists removed either way?
2. Bool arrays and objects: value semantics (copy on change, as lists) or
   identity semantics (as builders and vecs)? Then make the interpreter
   match.
3. Should the interpreter move onto the native PatLang runtime as part of
   this, or after it?
4. Is the 48-bit fixnum a language-visible fact or purely a runtime
   representation? Today it is visible: for `140737488355327 + 10`
   (2^47 + 9), `type_of` says `int` in the interpreter and `bigint`
   natively.
