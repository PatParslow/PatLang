# `Value::List` Arc-wrap: fixing the recurring list-clone bug

**Date:** 2026-07-16
**Status:** Done — verified across all three execution paths plus downstream apps.

## Background

`list_push`/`list_set`'s "clones the whole backing `Vec` on every call"
bug pattern was found and independently worked around **six separate
times** in one session (`family_tree.patlang`, `sim_tick_location_v2`,
`sim_resolve_events`, `sim_sort_by_birth_year`, `sim_group_by_birthplace`,
and a throwaway stress-test script), each time by routing through the
`vec_*` handle-based primitives instead of fixing the root cause.

Investigation showed the real problem is broader than `list_push`/
`list_set`: `Value::List(Vec<Value>)` derives `Clone`, so **every** clone
of a list value — including a plain variable read in the tree-walking
interpreter — was a full `O(n)` deep copy, not just explicit mutation
calls. Any code building up a large list via repeated pushes was
effectively `O(n^2)`.

Three options were considered: Arc-wrap the existing `Vec<Value>` (cheap
clone via refcount, `O(n)` push/set unchanged), a real persistent vector
via the `im` crate (`O(1)` clone *and* `O(log n)` push/set, new
dependency), or keeping `List` as-is and adding a separate thread-safe vec
type. Decision: Arc-wrap (option 1), after first surveying the actual
usage surface.

## The fix

`rust-runtime/src/ir/types.rs`:

```rust
List(Arc<Vec<Value>>),
```

`Arc`, not `Rc`, because `Arc` is `Send + Sync` — a list value can now be
safely cloned across a `parallel_map` worker-thread boundary, unlike the
`thread_local` `vec_*` handle tables it was previously necessary to route
through for that case.

Mutation goes through `Arc::make_mut(&mut xs)`, which mutates in place if
the `Arc` is uniquely held (the common case for `list_push`/`list_set`,
since the match-arm clone just made is typically the only live
reference), and deep-clones only if another reference still shares it.
`list_push`/`list_set` themselves are still `O(n)` per call (unchanged)
— the actual win is that every *other* read, pass-around, or return of a
list value elsewhere in the interpreter now costs `O(1)` (a refcount
bump) instead of `O(n)`.

## Scope: three execution paths, one definition each

PatLang has three independent places that define/use `Value::List` and
all three needed the same change:

1. **The tree-walking interpreter** (`--ir-run`) — `ir/types.rs`,
   `ir/interpreter.rs`, `ir/hosts.rs`, `ir/fiber.rs`.
2. **The native-codegen embedded prelude text** — `ir/codegen.rs`'s
   `PRELUDE_*` `&'static str` constants contain their own, textually
   separate `enum Value { ... List(Vec<Value>) ... }` definitions
   (`PRELUDE_VALUE_FAST`, `PRELUDE_NUMERIC_TOWER`) plus every
   `Value::List` construction/mutation site used by compiled programs
   (`list_push`/`list_set`/`parallel_map`/`vfs_list`/`argv`/`vec_to_list`/
   `list_dir`/`rule_add`/`solve`/the GOAP planner/`run_ir`/etc.).
3. **The self-hosted mirror** (`self_hosting/lib/runtime_rs.patlang`),
   which must reproduce those same `PRELUDE_*` chunks byte-for-byte via
   its own `emit_chunk_*` functions, per this repo's "do not leave the
   self-hosted mirror behind" discipline.

## What was actually done

- Edited `types.rs`/`interpreter.rs`/`hosts.rs`/`fiber.rs`; `cargo build`
  and `cargo test --release` both fully green. Two test files needed the
  same fix (`tests/lowering_smoke.rs`, `tests/goal_oriented_logic.rs`
  each had a raw `Value::List(vec![...])` construction).
- Edited `codegen.rs`'s embedded `enum Value` text (both copies) and
  every `Value::List` construction/mutation site inside the affected
  `PRELUDE_*` chunks, using the same `Arc::new(...)`/`Arc::make_mut(...)`
  pattern as the real Rust code.
- Ran the mirror-check parity test
  (`selfhost_runtime_text_parity`): 7 chunks came back mismatched (core,
  collections_handles, files, io_misc, logic, codegen_bootstrap,
  numeric_tower). Running `tools/regen_runtime_rs.py` fixed 5 of them —
  the other 2 (`collections_handles`, `io_misc`) were silently skipped
  because they were **missing from the script's own `CHUNKS` dict**, a
  pre-existing gap in the tool unrelated to this change. Fixed by adding
  both to `CHUNKS` in `tools/regen_runtime_rs.py`, then re-ran; all
  chunks now report `PARITY-OK`.
- Rebuilt `patc1.exe` from the resynced mirror.
- Proved three-path functional parity with a small `list_push`/
  `list_set`/`list_get`/`list_len` test program: `--ir-run`,
  `pat --patc`-compiled, and `patc1.exe`-compiled all produced identical
  output (`4 / 99 / 4 / 1`), including confirming persistent-list
  semantics still hold — mutating a list derived via `list_set` does not
  affect the original.
- Re-ran fantpop-patlang's own `tests/run_all.patlang` (6 suites) against
  the new engine — all pass, no regression.
- Additionally ran PatLang's own PatLang-level test suites, which aren't
  wired into `cargo test`: `self_hosting/tools/run_synthesis_selftests.
  patlang` (19 inductive-synthesis suites) and the standalone
  `regex_dsl_selftest.patlang`, `syntax_dsl_selftest.patlang`,
  `reflect_transpile_selftest.patlang`, `stochastic_bdd_selftest.patlang`
  — all pass.

## Tooling fix as a side effect

`tools/regen_runtime_rs.py`'s `CHUNKS` dict did not cover
`collections_handles` (`PRELUDE_COLLECTIONS_HANDLES`) or `io_misc`
(`PRELUDE_IO_MISC`), even though both chunks already exist in the mirror
and are checked by `selfhost_runtime_text_parity`. Any future engine
change touching those two chunks would have hit the same silent gap.
Fixed in the script itself as part of this work.

## Verification checklist (for the next engine change like this one)

1. Fix the real Rust code (`ir/types.rs` and friends) — `cargo check`
   clean.
2. Fix `codegen.rs`'s `PRELUDE_*` embedded text the same way — `cargo
   check` clean.
3. `cargo test --release` — fully green, including any raw test-file
   constructions of the changed type.
4. Mirror-check parity test — regenerate mismatched chunks via
   `tools/regen_runtime_rs.py`, but **check its `CHUNKS` dict actually
   covers the chunk being changed** before trusting a clean run.
5. Rebuild `patc1.exe` from the resynced mirror.
6. Three-path functional parity check (`--ir-run` / `pat --patc` /
   `patc1.exe`-compiled) on a small program exercising the change.
7. Re-run downstream application test suites (e.g. fantpop-patlang's
   `tests/run_all.patlang`) plus PatLang's own non-`cargo-test`
   selftests (`self_hosting/**/*_selftest.patlang`,
   `run_synthesis_selftests.patlang`).
