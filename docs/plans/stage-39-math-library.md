# Stage 39 — Math library

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Primitives use the tower types/promotion from
  [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md)
  and are emitted via the `math` chunk reserved in
  [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md)
  and populated in [`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md).
- `math.patlang` functions are the primary beneficiary of the per-function
  splicing built in
  [`stage-37c-symbol-level-shaking-math.md`](./stage-37c-symbol-level-shaking-math.md) —
  each function here gets a `deps.manifest` entry for that mechanism.
- Verified via the integration tests and live end-to-end checks in
  [`verification-plan.md`](./verification-plan.md), including the
  `agent_team.patlang` regression exercise.

## Goal

Hybrid design: a small set of `Host::` primitives (need direct access to
tower internals) plus `self_hosting/lib/math.patlang` for everything
expressible in terms of those primitives (cheaper to write/review, and gets
the Stage 37C symbol-level shaking for free).

## Detailed design

### Primitives (new `Host::` arms)

New `Host::` arms in `hosts.rs`, mirrored in the `math` chunk in both codegen
templates, and added to `Lowerer::is_allowed_host`'s allowlist in
`lowering.rs` — a real, easy-to-miss footgun today since anything missing
from that allowlist gets silently dropped from top-level statements with no
error:

- `sqrt(x)` — real sqrt for `x >= 0` (exact `Int` result for perfect
  squares, `Float` otherwise); `x < 0` → `Complex(0, sqrt(-x))` — the user's
  explicitly named trigger case.
- `pow(base, exp)` — integer exponent on integer/rational base stays exact
  via repeated squaring through the tower's own arithmetic (promotes to
  BigInt on overflow exactly like `*` does); non-integer exponent or float
  base falls back to `f64::powf`.
- `sin/cos/tan/asin/acos/atan/atan2/log/exp` — thin `f64` wrappers (always
  inexact, standard for transcendentals).
- `floor/ceil/round/trunc` — exact for `Int`/`BigInt`/`Rational` inputs
  (e.g. floor of a rational is exact integer division), `f64` fallback for
  `Float`.
- `abs` — exact for all real kinds; complex modulus (`sqrt(re²+im²)`) for
  `Complex`.
- `numeric_kind(x) -> string` (or `is_int`/`is_float`/... predicates) —
  runtime introspection so PatLang code can branch on what representation a
  value ended up in, since there are no source-level type annotations.

### `self_hosting/lib/math.patlang` (new)

`hypot`, `factorial` (exercises bignum promotion via repeated `*` on large
`n` — good smoke test), `gcd`/`lcm`, `clamp`, `sign`, `is_prime` (exercises
bignum via `%`), basic stats (`mean`, `sum`). Each function gets a
`deps.manifest` entry so the Stage 37C symbol-level splice mechanism can
shake it per-function.

### Documentation update

Update `self_hosting/tools/agent_team.patlang` (lines ~80, 97) which
currently documents "PatLang has no sqrt()" as a known test-harness
limitation — remove/update once shipped, and consider exercising the
AI-dev-team pipeline against a math task as a regression check.

## Files touched

- `rust-runtime/src/ir/hosts.rs` (new `Host::` primitive arms)
- `rust-runtime/src/ir/lowering.rs` (`is_allowed_host` allowlist)
- `rust-runtime/src/ir/codegen.rs` / `self_hosting/lib/runtime_rs.patlang`
  (`math` chunk mirror)
- `self_hosting/lib/math.patlang` (new)
- `self_hosting/lib/deps.manifest` (per-function entries for `math.patlang`)
- `self_hosting/tools/agent_team.patlang` (doc update)

## Tests

No dedicated new test file called out separately for this stage in the
source plan; covered by:
- Stage 37A's per-chunk parity test (for the `math` chunk content).
- The integration test in
  [`verification-plan.md`](./verification-plan.md) that compiles a demo
  calling `sqrt`/`factorial` through the self-hosted front end and asserts
  chunk inclusion/exclusion.
- Live end-to-end checks #3 and #5 in
  [`verification-plan.md`](./verification-plan.md) (`sqrt(-1)` complex
  result parity; `sqrt`-only compile excludes `factorial`/`is_prime`).
