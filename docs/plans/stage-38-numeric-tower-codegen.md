# Stage 38 — Numeric tower reaches codegen (compiled-program parity)

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Extends the `Value`/promotion design from
  [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md)
  into both codegen templates.
- Uses the `numeric_tower` chunk slot reserved in
  [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md)
  and is covered by that stage's redesigned per-chunk parity test.
- Is a prerequisite for [`stage-39-math-library.md`](./stage-39-math-library.md),
  whose primitives operate on tower values inside the emitted program.
- Its documented BigInt asymmetry (crate vs. hand-rolled) is directly
  relevant to why
  [`future-work-cuda-kernel-generation.md`](./future-work-cuda-kernel-generation.md)'s
  typed-array gap isn't addressed here either — both are deliberate
  scope boundaries around what the emitted-program template can depend on.
- Verified via the new `bignum_cross_path.rs` cross-implementation property
  test described in [`verification-plan.md`](./verification-plan.md).

## Goal

Extend the Stage 36 tower into both codegen templates via the new
`numeric_tower` chunk (Stage 37A mechanism), so the cost is opt-in per binary.

## Detailed design

- Add `numeric_tower` chunk text to both `codegen.rs` and
  `runtime_rs.patlang` (private `Value` copy gains the same variants;
  `numeric::*` logic hand-transcribed into the template's Rust-text dialect,
  same process already used for every other host function). Covered by
  Stage 37A's per-chunk parity test, so drift is caught immediately rather
  than silently.

### BigInt: a deliberate, documented asymmetry

**BigInt in the emitted program is a separate decision from BigInt in the
interpreter**: emitted programs are compiled via bare `rustc` on a single
`.rs` file with zero `Cargo.toml`/dependencies (load-bearing for
`rustc_build`'s offline/hermetic/no-`cargo` invariant) — switching to
`cargo build` + a generated `Cargo.toml` just to depend on `num-bigint` is a
materially bigger architecture change (touches WASM target detection, build
caching, every `compile_source_to_exe` call site) and is **not**
recommended.

Instead: **hand-roll a self-contained BigInt** (`Vec<u32>` limbs, schoolbook
multiply, simple long division) as plain Rust source text inside the
`numeric_tower` chunk. This is a deliberate, documented asymmetry (crate in
the interpreter's own `Cargo.toml` per Stage 36, hand-rolled limbs in the
emitted-program template here) — call it out explicitly in code comments at
both definition sites so it doesn't look like an oversight.

Because this creates two independent BigInt implementations that must behave
identically, add a **cross-implementation property test**
(`rust-runtime/tests/bignum_cross_path.rs`): random big-integer operation
pairs, run through both the interpreter and a compiled binary (via
`rustc_build` + `exec_capture`), assert identical string output. This is the
concrete "live-test both paths" verification the numeric work needs, not
just unit tests.

- Rational/Complex in the template: same hand-roll treatment (struct-pair
  arithmetic, no crate needed on either side), lower risk than BigInt.
- Wire the literal int/float discrimination from Stage 36 through the rest
  of the pipeline: `hosts.rs`'s `lower_shape_expr`/`decode_ir_instr` and
  `codegen.patlang`'s `emit_instr_rs` `"Const"` arm both need a numeric-kind
  discriminator, not just an f64 payload.

## Files touched

- `rust-runtime/src/ir/codegen.rs` (`numeric_tower` chunk content)
- `self_hosting/lib/runtime_rs.patlang` (`numeric_tower` chunk content mirror)
- `rust-runtime/src/ir/hosts.rs` (`lower_shape_expr`/`decode_ir_instr`
  numeric-kind discriminator)
- `self_hosting/lib/codegen.patlang` (`emit_instr_rs` `"Const"` arm)

## Tests

- New `rust-runtime/tests/bignum_cross_path.rs` (cross-implementation
  property test, needs `rustc`, see verification plan for the
  skip-if-no-rustc pattern to follow).
- Covered by Stage 37A's redesigned per-chunk parity test for the
  `numeric_tower` chunk's text content.

See [`verification-plan.md`](./verification-plan.md) for the live
end-to-end checks that exercise this stage (`9223372036854775800 + 1000`,
`10 / 3`, `sqrt(-1)` diffed between interpreter and compiled binary).
