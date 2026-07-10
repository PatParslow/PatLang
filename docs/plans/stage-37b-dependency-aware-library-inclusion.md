# Stage 37B — Dependency-aware `.patlang` library inclusion (file-level, general mechanism)

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Sits alongside [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md)
  (that stage's chunking is for the built-in host-function runtime; this
  stage's mechanism is for user/library `.patlang` files).
- Is the general-purpose safety net underneath the finer-grained,
  per-function mechanism in
  [`stage-37c-symbol-level-shaking-math.md`](./stage-37c-symbol-level-shaking-math.md) —
  37C builds on top of the dedup and manifest infrastructure introduced here.

## Goal

PatLang the language has no `import`/`export` syntax, and adding one is out
of scope here — instead, introduce a sidecar manifest mechanism plus a
correctness fix for the existing naive include-expansion.

## Detailed design

- New `self_hosting/lib/deps.manifest` (same `name: dep1 dep2` format as
  `patbuild.manifest`) declaring file-level dependencies for
  `lexer`/`parser`/`lower`/`codegen`/`runtime_rs`/`math` etc.
- `rust-runtime/src/preprocess.rs::expand_includes` gains a
  `HashSet<canonical_path>`-based dedup (fixes the naive double-`include`
  duplication flaw) — this is the general-purpose safety net under the
  finer-grained mechanism in Stage 37C.

## Files touched

- `self_hosting/lib/deps.manifest` (new)
- `rust-runtime/src/preprocess.rs` (`expand_includes` dedup)

## Tests

No dedicated new test file called out for this sub-stage specifically;
covered indirectly by the broader modularity tests in
[`verification-plan.md`](./verification-plan.md) (e.g. the "compile the same
program twice" binary-size/text-diff check in the live end-to-end
verification list), and by Stage 37C's tests once symbol-level shaking is
layered on top of this manifest infrastructure.
