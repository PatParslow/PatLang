# Stage 36 — Numeric tower in the interpreter (no codegen changes yet)

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Foundation for [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md)
  (the `numeric_tower` chunk trigger heuristic references `BinOp` from here).
- Foundation for [`stage-38-numeric-tower-codegen.md`](./stage-38-numeric-tower-codegen.md)
  (extends this same `Value` design and promotion rules into both codegen templates).
- Its literal int/float discrimination is threaded further in Stage 38's
  `hosts.rs`/`codegen.patlang` work.
- Verified per [`verification-plan.md`](./verification-plan.md) (interpreter-only
  `numeric_tower.rs` tests, pre-Stage-36 audit of existing stdout expectations).

## Goal

Get promotion semantics right and fully tested in the cheap, no-`rustc`
interpreter path before touching either codegen template.

## Detailed design

### `rust-runtime/src/ir/types.rs` — replace the single `Number(f64)` variant

```rust
pub enum Value {
    Unit, Bool(bool),
    Int(i64),
    Float(f64),
    BigInt(num_bigint::BigInt),
    Rational(num_bigint::BigInt, num_bigint::BigInt),   // always reduced, den > 0
    Complex(Box<Value>, Box<Value>),                     // re/im each Int|Float|BigInt|Rational
    String(String), List(Vec<Value>), HostFunction(...), Object(HashMap<String, Value>),
    Closure { func_name: String, captured: Vec<(String, Value)> },
}
```

Take the `num-bigint` crate dependency for the interpreter
(`rust-runtime/Cargo.toml`) — hand-rolling arbitrary-precision arithmetic
correctly is a multi-week trap with no benefit here, since this crate never
gets textually reproduced anywhere (that's a separate, later decision for the
codegen template — see Stage 38's documented hand-rolled-BigInt asymmetry).

### New module `rust-runtime/src/ir/numeric.rs`

- `promote_pair(a: &Value, b: &Value) -> Result<(Value, Value), String>` —
  central dispatch coercing two operands to a common representation.
- `normalize(v: Value) -> Value` — demotes `BigInt` back to `Int` if it fits
  in `i64`, `Rational` with denominator 1 to `Int`/`BigInt`, `Complex` with
  exactly-zero imaginary part to its real component. Run after every
  arithmetic op so the fast path stays fast.

### Promotion rules

- `Int ⊗ Int` (`+`,`-`,`*`): `i64::checked_*`; on overflow, promote both to
  `BigInt` and retry (always succeeds).
- `Int / Int`: exact (`a % b == 0`) → `Int`/`BigInt`; inexact →
  `Rational(a, b)` reduced (per the locked-in decision in the index).
- Any operand `Float` → both sides convert to `f64`, op proceeds in float
  (inexact contagion, Scheme-style). `BigInt`/`Rational` → `f64` conversion
  can lose precision silently; document, don't error.
- `Rational ⊗ Rational` / `Rational ⊗ Int`: cross-multiply using `BigInt`
  arithmetic — never overflows, no error path needed given the BigInt-backed
  decision.
- `Complex` involved: other operand promotes to `Complex(other, 0)`;
  component-wise formulas `(a+bi)+(c+di)=(a+c)+(b+d)i`,
  `(a+bi)(c+di)=(ac-bd)+(ad+bc)i`.
- Comparisons (`Eq/Lt/...`): promote both sides through the same
  `promote_pair` before comparing (so `Int(3) == Rational(3,1)` is `true`).

### `rust-runtime/src/ir/ops.rs`

Rewrite `add/sub/mul/div/modu/cmp` to call `numeric::promote_pair` + a
same-kind op + `normalize`, keeping the existing string-concat special case
in `add` untouched. Add `as_index(&Value) -> Result<usize, String>` as the
new lossy-truncation escape hatch for list-index math, replacing ad hoc
`as f64 as usize` call sites; audit `hosts.rs` for the ~15 places currently
doing that.

### Literal lexing (newly discovered required scope)

`rust-runtime/src/lexer.rs`'s number-lexing loop (currently integer-only,
line ~133) needs a decimal-point branch producing a distinct float token, and
the AST/IR literal node needs a flag for "was this written with a decimal
point" so `42` lowers to `Const(Value::Int(42))` (fast path by default) while
`42.5` lowers to `Const(Value::Float(42.5))`. Mirror in
`self_hosting/lib/lexer.patlang`.

## Files touched

- `rust-runtime/src/ir/types.rs`
- `rust-runtime/src/ir/numeric.rs` (new)
- `rust-runtime/src/ir/ops.rs`
- `rust-runtime/src/ir/hosts.rs` (audit ~15 `as f64 as usize` call sites)
- `rust-runtime/src/lexer.rs`
- `self_hosting/lib/lexer.patlang` (mirrored decimal-point lexing)
- `rust-runtime/Cargo.toml` (add `num-bigint`)

## Tests

New `rust-runtime/tests/numeric_tower.rs`, purely interpreter-driven
(`Interpreter::run`, no `rustc`):
- overflow-triggers-bigint
- inexact-division-triggers-rational
- demotion-after-op
- cross-kind comparison

See [`verification-plan.md`](./verification-plan.md) for the pre-Stage-36
audit of `self_hosting/examples/*.patlang` and hardcoded stdout strings in
`rust-runtime/tests/` that must be updated for the new rational-on-inexact-
division display behavior, and for the live end-to-end checks
(`9223372036854775800 + 1000`, `10 / 3`) that exercise this stage.
