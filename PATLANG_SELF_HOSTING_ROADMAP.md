# PatLang Self-Hosting Roadmap

This document outlines the pragmatic next steps to reach self-hosting by leveraging the existing PatLang implementations of the lexer, parser, and evaluator, while keeping Stage 0 semantics small and focused.

## status update (July 4, 2026): closures

Real closures landed in both Stage 0 (Rust) and Stage 1 (self-hosted):

- `Value::Closure { func_name, captured }` — a closure value is a synthesized
  function name plus a snapshot of its captured environment. `Instr::MakeClosure`
  bundles N stack values (pushed via `LoadLocal`) into a closure; `Instr::CallValue`
  pops a closure value plus call args and dispatches to the synthesized function
  (captured values become its leading hidden parameters).
- Stage 0 (`rust-runtime/src/ir/lowering.rs`): a real free-variable analysis
  (`collect_referenced_idents`/`collect_let_bound_names`) walks a closure
  literal's body, intersects referenced identifiers with the enclosing
  `known_locals`, and captures exactly those — including transitively through
  nested closures. `Expr::Call` on an identifier now disambiguates three ways:
  known top-level function → `Call`, known local variable → `CallValue`
  (dynamic dispatch through whatever closure value it holds), otherwise → `CallHost`.
- Stage 1 (`self_hosting/lib/*.patlang`): same design, simplified — rather than
  precise free-variable analysis, a closure captures its *entire* enclosing
  locals list (over-capture). This is correct by construction given the flat
  per-call locals map already used throughout: a closure's own `let` of a
  same-named variable just overwrites the pre-bound captured slot, which is
  exactly the intended shadowing behaviour, so no exclusion logic is needed.
  `locals` and a `pending` (synthesized closure functions) vec are threaded
  as extra parameters through `lower_expr`/`lower_stmt`/`lower_block`.
  Closure syntax is `|params| do body end` (not Stage 0's `{ }`), matching
  Stage 1's brace-free block convention everywhere else; immediately-invoked
  closure literals aren't supported yet (the `Call` AST node assumes a
  string callee name — calling through a named variable holding a closure
  works fine).
- Verified end-to-end: interpreted, compiled natively (rustc) via both the
  Stage 0 and Stage 1 codegen paths — nested closures capturing an
  enclosing function's own parameter, closures as higher-order arguments,
  and value-semantics capture snapshots (reassigning the outer variable
  after closure creation doesn't change what the closure sees). Regression
  tests: `rust-runtime/tests/closures.rs` (Stage 0, 6 tests) and
  `selfhost_targets.rs::stage1_closures_native` (Stage 1).
- Prelude regenerated (`Value`/`Instr` enum additions + VM loop are part of
  the fixed runtime text baked into every emitted program).

## status update (July 4, 2026): design by contract + dev-tool portfolio wiring

**Design by contract** (`require`/`ensure`/`assert`) landed as a genuine
VM-level semantic, not a codegen feature — deliberately, since rustc is the
slow part of this stack and contract *checking* has nothing to do with it:

- New `Stmt::Assert { kind, expr }` in both the Stage 0 Rust AST/parser/
  lowerer and the Stage 1 self-hosted parser/lowerer (`self_hosting/lib/
  parser.patlang` reuses its own `ast_to_str` to render violation messages;
  `lower.patlang` threads a `fname` parameter through `lower_block`/
  `lower_stmt` for "which function" context).
- One shared `contract_check(func_name, kind, text, ok)` host arm, present
  verbatim in both the interpreter (`ir/hosts.rs`) and the emitted-program
  codegen template (`ir/codegen.rs`) — so enforcement is byte-for-byte
  identical whether a program is interpreted, executed via `run_ir` (no
  rustc — the browser-playground path), or compiled natively. Proved this
  explicitly: a precondition violation was demonstrated through all three
  paths before anything else was built on top.
- `ensure` is checked wherever it's written (not wrapped around every
  `return`), so multi-exit functions just repeat `ensure` before whichever
  exits they want checked — no hidden control-flow rewriting.
- `self_hosting/examples/contracts_demo.patlang`: passing require/ensure/
  assert on `safe_divide`/`clamp`/`factorial`, then one deliberate
  precondition violation, so the demo shows enforcement actually firing.
- `host_exec_capture` now appends stderr when the process exits non-zero,
  so native transcripts of intentionally-failing demos show the violation
  message instead of silently truncating.
- Found and fixed one non-ASCII character (an em dash in a new codegen
  comment) that broke the prelude byte-parity test — a reminder that the
  "prelude must be pure ASCII" invariant from the performance work
  (stage 7) is easy to violate accidentally and is caught immediately by
  `selfhost_runtime_text_parity`.

**Dev tools wired more deeply into the portfolio:**
- `flowgraph` now renders *multiple* programs into one navigable page
  (`<flowgraph <output.html> [inputs...]>`; with no arguments it renders a
  curated set — the benchmark, the contracts demo, the point-of-sale
  bundle, and the all-paradigms demo). Rendering IR doesn't require
  semantic resolution, so a library+driver pair can be bundled with a
  `lib.patlang+demo.patlang` spec without needing a real module system.
- `patbuild.manifest` gained `contracts_demo` and `pos_demo` as real
  targets; `patbuild_main.patlang` gained the same `+`-bundling convention
  (`read_bundle`) so a manifest target can combine a library with its
  driver.
- Portfolio gained a `contracts` card (runnable in-browser, showing both
  the passing checks and the violation) and the playground's example
  selector now includes it.

**Bug found and fixed while writing the curated flowgraph list:** the
Stage 1 self-hosted lexer emits an explicit `NL` token for every newline
with no bracket-depth suppression (unlike the Stage 0 Rust lexer, which
already tolerates newlines around brackets). A multi-line list literal or
function call therefore desugared into a swallowed parse error — silently,
because the malformed `Err` node fell through `lower_expr`'s catch-all into
an empty string, so `xs.length` on a "broken" 3-element list literal
quietly read `0` instead of raising anything. Fixed by having
`parser.patlang`'s list-literal and `parse_args` loops call `skip_nl`
around `[`/`(`, `,`, and `]`/`)`, matching the Stage 0 parser's existing
tolerance. Caught by writing `flowgraph`'s curated example list across
multiple lines for readability and noticing the published page came out
empty — a good reminder that the two parsers (Rust and self-hosted) can
still drift on tolerances that were only ever added to one side. Regression
test: `selfhost_targets.rs::stage1_multiline_lists_and_calls`.

## status update (July 3, 2026): Stage 1 front-end is self-hosted

The compiler front-end (lexer + parser) now runs in PatLang, executed by the
Stage 0 runtime, and drives native compilation end-to-end:

- `self_hosting/lib/lexer.patlang` — tokenizer written in the Stage 0
  compilable subset. Runs under `pat --ir-run` AND compiles to a native exe via
  patc with identical output (verified by `tests/selfhost_lexer.rs`).
- `self_hosting/lib/parser.patlang` — recursive-descent parser producing
  list-shaped AST nodes (`["Program", [stmts]]`, `["Let", name, expr]`,
  `["Bin", op, l, r]`, ...). Handles precedence, parens, strings.
- `self_hosting/pipeline_stage1.patlang` — full pipeline: PatLang lexer →
  PatLang parser → `compile_shape` host (AST-shape → Stage 0 IR → rustc) →
  native executable. Verified by `tests/selfhost_pipeline.rs`.
- `include "path"` preprocessor added to Stage 0 (interpreter + patc paths) as
  the minimal module mechanism for self-hosted sources.
- Language/runtime additions that made this possible: `!=` operator, index
  expressions `xs[i]`, string escapes in literals, lexicographic string
  comparison, host shims (`list_push`, `char_code`, `substr`, `to_num`,
  `read_file`, `compile_shape`), forward-reference/mutual-recursion support in
  the lowerer, `while` accepted inside function/if/while bodies (parser bug).

Current grammar of the self-hosted parser (Stage 1, extended July 3, 2026):
`let`, general call statements, `if/then/else/end`, `while/do/end`,
`make a function called N takes a, b returns r ... end`, `return`,
`when EVENT do ... end` event handlers, list literals, indexing `xs[i]`,
member access `.length`/`.prop`, `and`/`or`/`not`, unary minus, bool literals.

Feature coverage through the self-hosted front-end (all natively compiled and
output-verified by `tests/selfhost_pipeline.rs` via
`self_hosting/examples/feature_demo.patlang`):
- functions + recursion, full control flow, lists
- **event-driven**: `when` handlers + `emit` (IR event_handlers in both the
  IR interpreter and compiled programs)
- **logic**: `fact`/`query`/`goal` hosts (thread-local FACTS, parity between
  interpreted and compiled runs via `ir/hosts.rs`)
- **OO**: `new`/`send`/`get` against the named-object store
- **functional**: `apply(fname, args...)` call-by-name in both VMs enables
  map/filter/reduce written in PatLang (see feature_demo)
- **networking**: blocking TCP hosts (`tcp_listen`/`tcp_accept`/`tcp_read`/
  `tcp_write`/`tcp_close`, plus `chr`) in both VMs; a working HTTP echo server
  written in Stage 1 PatLang compiles natively and answers real requests
  (`self_hosting/examples/echo_server.patlang`, verified by
  `selfhost_pipeline_compiles_tcp_echo_server`)
- **WebAssembly** (July 4, 2026): `rustc_build(rs, out, "wasm32-wasip1")`
  cross-compiles emitted programs unchanged; the feature demo runs under
  Node's WASI with identical output (`wasm_target_compiles_and_runs_feature_demo`)
- **browser GUI** (July 4, 2026): `lib/html.patlang` builds well-formed
  HTML5+JS pages; `examples/gui_demo.patlang` (static interactive page via
  write_file) and `examples/gui_server_demo.patlang` (native PatLang server
  serving the page plus live JSON consumed by the page's fetch) — verified by
  `selfhost_targets.rs`

### next steps toward full self-hosting
1. ✅ DONE (July 3, 2026): AST → IR lowering moved into PatLang.
   `self_hosting/lib/lower.patlang` emits list-shaped IR instructions (with
   jump patching via the new `list_set` host); the `compile_ir` host only
   decodes finished IR and runs codegen + rustc. `pipeline_stage3.patlang`
   runs lexer + parser + lowerer all in PatLang; verified by
   `selfhost_stage3_lowering_in_patlang` (identical output to stage 2).
2. ✅ DONE (July 3, 2026, step 2a): Rust source emission moved into PatLang.
   `self_hosting/lib/codegen.patlang` walks the IR shape and generates the
   program-builder Rust text (rs_escape/rs_str built with chr(), staying in
   the escape-free Stage 1 dialect); hosts shrank to `codegen_prelude()`
   (fixed runtime library string) and `rustc_build(source, out)` (write +
   rustc). `pipeline_stage4.patlang` runs lexer + parser + lowerer + codegen
   all in PatLang; verified by `selfhost_stage4_codegen_in_patlang`.
   ✅ DONE (July 3, 2026, step 2b): **THE FIXPOINT IS ACHIEVED.**
   The compiler libs were already expressible in the Stage 1 dialect. With
   `argv`/`write_file` hosts and a `rustc_build` arm in the emitted-program
   template, plus the runtime prelude exported to
   `self_hosting/runtime/prelude.rs` (read at compile time — resolving the
   quine problem the standard way, by shipping the runtime as a file):
   - Gen A: `build_patc1.patlang` (interpreter) compiles the concatenated
     compiler source (36 KB, 7787 tokens, 41 functions) → native `patc1.exe`
   - Gen B: `patc1.exe` compiles feature_demo in 3.5 s (~65x faster than the
     interpreted pipeline) with correct output
   - Gen C: `patc1.exe` compiles its own source → `patc2.exe`, which compiles
     feature_demo identically; patc1 and patc2 emit **byte-identical Rust**
     for the same input
   Verified by `selfhost_fixpoint_patc_compiles_itself`
   (`cargo test --test selfhost_pipeline -- --ignored`, ~7 min).
   PatLang development is now independent of other languages: the compiler is
   written in PatLang and compiles itself; the host contributions are the
   fixed prelude file (a runtime library artifact) and rustc as the machine
   back end.
   ✅ EXTENDED (July 4, 2026): the runtime prelude is now PatLang source too.
   `self_hosting/lib/runtime_rs.patlang` (generated by
   `tools/transcribe_prelude.py`, parity-checked byte-for-byte against the
   host template by `selfhost_runtime_text_parity`) emits the runtime text,
   and `emit_program_rs` uses it — every byte of an emitted program
   originates from .patlang files. The bootstrap seed is exactly: rustc +
   the Stage 0 interpreter (used once for Gen A). Fixpoint re-verified with
   byte-identical emission. Also stage 7 performance: vec/sb/intern builder
   hosts made the pipeline O(n) (Gen A 3m51s -> 45s before runtime-in-PatLang;
   with it, Gen A ~9 min / self-compile ~7 min, dominated by rustc chewing on
   the 900 KB emitted compiler source).
3. Switch `patc.patlang` internals from `patc_compile_from_argv` delegation to
   the native lexer/parser pipeline, keeping the host path as a fallback flag.
4. Grow the Stage 1 language until it can express `self_hosting/lib/*` itself
   (remaining gaps: string escape decoding in the Stage 1 lexer, `include` at
   the Stage 1 level, closures proper rather than call-by-name).
5. Async: build an event loop over the existing event system (blocking TCP
   hosts landed July 3, 2026; concurrency/async dispatch is the open half —
   e.g. accept-loop emitting request events to `when` handlers, timers).

Note: the older `native_lexer/`, `native_parser/`, `native_evaluator/` sources
are written in a richer aspirational dialect that parses under Stage 0 (kept
green by `tests/bootstrap_native_pipeline.rs`) but does not execute; the
runnable self-hosted implementation lives in `self_hosting/`.

## current status

- CLI/runtime
  - patc compiles directly with rustc -o to the target path and prints the canonical output path.
  - Compare mode aligns interpreter vs compiled by returning text from print in interpreter during compare.
- Parser tolerances (Stage 0)
  - Ruby-like `if ... then ... else ... end` accepted (Else token supported).
  - Statement separators relaxed between top-level statements and within blocks; still require a separator when two statements are on the same line (semicolon or newline).
  - Inline “make a function … takes … returns … end” parsed; optional implicit return of hinted var.
  - Accept `=` as equality (maps to Equal) in expressions.
  - Postfix `{ ... }` blocks treated as closures (attach to previous call where applicable), while avoiding consuming the `{}` after an `if`/`elif` condition.
  - Goal/Rule recognized and skipped when used as DSL headers; treat `goal(...)` and `rule(...)` as normal function calls.
  - DSL keywords are handled case-insensitively (e.g., `Goal`, `Rule`, `Fact`).
  - Newlines tolerated around brace-style `if {}` and before `else`/`elif` blocks.
  - Label lines like `precondition:`, `postcondition:`, `strategy:` tolerated/skipped.
- Native sources
  - `native_lexer.patlang`, `native_parser.patlang`, and `core_evaluator.patlang` parse under the current evaluator without fatal parse errors.

### recent progress (Aug 10, 2025)

- Fixed a regression in brace-style `if { ... } else { ... }` parsing and added tolerance for newlines around blocks; all parser and lowering smoke tests pass.
- Hardened DSL compatibility: case-insensitive `Goal/Rule/Fact`, and `goal(...)`/`rule(...)` treated as calls; label lines and relationship/activate/case/query/while blocks skipped.
- End-to-end tests are green across suites (warnings only).
- Compiled the `docs/examples/webserver.patlang` example to a native Windows executable via `--patc` (see Try it).
- Minimal native patc bootstrap: added built-ins `patc_compile`, `patc_compile_from_argv`, and argv helpers; `patc.patlang` now delegates to the Stage 0 backend and prints the canonical exe path. Verified by producing `demo2.exe` from `demo.patlang`.
- Reduced default noise: evaluator/parser debug logs are gated behind the `PATLANG_DEBUG` env var.

## objective

Run the native PatLang lexer → parser → evaluator on small programs and progressively wire their outputs into the Stage 0 IR and patc pipeline, moving toward a self-hosted path without expanding Stage 0 semantics beyond necessity.

## step-by-step plan

1) Lock parser compatibility and coverage (tests)
- Add unit tests for now-tolerated constructs:
  - Ruby-if with `then/else/end`.
  - Label lines with colon (precondition/postcondition/strategy).
  - Goal/Rule/Fact lines and multi-line `Rule ... .` blocks.
  - Inline make-a-function blocks (with `takes` / `returns`).
  - Postfix closure blocks `{ ... }` after calls.
  - Relaxed statement separators.
- Edge cases to include:
  - Nested closures and trailing-block calls.
  - Equality with single `=` vs `==`.
  - Interleaved DSL constructs with expressions.
- Deliverables: tests under `rust-runtime/tests/` covering each case; keep Stage 0 behavior minimal (parse/skip, no heavy semantics).

2) Evaluate native_lexer.patlang end-to-end
- Harness: a tiny `.patlang` driver that calls `initialize_lexer`, runs a few scanning functions (`skip_whitespace`, `extract_number`), and prints a summary (e.g., `current_position/current_line` and token count).
- Stretch: tokenize a short example (like one or two statements) and sanity-check token types/length (not deep validation yet).

3) Evaluate native_parser.patlang end-to-end
- Build a small token fixture encoded as lists/maps the evaluator can handle (e.g., `{type: "IDENTIFIER", value: "x"}`).
- Call `parse_program(tokens)` and print a summarized AST shape (node counts/types).
- Stretch: Feed output of native_lexer for a tiny input into native_parser to close the loop.

4) Evaluate native_evaluator/core_evaluator.patlang on tiny ASTs
- Construct a minimal Program-like structure (NumberLiteral, StringLiteral, BinaryOperation) and call `evaluate_program` or `evaluate_ast_node`.
- Print final value/type to confirm dispatch works.

5) Define a simple interchange schema
- Token (example): `{type: "IDENTIFIER", value: "foo", line: 1, col: 2}`.
- AST Node (example): `{type: "NumberLiteral", value: 42}`.
- Value (example): `{type: "String", data: "ok"}`.
- Use plain lists/maps to make interchange easy for both native .patlang and the Stage 0 runtime.

6) Bridge shims in the evaluator
- Ensure small host helpers exist where needed:
  - Strings: interpolation (already supported), basic ops.
  - Lists: `list_new`, `map/filter/reduce/any?/unique_by` (supported across evaluator + builtins).
  - Variables/objects: `set_var/get`, simple object store accessors.
- Optional: add a tiny helper to construct ad-hoc maps/records from `.patlang` when encoding tokens or AST nodes.

7) Bootstrap pipeline (self-host smoke)
- A `.patlang` script that:
  - Runs native_lexer on a tiny program string.
  - Feeds tokens to native_parser to produce an AST shape.
  - Invokes native_evaluator on that AST to compute a final value.
- Validate with 2–3 tiny programs: arithmetic, print, and a short list pipeline (`[1,2,3].map { |x| x + 1 }`).

7.1) Native patc CLI (bootstrap achieved)
- Current: `patc.patlang` calls `patc_compile_from_argv()` (new host built-in) to reuse the Rust Stage 0 pipeline.
- Next: improve CLI UX and error surfaces in `.patlang` (usage, exit codes), then gradually switch its internals to the native lexer/parser when ready.

8) Integrate with Stage 0 IR/codegen
- Write a converter that lowers the AST shape (maps/lists) produced by native_parser into Stage 0 AST/IR structs used by `Lowerer`.
- From there, use existing Rust codegen to emit and patc to produce a native .exe.
- Milestone: patc compiling a small program where the AST was produced by the native parser.

8.1) Wire `patc.patlang` to native parser
- Replace the internal call to `patc_compile_*` with: native_lexer + native_parser → AST-shape → call a new host lowering function to Stage 0 IR → Rust codegen.
- Keep `patc_compile_*` as a fallback switch (env/flag) until parity is proven.

9) Quality gates and documentation
- Minimal CI: cargo test includes the parser tolerance tests and the bootstrap smoke.
- Documentation:
  - Update/extend this roadmap with a status table (lexer/parser/evaluator: parse/run/interop).
  - Add a small README in a `self_hosting/` examples folder describing the bootstrap demos.

## risks and mitigations
- DSL breadth: The native sources use richer constructs than Stage 0. Mitigate by “parse/skip” tolerances and keeping the interchange schema simple.
- Data encoding friction: Standardize on plain maps/lists with a small set of required keys to connect components.
- Debug verbosity: Keep lexer/parser debug prints behind env flags to avoid noisy runs.

## quick try (optional)

- Compare check (kept green):
  - arithmetic and control_flow examples via `--compare` are OK.
- patc stable output:
  - `docs/examples/sed_demo.exe` and `docs/examples/event_demo.exe` are emitted directly by rustc -o.
- Parse native sources:
  - `native_lexer.patlang`, `native_parser.patlang`, and `core_evaluator.patlang` currently parse under the evaluator without fatal parse errors.

Try the webserver demo (Windows, from `rust-runtime`):

```bash
cd e:/patlang/rust-runtime
# Run without producing an exe (build-run path)
cargo run -- --build-run ../docs/examples/webserver.patlang

# Compile to a native exe with patc
cargo run -- --patc ../docs/examples/webserver.patlang --out ../docs/examples/webserver.exe

# Then run the exe (starts a localhost server on the configured port)
../docs/examples/webserver.exe
```

Note: The server prints a keepalive message and listens on the port set in the script (8123 in the example). Press Ctrl+C to stop.

Try the minimal native patc (bootstrap path):

```bash
cd e:/patlang
# Using the built binary
./rust-runtime/target/debug/pat ./patc.patlang ./demo.patlang --out ./demo2.exe

# Or via cargo
cd e:/patlang/rust-runtime
cargo run -- ../patc.patlang ../demo.patlang --out ../demo3.exe
```

Tip: Set `PATLANG_DEBUG=1` to see detailed evaluator/parser logs during bootstrap debugging.

## deliverables summary
- Parser tolerance tests (short, focused).
- Tiny `.patlang` harnesses: lexer demo, parser demo, evaluator demo.
- Bootstrap `.patlang` pipeline wiring all three.
- AST-to-IR lowering adapter for integration with codegen/patc.
- README + status matrix.

### immediate next steps

- Define the minimal token/AST interchange (maps/lists). If needed, add small helper constructors (e.g., `map_new`, `map_set`) to ease encoding from `.patlang`.
- Create a tiny `.patlang` lexer harness to produce a token list for a 2–3 line program and print a summary.
- Build the native-parser harness to accept that token list and print a compact AST shape.
- Implement the AST-shape → Stage 0 AST/IR adapter and add a smoke test that compiles a tiny program end-to-end via the native parser.
- Enhance `patc.patlang` UX: usage/help, error codes, and a fallback flag to force the Stage 0 backend while native parity is in progress.

---
Maintaining a small Stage 0 while leaning on the native `.patlang` implementations lets us iterate quickly toward self-hosting without overcommitting semantics early.
