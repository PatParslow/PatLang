# PatLang Self-Hosting Roadmap

This document outlines the pragmatic next steps to reach self-hosting by leveraging the existing PatLang implementations of the lexer, parser, and evaluator, while keeping Stage 0 semantics small and focused.

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

### next steps toward full self-hosting
1. ✅ DONE (July 3, 2026): AST → IR lowering moved into PatLang.
   `self_hosting/lib/lower.patlang` emits list-shaped IR instructions (with
   jump patching via the new `list_set` host); the `compile_ir` host only
   decodes finished IR and runs codegen + rustc. `pipeline_stage3.patlang`
   runs lexer + parser + lowerer all in PatLang; verified by
   `selfhost_stage3_lowering_in_patlang` (identical output to stage 2).
2. Embed codegen in compiled programs so a natively compiled patc can compile
   without the `pat` interpreter (true fixpoint: patc.exe compiles patc).
   Next concrete piece: emit the Rust source text from PatLang too (walk the
   IR shape and build the program-builder section as a string), leaving only
   "write file + invoke rustc" on the host.
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
