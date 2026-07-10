# Verification plan

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Cross-references:** this file is the cross-cutting verification strategy
covering all of
[`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md),
[`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md),
[`stage-37b-dependency-aware-library-inclusion.md`](./stage-37b-dependency-aware-library-inclusion.md),
[`stage-37c-symbol-level-shaking-math.md`](./stage-37c-symbol-level-shaking-math.md),
[`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md), and
[`stage-39-math-library.md`](./stage-39-math-library.md).

## Automated test additions

- `cargo test` additions: `numeric_tower.rs` (Stage 36, no `rustc` needed),
  `tree_shaking.rs` (Stage 37A, inspects emitted source text only),
  `bignum_cross_path.rs` (Stage 38, needs `rustc`, follow the existing
  skip-if-no-rustc pattern from `selfhost_pipeline.rs`).
- Redesigned `selfhost_runtime_text_parity` (per-chunk, see Stage 37A) is the
  mechanical guardrail against the two hand-kept-in-sync codegen templates
  drifting — every new chunk added in Stage 38/39 must pass it before merge.
- New `selfhost_pipeline`/`selfhost_targets`-style integration tests modeled
  on existing ones (e.g. `selfhost_stage4_codegen_in_patlang`): compile a
  demo calling `sqrt`/`factorial` through the *self-hosted* front end,
  assert the emitted Rust excludes `networking`/`oo`/`logic` chunk text while
  including `numeric_tower`/`math` (see Stage 37A and Stage 39).
- Re-run the `#[ignore]`d fixpoint test
  (`selfhost_fixpoint_patc_compiles_itself`, ~7 min) manually after Stage
  38/39 land — parity tests prove chunk *contents* match between the two
  templates, but not that `required_chunks` *selection logic* agrees on which
  chunks a given program needs; the fixpoint test is the strongest available
  check for that.

## Live end-to-end verification

Not just automated tests — run these for real via `pat --ir-run` and a
compiled `patc`-produced binary, diff stdout between the two:

1. `let x = 9223372036854775800 + 1000` — confirm both paths show the
   correct bignum result, not wraparound or a panic.
   (Exercises [Stage 36](./stage-36-numeric-tower-interpreter.md) and
   [Stage 38](./stage-38-numeric-tower-codegen.md).)
2. `let x = 10 / 3` — confirm both paths agree on the new exact-rational
   behavior (and don't just quietly still print a float — the actual point
   of this whole change).
   (Exercises [Stage 36](./stage-36-numeric-tower-interpreter.md) and
   [Stage 38](./stage-38-numeric-tower-codegen.md).)
3. `sqrt(-1)` — confirm both paths report an identically formatted complex
   result.
   (Exercises [Stage 38](./stage-38-numeric-tower-codegen.md) and
   [Stage 39](./stage-39-math-library.md).)
4. Compile the same small program twice (once bare, once additionally
   calling `tcp_listen`) — confirm the emitted source text and compiled
   binary size both differ, as a concrete "modularity worked" signal beyond
   source-grepping alone.
   (Exercises [Stage 37A](./stage-37a-host-prelude-chunking.md).)
5. Compile a program calling only `sqrt` from `math.patlang` — confirm the
   emitted source contains `sqrt`'s definition but not
   `factorial`/`is_prime`.
   (Exercises [Stage 37C](./stage-37c-symbol-level-shaking-math.md) and
   [Stage 39](./stage-39-math-library.md).)

## Pre-Stage-36 audit

Before Stage 36 lands: audit `self_hosting/examples/*.patlang` and any
hardcoded stdout strings in `rust-runtime/tests/` for integer-division
results that will change display format under the new rational-on-inexact-
division rule, and update expected outputs deliberately (not as surprise
test breakage). See the locked-in division decision in
[`README.md`](./README.md).

## Files touched

- `rust-runtime/tests/numeric_tower.rs` (new)
- `rust-runtime/tests/tree_shaking.rs` (new)
- `rust-runtime/tests/bignum_cross_path.rs` (new)
- `rust-runtime/tests/selfhost_pipeline.rs` (redesigned parity test, new
  integration tests)
- `self_hosting/examples/*.patlang` (audit/update expected outputs)
