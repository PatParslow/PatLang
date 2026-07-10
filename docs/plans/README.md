# PatLang: Numeric Tower, Math Library, and Modular Compilation — Plan Index

This directory splits the combined plan originally captured in
`review-memory-for-the-swirling-octopus.md` (repo root) into one file per
implementation step, for easier review and incremental execution. Each file
retains full technical detail from the source — this is a *split*, not a
summary — and cross-references the other files where the source implies a
dependency.

## Reading / dependency order

1. [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md) — foundation: `Value` enum, promotion rules, decimal literal lexing, interpreter-only tests.
2. [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md) — split the ~1600-line host-function prelude into named chunks + `required_chunks()` selection.
3. [`stage-37b-dependency-aware-library-inclusion.md`](./stage-37b-dependency-aware-library-inclusion.md) — file-level `deps.manifest` + include-dedup safety net.
4. [`stage-37c-symbol-level-shaking-math.md`](./stage-37c-symbol-level-shaking-math.md) — per-function `include ... only [...]` splicing, built now for `math.patlang`.
5. [`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md) — extend the tower into both codegen templates via the new `numeric_tower` chunk.
6. [`stage-39-math-library.md`](./stage-39-math-library.md) — `Host::` primitives + `math.patlang`, built on 37C's shaking and 38's chunk.
7. [`verification-plan.md`](./verification-plan.md) — cross-cutting test/verification strategy covering every stage above.
8. [`future-work-cuda-kernel-generation.md`](./future-work-cuda-kernel-generation.md) — explicitly out of scope; documents the architectural prerequisites for a later stage.

## Shared context (applies to all files below)

PatLang currently has exactly one numeric representation end-to-end
(`Value::Number(f64)`, used identically by the interpreter, the Rust codegen
template, and the self-hosted PatLang codegen template) and no math library at
all — `self_hosting/tools/agent_team.patlang` explicitly documents "PatLang
has no sqrt()" as a known gap. Separately, PatLang's compilation model embeds
its *entire* ~1600-line host-function runtime (TCP networking, OO/facts/goals,
string builders, everything) into **every** compiled binary unconditionally —
there is no tree-shaking anywhere, and library "inclusion" (`include "path"`,
`patbuild.manifest`) is naive whole-file text concatenation with no dependency
analysis.

The user wants three things, in this priority order:
1. A **math library** built on a **Numerical Tower** (Scheme/Racket-style
   automatic promotion: small ints/floats stay fast by default; the runtime
   auto-promotes on overflow to bignum, on inexact int division to exact
   rational, and on `sqrt` of a negative number to complex — no source-level
   type annotations required).
2. Genuine **modular compilation**: a program should only pull in the host
   functions and library code it actually uses — the *big* version: split the
   host-function prelude by feature in both codegen paths, **and** build real
   per-function dependency tracking for the math library specifically (not
   just file-level).
3. **CUDA kernel generation is explicitly out of scope for this plan** — see
   [`future-work-cuda-kernel-generation.md`](./future-work-cuda-kernel-generation.md).

Key discovered fact shaping the whole plan: PatLang's lexer has **no
decimal-point literal syntax today** (`rust-runtime/src/lexer.rs:133-142`,
comment "Numbers (integer only for now)"; `.` only lexes as a `Dot` token for
member access). Every numeric literal in existing `.patlang` source is an
integer — the only way non-whole values arise today is as a side effect of
`/`. This is why the division-semantics decision below is central rather than
a side detail, and why adding `3.14`-style literals is in scope alongside the
tower itself (see Stage 36).

### Decisions locked in with the user

- **Division**: `int / int` that doesn't divide evenly promotes to an
  **exact Rational** automatically (not float) — true Scheme-style
  exactness-by-default. This changes the printed output of existing
  integer-division programs; must audit `self_hosting/examples/*.patlang` and
  any hardcoded stdout strings in `rust-runtime/tests/` (tracked in
  [`verification-plan.md`](./verification-plan.md)).
- **Rational representation**: **BigInt-backed from day one**
  (`Rational(BigInt, BigInt)`, always reduced), not a fixed `i64` pair with an
  overflow error. No later widening migration needed.
- **Tree-shaking granularity**: build **symbol-level (per-function)**
  dependency tracking for `math.patlang` now, not deferred — in addition to
  the coarser file/chunk-level shaking for the host-function prelude and
  other library files.

### The two parallel implementations that must stay in sync

This repo has two parallel implementations that must stay in sync throughout:
- `rust-runtime/` — the real Stage 0 Rust compiler: `src/ir/types.rs`,
  `ir/ops.rs`, `ir/hosts.rs`, `ir/codegen.rs`, `ir/lowering.rs`,
  `src/lexer.rs`, `src/preprocess.rs`.
- `self_hosting/` — the self-hosted PatLang-authored compiler:
  `lib/lexer.patlang`, `lib/parser.patlang`, `lib/lower.patlang`,
  `lib/codegen.patlang`, `lib/runtime_rs.patlang`.

`runtime_rs.patlang`'s `emit_runtime_rs()` is parity-tested byte-for-byte
against `codegen.rs`'s `prelude()` today (`selfhost_runtime_text_parity` in
`rust-runtime/tests/selfhost_pipeline.rs`) — every change in Stages 36-39 must
preserve an equivalent parity guarantee, redesigned to be per-chunk (see
Stage 37A and the verification plan).

`rust-runtime/Cargo.toml` already depends on `tokio`, `serde`, `hyper`,
`serde_yaml`, `uuid` — adding `num-bigint` to the **interpreter's own**
dependency list (Stage 36) is a trivial, in-character addition, not a new
category of risk.

## Master critical-files list

- `rust-runtime/src/ir/types.rs`, `ir/ops.rs`, `ir/numeric.rs` (new),
  `ir/hosts.rs`, `ir/codegen.rs`, `ir/lowering.rs`, `src/lexer.rs`,
  `src/preprocess.rs`
- `self_hosting/lib/lexer.patlang`, `lib/parser.patlang`, `lib/lower.patlang`,
  `lib/codegen.patlang`, `lib/runtime_rs.patlang`, `lib/math.patlang` (new),
  `lib/deps.manifest` (new)
- `self_hosting/tools/patbuild_main.patlang`, `patbuild.manifest`,
  `tools/tree_shake_lib.patlang` (new), `tools/agent_team.patlang`
- `rust-runtime/tests/selfhost_pipeline.rs`, new `numeric_tower.rs` /
  `tree_shaking.rs` / `bignum_cross_path.rs`
- `rust-runtime/Cargo.toml` (add `num-bigint`)

Each per-stage file below lists only the subset of these files relevant to
that stage.
