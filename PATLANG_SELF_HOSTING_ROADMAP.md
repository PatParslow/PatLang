# PatLang Self-Hosting Roadmap

This document outlines the pragmatic next steps to reach self-hosting by leveraging the existing PatLang implementations of the lexer, parser, and evaluator, while keeping Stage 0 semantics small and focused.

## current status

- CLI/runtime
  - patc compiles directly with rustc -o to the target path and prints the canonical output path.
  - Compare mode aligns interpreter vs compiled by returning text from print in interpreter during compare.
- Parser tolerances (Stage 0)
  - Ruby-like `if ... then ... else ... end` accepted (Else token supported).
  - Statement separators relaxed between top-level statements and within blocks.
  - Inline “make a function … takes … returns … end” parsed; optional implicit return of hinted var.
  - Accept `=` as equality (maps to Equal) in expressions.
  - Postfix `{ ... }` blocks treated as closures (attach to previous call where applicable).
  - Goal/Rule recognized and skipped; multi-line rule termination by trailing `.` tolerated.
  - Label lines like `precondition:`, `postcondition:`, `strategy:` tolerated/skipped.
- Native sources
  - `native_lexer.patlang`, `native_parser.patlang`, and `core_evaluator.patlang` parse under the current evaluator without fatal parse errors.

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

8) Integrate with Stage 0 IR/codegen
- Write a converter that lowers the AST shape (maps/lists) produced by native_parser into Stage 0 AST/IR structs used by `Lowerer`.
- From there, use existing Rust codegen to emit and patc to produce a native .exe.
- Milestone: patc compiling a small program where the AST was produced by the native parser.

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

## deliverables summary
- Parser tolerance tests (short, focused).
- Tiny `.patlang` harnesses: lexer demo, parser demo, evaluator demo.
- Bootstrap `.patlang` pipeline wiring all three.
- AST-to-IR lowering adapter for integration with codegen/patc.
- README + status matrix.

---
Maintaining a small Stage 0 while leaning on the native `.patlang` implementations lets us iterate quickly toward self-hosting without overcommitting semantics early.
