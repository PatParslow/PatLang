# Stage 37A — Host-function prelude chunking

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Consumes the `BinOp`/literal work from
  [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md)
  for the `numeric_tower` chunk's conservative-inclusion trigger.
- Is the general mechanism that
  [`stage-37b-dependency-aware-library-inclusion.md`](./stage-37b-dependency-aware-library-inclusion.md)
  sits alongside (chunk-level for host functions vs. file-level for `.patlang`
  library inclusion) and that
  [`stage-37c-symbol-level-shaking-math.md`](./stage-37c-symbol-level-shaking-math.md)
  refines further (symbol-level for `math.patlang` specifically).
- The `numeric_tower` chunk defined here is populated with real content in
  [`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md);
  the `math` chunk is populated in
  [`stage-39-math-library.md`](./stage-39-math-library.md).
- Its redesigned parity test and new `tree_shaking.rs` test are part of the
  overall approach in [`verification-plan.md`](./verification-plan.md).

## Goal

Make "compile only what's required" real, in both codegen paths, before the
tower's own runtime code becomes one more thing every binary pays for
unconditionally.

## Detailed design

Split `RustCodegen::prelude()` (`rust-runtime/src/ir/codegen.rs`, currently
one ~1600-line string) into named, independently-emittable chunks, derived
directly from the existing `Host::call` match arms (a regrouping, not new
design):

- `core` (always included: `Value`, `Instr`, VM loop, `display_value`, list
  ops, event dispatch)
- `strings_ext`
- `collections_handles` (`vec_*`/`sb_*`)
- `files`
- `io_misc`
- `oo` (`new`/`send`/`get` object arms)
- `logic` (`fact`/`query`/`goal`)
- `contracts`
- `networking` (`tcp_*`)
- `codegen_bootstrap` (`rustc_build`/`compile_shape`/`compile_ir`/`run_ir` —
  builder-only hosts, the single highest-value exclusion since end-user
  programs almost never need to shell out to `rustc` themselves)
- `numeric_tower` (populated in Stage 38)
- `math` (populated in Stage 39)

### Chunk selection

- `required_chunks(program: &Program) -> BTreeSet<ChunkId>` (new, in
  `codegen.rs`): one pass over every function's IR collecting distinct
  `Instr::CallHost(name, _)` names, mapped to chunks via a static table, plus
  transitive closure over the small cross-chunk dependency edges, plus `core`
  always. `numeric_tower` is a special case: since any `+ - * / %` could in
  principle overflow into bignum, include it whenever any numeric `BinOp`
  appears at all — flagged as a known conservative-inclusion limitation, not
  a bug, and not worth over-engineering away in this stage.
- `RustCodegen::prelude()` → `prelude_for(chunks: &BTreeSet<ChunkId>) -> String`,
  each chunk stored as its own `&'static str` constant; `emit_rust` computes
  `required_chunks` then calls `prelude_for`.

### Mirror in the self-hosted compiler

- **`self_hosting/lib/codegen.patlang`**: an equivalent `required_chunks(ir)`
  walking the list-shaped IR's `CallHost` instructions — mechanical,
  consistent with the file's existing tag-dispatch style, no new language
  features needed.
- **`self_hosting/lib/runtime_rs.patlang`**: split `emit_runtime_rs()` into
  per-chunk emitter functions (`emit_chunk_core()`, etc.) plus
  `emit_runtime_rs_for(chunk_names)` concatenating in the same fixed order the
  Rust side uses (order must match exactly or byte-for-byte parity breaks on
  ordering alone, independent of content).

## Parity test redesign

`rust-runtime/tests/selfhost_pipeline.rs::selfhost_runtime_text_parity`:
replace the current single whole-prelude string comparison with a per-chunk
loop asserting `emit_chunk_by_name(name) == codegen_prelude_chunk(name)` for
every chunk name — this also gives better failure localization than today's
all-or-nothing diff. Keep one whole-program assertion
(`prelude_for(all_chunks) == emit_runtime_rs_for(all_chunk_names)`) as a
regression guard that the split itself didn't change concatenated output,
diffed once against the pre-split monolith at the moment of the refactor.

## Files touched

- `rust-runtime/src/ir/codegen.rs` (split into chunks, `required_chunks`,
  `prelude_for`)
- `self_hosting/lib/codegen.patlang` (`required_chunks(ir)` mirror)
- `self_hosting/lib/runtime_rs.patlang` (per-chunk emitters,
  `emit_runtime_rs_for`)
- `rust-runtime/tests/selfhost_pipeline.rs` (redesigned
  `selfhost_runtime_text_parity`)

## Tests

- Redesigned `selfhost_runtime_text_parity` (per-chunk loop + one whole-program
  regression guard, see above).
- New `rust-runtime/tests/tree_shaking.rs`: compile a TCP-using vs a
  non-TCP program, assert the emitted Rust source text excludes/includes
  `tcp_listen` etc. accordingly; same for `oo`/`logic`/`codegen_bootstrap`.

See [`verification-plan.md`](./verification-plan.md) for how this stage's
tests fit into the overall verification strategy, including the live
end-to-end binary-size-diff check.
