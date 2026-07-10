# Future work (explicitly out of scope here): CUDA kernel generation

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- The typed-array gap below is directly related to the `Value` enum design
  finalized in
  [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md)
  and extended in
  [`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md) —
  no typed numeric array variant is added in either of those stages, which is
  why CUDA generation remains blocked afterward too.
- The backend-selection gap relates to `rustc_build`'s role discussed in
  Stage 38's BigInt-asymmetry rationale (single-`.rs`-file, no-`cargo`
  invariant).

## Status

No design work for CUDA itself is included in this plan. This file exists
only to document the pointer for a future stage, per the user's explicit
scoping decision (see [`README.md`](./README.md), priority item 3).

## Architectural prerequisites for a later CUDA stage

A later stage would need, at minimum:

1. **A typed numeric array/vector `Value` variant** — today the only
   collection is `Value::List(Vec<Value>)`, dynamically typed and
   heterogeneous, which a GPU kernel signature can't be generated from.
2. **Loop structure preserved through lowering** instead of erased to raw
   `Instr::Jump`/`JumpIfFalse` gotos, since kernel generation needs a
   structured, bounded iteration space.
3. **A generalized backend-selection abstraction**, since `rustc_build`'s
   `target: Option<&str>` only knows how to pass strings to
   `rustc --target` and has no concept of an alternate toolchain (`nvcc`) or
   non-Rust source emission.

## Files touched

None — no implementation work in this plan. Future stage would likely touch
`rust-runtime/src/ir/types.rs` (typed array variant), `ir/lowering.rs` (loop
preservation), and `ir/hosts.rs` (`rustc_build`/backend abstraction).

## Tests

None — out of scope for this plan.
