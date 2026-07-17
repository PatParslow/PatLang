# PatLang: Numeric Tower, Math Library, and Modular Compilation

## Context

PatLang currently has exactly one numeric representation end-to-end (`Value::Number(f64)`, used identically by the interpreter, the Rust codegen template, and the self-hosted PatLang codegen template) and no math library at all — `self_hosting/tools/agent_team.patlang` explicitly documents "PatLang has no sqrt()" as a known gap. Separately, PatLang's compilation model embeds its *entire* ~1600-line host-function runtime (TCP networking, OO/facts/goals, string builders, everything) into **every** compiled binary unconditionally — there is no tree-shaking anywhere, and library "inclusion" (`include "path"`, `patbuild.manifest`) is naive whole-file text concatenation with no dependency analysis.

The user wants three things, in this priority order:
1. A **math library** built on a **Numerical Tower** (Scheme/Racket-style automatic promotion: small ints/floats stay fast by default; the runtime auto-promotes on overflow to bignum, on inexact int division to exact rational, and on `sqrt` of a negative number to complex — no source-level type annotations required).
2. Genuine **modular compilation**: a program should only pull in the host functions and library code it actually uses. This is the mechanism that makes growing a math library (or any library) safe without bloating every binary — chosen as the *big* version: split the host-function prelude by feature in both codegen paths, **and** build real per-function dependency tracking for the math library specifically (not just file-level).
3. **CUDA kernel generation is explicitly out of scope for this plan.** It's architecturally gated behind two things that don't exist yet — a typed numeric array type, and loop structure surviving lowering instead of being erased to raw jumps — so this plan only leaves a documented pointer for a future stage.

Key discovered fact that shapes the whole plan: PatLang's lexer has **no decimal-point literal syntax today** (`rust-runtime/src/lexer.rs:133-142`, comment "Numbers (integer only for now)"; `.` only lexes as a `Dot` token for member access). Every numeric literal in existing `.patlang` source is an integer — the only way non-whole values arise today is as a side effect of `/`. This is why the division-semantics decision below is central rather than a side detail, and why adding `3.14`-style literals is in scope alongside the tower itself.

Decisions locked in with the user:
- **Division**: `int / int` that doesn't divide evenly promotes to an **exact Rational** automatically (not float) — true Scheme-style exactness-by-default. This changes the printed output of existing integer-division programs; must audit `self_hosting/examples/*.patlang` and any hardcoded stdout strings in `rust-runtime/tests/`.
- **Rational representation**: **BigInt-backed from day one** (`Rational(BigInt, BigInt)`, always reduced), not a fixed `i64` pair with an overflow error. No later widening migration needed.
- **Tree-shaking granularity**: build **symbol-level (per-function)** dependency tracking for `math.patlang` now, not deferred — in addition to the coarser file/chunk-level shaking for the host-function prelude and other library files.

This repo has two parallel implementations that must stay in sync throughout: `rust-runtime/` (the real Stage 0 Rust compiler: `src/ir/types.rs`, `ir/ops.rs`, `ir/hosts.rs`, `ir/codegen.rs`, `ir/lowering.rs`, `src/lexer.rs`, `src/preprocess.rs`) and `self_hosting/` (the self-hosted PatLang-authored compiler: `lib/lexer.patlang`, `lib/parser.patlang`, `lib/lower.patlang`, `lib/codegen.patlang`, `lib/runtime_rs.patlang`). `runtime_rs.patlang`'s `emit_runtime_rs()` is parity-tested byte-for-byte against `codegen.rs`'s `prelude()` today (`selfhost_runtime_text_parity` in `rust-runtime/tests/selfhost_pipeline.rs`) — every change below must preserve an equivalent parity guarantee, redesigned to be per-chunk.

`rust-runtime/Cargo.toml` already depends on `tokio`, `serde`, `hyper`, `serde_yaml`, `uuid` — adding `num-bigint` to the **interpreter's own** dependency list is a trivial, in-character addition, not a new category of risk.

---

## Stage 36 — Numeric tower in the interpreter (no codegen changes yet)

Goal: get promotion semantics right and fully tested in the cheap, no-`rustc` interpreter path before touching either codegen template.

**`rust-runtime/src/ir/types.rs`** — replace the single `Number(f64)` variant:
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
Take the `num-bigint` crate dependency for the interpreter (`rust-runtime/Cargo.toml`) — hand-rolling arbitrary-precision arithmetic correctly is a multi-week trap with no benefit here, since this crate never gets textually reproduced anywhere (that's a separate, later decision for the codegen template in Stage 38).

New module **`rust-runtime/src/ir/numeric.rs`**:
- `promote_pair(a: &Value, b: &Value) -> Result<(Value, Value), String>` — central dispatch coercing two operands to a common representation.
- `normalize(v: Value) -> Value` — demotes `BigInt` back to `Int` if it fits in `i64`, `Rational` with denominator 1 to `Int`/`BigInt`, `Complex` with exactly-zero imaginary part to its real component. Run after every arithmetic op so the fast path stays fast.

Promotion rules:
- `Int ⊗ Int` (`+`,`-`,`*`): `i64::checked_*`; on overflow, promote both to `BigInt` and retry (always succeeds).
- `Int / Int`: exact (`a % b == 0`) → `Int`/`BigInt`; inexact → `Rational(a, b)` reduced (per the locked-in decision above).
- Any operand `Float` → both sides convert to `f64`, op proceeds in float (inexact contagion, Scheme-style). `BigInt`/`Rational` → `f64` conversion can lose precision silently; document, don't error.
- `Rational ⊗ Rational` / `Rational ⊗ Int`: cross-multiply using `BigInt` arithmetic — never overflows, no error path needed given the BigInt-backed decision.
- `Complex` involved: other operand promotes to `Complex(other, 0)`; component-wise formulas `(a+bi)+(c+di)=(a+c)+(b+d)i`, `(a+bi)(c+di)=(ac-bd)+(ad+bc)i`.
- Comparisons (`Eq/Lt/...`): promote both sides through the same `promote_pair` before comparing (so `Int(3) == Rational(3,1)` is `true`).

**`rust-runtime/src/ir/ops.rs`**: rewrite `add/sub/mul/div/modu/cmp` to call `numeric::promote_pair` + a same-kind op + `normalize`, keeping the existing string-concat special case in `add` untouched. Add `as_index(&Value) -> Result<usize, String>` as the new lossy-truncation escape hatch for list-index math, replacing ad hoc `as f64 as usize` call sites; audit `hosts.rs` for the ~15 places currently doing that.

**Literal lexing** (newly discovered required scope): `rust-runtime/src/lexer.rs`'s number-lexing loop (currently integer-only, line ~133) needs a decimal-point branch producing a distinct float token, and the AST/IR literal node needs a flag for "was this written with a decimal point" so `42` lowers to `Const(Value::Int(42))` (fast path by default) while `42.5` lowers to `Const(Value::Float(42.5))`. Mirror in `self_hosting/lib/lexer.patlang`.

**Tests**: new `rust-runtime/tests/numeric_tower.rs`, purely interpreter-driven (`Interpreter::run`, no `rustc`) — overflow-triggers-bigint, inexact-division-triggers-rational, demotion-after-op, cross-kind comparison.

---

## Stage 37 — Modularity: host-prelude chunking + dependency-aware library inclusion

Goal: make "compile only what's required" real, in both codegen paths, before the tower's own runtime code becomes one more thing every binary pays for unconditionally.

### A. Host-function prelude chunking

Split `RustCodegen::prelude()` (`rust-runtime/src/ir/codegen.rs`, currently one ~1600-line string) into named, independently-emittable chunks, derived directly from the existing `Host::call` match arms (a regrouping, not new design):

`core` (always included: `Value`, `Instr`, VM loop, `display_value`, list ops, event dispatch) · `strings_ext` · `collections_handles` (`vec_*`/`sb_*`) · `files` · `io_misc` · `oo` (`new`/`send`/`get` object arms) · `logic` (`fact`/`query`/`goal`) · `contracts` · `networking` (`tcp_*`) · `codegen_bootstrap` (`rustc_build`/`compile_shape`/`compile_ir`/`run_ir` — builder-only hosts, the single highest-value exclusion since end-user programs almost never need to shell out to `rustc` themselves) · `numeric_tower` (Stage 38) · `math` (Stage 39).

- `required_chunks(program: &Program) -> BTreeSet<ChunkId>` (new, in `codegen.rs`): one pass over every function's IR collecting distinct `Instr::CallHost(name, _)` names, mapped to chunks via a static table, plus transitive closure over the small cross-chunk dependency edges, plus `core` always. `numeric_tower` is a special case: since any `+ - * / %` could in principle overflow into bignum, include it whenever any numeric `BinOp` appears at all — flagged as a known conservative-inclusion limitation, not a bug, and not worth over-engineering away in this stage.
- `RustCodegen::prelude()` → `prelude_for(chunks: &BTreeSet<ChunkId>) -> String`, each chunk stored as its own `&'static str` constant; `emit_rust` computes `required_chunks` then calls `prelude_for`.
- **Mirror in `self_hosting/lib/codegen.patlang`**: an equivalent `required_chunks(ir)` walking the list-shaped IR's `CallHost` instructions — mechanical, consistent with the file's existing tag-dispatch style, no new language features needed.
- **Mirror in `self_hosting/lib/runtime_rs.patlang`**: split `emit_runtime_rs()` into per-chunk emitter functions (`emit_chunk_core()`, etc.) plus `emit_runtime_rs_for(chunk_names)` concatenating in the same fixed order the Rust side uses (order must match exactly or byte-for-byte parity breaks on ordering alone, independent of content).

**Parity test redesign** (`rust-runtime/tests/selfhost_pipeline.rs::selfhost_runtime_text_parity`): replace the current single whole-prelude string comparison with a per-chunk loop asserting `emit_chunk_by_name(name) == codegen_prelude_chunk(name)` for every chunk name — this also gives better failure localization than today's all-or-nothing diff. Keep one whole-program assertion (`prelude_for(all_chunks) == emit_runtime_rs_for(all_chunk_names)`) as a regression guard that the split itself didn't change concatenated output, diffed once against the pre-split monolith at the moment of the refactor.

New test `rust-runtime/tests/tree_shaking.rs`: compile a TCP-using vs a non-TCP program, assert the emitted Rust source text excludes/includes `tcp_listen` etc. accordingly; same for `oo`/`logic`/`codegen_bootstrap`.

### B. Dependency-aware `.patlang` library inclusion (file-level, general mechanism)

PatLang the language has no `import`/`export` syntax, and adding one is out of scope here — instead, a sidecar manifest: new `self_hosting/lib/deps.manifest` (same `name: dep1 dep2` format as `patbuild.manifest`) declaring file-level dependencies for `lexer`/`parser`/`lower`/`codegen`/`runtime_rs`/`math` etc. `rust-runtime/src/preprocess.rs::expand_includes` gains a `HashSet<canonical_path>`-based dedup (fixes the naive double-`include` duplication flaw) — this is the general-purpose safety net under the finer-grained mechanism in part C.

### C. Symbol-level shaking for `math.patlang` (built now, per the user's explicit choice)

New directive on `include`: `include "path" only [fn1, fn2, ...]` (confirm keyword style against `self_hosting/lib/parser.patlang`'s existing grammar conventions before finalizing syntax). Mechanism:
1. Parse the target file once with the existing lexer/parser (reuse, don't reinvent); walk the resulting `Stmt::Function` list to build `fn_name -> source_span` and `fn_name -> Set<called_fn_names>` (same style of walk as `lowering.rs`'s existing `collect_referenced_idents` used for closure free-variable analysis).
2. Given the requesting program's own call set (a `required_chunks`-style scan for `Call("sqrt", ...)` etc.), compute the transitive closure of needed library functions.
3. Splice only those functions' original source spans (line-range based, not AST-reserialized, to avoid whitespace/formatting drift) into the expansion, in place of whole-file concatenation.
4. Dedup `(canonical_path, fn_name)` pairs across the whole recursive expansion.

New tool `self_hosting/tools/tree_shake_lib.patlang` (or inlined into `codegen.patlang`) implementing the PatLang-side equivalent for the self-hosted front end, and `self_hosting/tools/patbuild_main.patlang`/`patbuild.manifest` updated so any `+`-joined component naming a `deps.manifest` entry with declared symbol-level info goes through this path instead of `read_bundle`'s raw concatenation.

---

## Stage 38 — Numeric tower reaches codegen (compiled-program parity)

Extend the Stage 36 tower into both codegen templates via the new `numeric_tower` chunk (Stage 37 mechanism), so the cost is opt-in per binary.

- Add `numeric_tower` chunk text to both `codegen.rs` and `runtime_rs.patlang` (private `Value` copy gains the same variants; `numeric::*` logic hand-transcribed into the template's Rust-text dialect, same process already used for every other host function). Covered by Stage 37's per-chunk parity test, so drift is caught immediately rather than silently.
- **BigInt in the emitted program is a separate decision from BigInt in the interpreter**: emitted programs are compiled via bare `rustc` on a single `.rs` file with zero `Cargo.toml`/dependencies (load-bearing for `rustc_build`'s offline/hermetic/no-`cargo` invariant) — switching to `cargo build` + a generated `Cargo.toml` just to depend on `num-bigint` is a materially bigger architecture change (touches WASM target detection, build caching, every `compile_source_to_exe` call site) and is **not** recommended. Instead: **hand-roll a self-contained BigInt** (`Vec<u32>` limbs, schoolbook multiply, simple long division) as plain Rust source text inside the `numeric_tower` chunk. This is a deliberate, documented asymmetry (crate in the interpreter's own `Cargo.toml`, hand-rolled limbs in the emitted-program template) — call it out explicitly in code comments at both definition sites so it doesn't look like an oversight.
- Because this creates two independent BigInt implementations that must behave identically, add a **cross-implementation property test** (`rust-runtime/tests/bignum_cross_path.rs`): random big-integer operation pairs, run through both the interpreter and a compiled binary (via `rustc_build` + `exec_capture`), assert identical string output. This is the concrete "live-test both paths" verification the numeric work needs, not just unit tests.
- Rational/Complex in the template: same hand-roll treatment (struct-pair arithmetic, no crate needed on either side), lower risk than BigInt.
- Wire the literal int/float discrimination from Stage 36 through the rest of the pipeline: `hosts.rs`'s `lower_shape_expr`/`decode_ir_instr` and `codegen.patlang`'s `emit_instr_rs` `"Const"` arm both need a numeric-kind discriminator, not just an f64 payload.

---

## Stage 39 — Math library

Hybrid design: a small set of `Host::` primitives (need direct access to tower internals) plus `self_hosting/lib/math.patlang` for everything expressible in terms of those primitives (cheaper to write/review, and gets the Stage 37 symbol-level shaking for free).

**Primitives** (new `Host::` arms in `hosts.rs`, mirrored in the `math` chunk in both codegen templates, and added to `Lowerer::is_allowed_host`'s allowlist in `lowering.rs` — a real, easy-to-miss footgun today since anything missing from that allowlist gets silently dropped from top-level statements with no error):
- `sqrt(x)` — real sqrt for `x >= 0` (exact `Int` result for perfect squares, `Float` otherwise); `x < 0` → `Complex(0, sqrt(-x))` — the user's explicitly named trigger case.
- `pow(base, exp)` — integer exponent on integer/rational base stays exact via repeated squaring through the tower's own arithmetic (promotes to BigInt on overflow exactly like `*` does); non-integer exponent or float base falls back to `f64::powf`.
- `sin/cos/tan/asin/acos/atan/atan2/log/exp` — thin `f64` wrappers (always inexact, standard for transcendentals).
- `floor/ceil/round/trunc` — exact for `Int`/`BigInt`/`Rational` inputs (e.g. floor of a rational is exact integer division), `f64` fallback for `Float`.
- `abs` — exact for all real kinds; complex modulus (`sqrt(re²+im²)`) for `Complex`.
- `numeric_kind(x) -> string` (or `is_int`/`is_float`/... predicates) — runtime introspection so PatLang code can branch on what representation a value ended up in, since there are no source-level type annotations.

**`self_hosting/lib/math.patlang`** (new): `hypot`, `factorial` (exercises bignum promotion via repeated `*` on large `n` — good smoke test), `gcd`/`lcm`, `clamp`, `sign`, `is_prime` (exercises bignum via `%`), basic stats (`mean`, `sum`). Each function gets a `deps.manifest` entry so the Stage 37-C symbol-level splice mechanism can shake it per-function.

Update `self_hosting/tools/agent_team.patlang` (lines ~80, 97) which currently documents "PatLang has no sqrt()" as a known test-harness limitation — remove/update once shipped, and consider exercising the AI-dev-team pipeline against a math task as a regression check.

---

## Verification plan

- `cargo test` additions: `numeric_tower.rs` (Stage 36, no `rustc` needed), `tree_shaking.rs` (Stage 37, inspects emitted source text only), `bignum_cross_path.rs` (Stage 38, needs `rustc`, follow the existing skip-if-no-rustc pattern from `selfhost_pipeline.rs`).
- Redesigned `selfhost_runtime_text_parity` (per-chunk) is the mechanical guardrail against the two hand-kept-in-sync codegen templates drifting — every new chunk added in Stage 38/39 must pass it before merge.
- New `selfhost_pipeline`/`selfhost_targets`-style integration tests modeled on existing ones (e.g. `selfhost_stage4_codegen_in_patlang`): compile a demo calling `sqrt`/`factorial` through the *self-hosted* front end, assert the emitted Rust excludes `networking`/`oo`/`logic` chunk text while including `numeric_tower`/`math`.
- Re-run the `#[ignore]`d fixpoint test (`selfhost_fixpoint_patc_compiles_itself`, ~7 min) manually after Stage 38/39 land — parity tests prove chunk *contents* match between the two templates, but not that `required_chunks` *selection logic* agrees on which chunks a given program needs; the fixpoint test is the strongest available check for that.
- **Live end-to-end verification** (not just automated tests — run these for real via `pat --ir-run` and a compiled `patc`-produced binary, diff stdout between the two):
  1. `let x = 9223372036854775800 + 1000` — confirm both paths show the correct bignum result, not wraparound or a panic.
  2. `let x = 10 / 3` — confirm both paths agree on the new exact-rational behavior (and don't just quietly still print a float — the actual point of this whole change).
  3. `sqrt(-1)` — confirm both paths report an identically formatted complex result.
  4. Compile the same small program twice (once bare, once additionally calling `tcp_listen`) — confirm the emitted source text and compiled binary size both differ, as a concrete "modularity worked" signal beyond source-grepping alone.
  5. Compile a program calling only `sqrt` from `math.patlang` — confirm the emitted source contains `sqrt`'s definition but not `factorial`/`is_prime`.
- Before Stage 36 lands: audit `self_hosting/examples/*.patlang` and any hardcoded stdout strings in `rust-runtime/tests/` for integer-division results that will change display format under the new rational-on-inexact-division rule, and update expected outputs deliberately (not as surprise test breakage).

---

## Future work (explicitly out of scope here): CUDA kernel generation

A later stage would need, at minimum: (1) a typed numeric array/vector `Value` variant — today the only collection is `Value::List(Vec<Value>)`, dynamically typed and heterogeneous, which a GPU kernel signature can't be generated from; (2) loop structure preserved through lowering instead of erased to raw `Instr::Jump`/`JumpIfFalse` gotos, since kernel generation needs a structured, bounded iteration space; (3) a generalized backend-selection abstraction, since `rustc_build`'s `target: Option<&str>` only knows how to pass strings to `rustc --target` and has no concept of an alternate toolchain (`nvcc`) or non-Rust source emission. No design work for CUDA itself is included in this plan.

## Critical files
- `rust-runtime/src/ir/types.rs`, `ir/ops.rs`, `ir/numeric.rs` (new), `ir/hosts.rs`, `ir/codegen.rs`, `ir/lowering.rs`, `src/lexer.rs`, `src/preprocess.rs`
- `self_hosting/lib/lexer.patlang`, `lib/parser.patlang`, `lib/lower.patlang`, `lib/codegen.patlang`, `lib/runtime_rs.patlang`, `lib/math.patlang` (new), `lib/deps.manifest` (new)
- `self_hosting/tools/patbuild_main.patlang`, `patbuild.manifest`, `tools/tree_shake_lib.patlang` (new), `tools/agent_team.patlang`
- `rust-runtime/tests/selfhost_pipeline.rs`, new `numeric_tower.rs`/`tree_shaking.rs`/`bignum_cross_path.rs`
- `rust-runtime/Cargo.toml` (add `num-bigint`)
