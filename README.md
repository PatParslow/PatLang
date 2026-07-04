# PatLang

PatLang is a multi-paradigm programming language (functions, control flow,
lists, closures, and design-by-contract; object-orientation via
`new`/`send`/`get`; logic programming via `fact`/`query`/`goal`; events via
`when`/`emit`; networking via `tcp_*` hosts) with a **fully self-hosted
compiler**: the lexer, parser, lowerer, and code generator are all written
in PatLang, and compile themselves.

## Repository layout

- **`rust-runtime/`** — the Stage 0 runtime: a Rust interpreter/compiler that
  bootstraps everything else. Provides an IR-based lexer → parser → lowerer
  → codegen(Rust) → `rustc` pipeline, plus a direct IR interpreter
  (`run_ir`) used for day-to-day development so `rustc` isn't needed after
  the initial build.
- **`self_hosting/`** — the PatLang compiler, written in PatLang
  (`lib/lexer.patlang`, `lib/parser.patlang`, `lib/lower.patlang`,
  `lib/codegen.patlang`), plus example programs (`examples/`) and dev
  tooling (`tools/`: a goal-oriented build system, a test framework with
  Gherkin support, and a control-flow-graph renderer).
- **`portfolio/`** — a generated, self-contained set of HTML pages
  showcasing the language: a live in-browser playground and IDE (the
  compiler itself compiled to WebAssembly), a maze solver, and a
  project-report simulator demonstrating goal-oriented programming with
  worker delegation, QA review gates, and feedback loops. Regenerate with
  `pat --ir-run self_hosting/tools/build_portfolio.patlang`.
- **`archive/`** — documentation from an earlier, abandoned implementation
  approach (a Ruby interpreter + a separate C runtime prototype). Unrelated
  to the current system; kept for historical reference only.

## Getting started

See [`TUTORIAL.md`](TUTORIAL.md) for a full walkthrough: building the
runtime, your first program, a tour of every paradigm, and the self-hosting
pipeline. The one-time bootstrap step is:

```bash
cd rust-runtime
cargo build --release
```

After that, running or "compiling" PatLang programs during normal
development never needs `rustc` again:

```bash
rust-runtime/target/release/pat --ir-run self_hosting/examples/feature_demo.patlang
```

`rustc`/`cargo` only come back into play if you deliberately want a
standalone native or WebAssembly binary — see the tutorial's sections on
`--patc` and `rustc_build`.

## Self-hosting

[`PATLANG_SELF_HOSTING_ROADMAP.md`](PATLANG_SELF_HOSTING_ROADMAP.md) is the
staged history of how PatLang came to compile itself, from a Rust seed to
byte-for-byte self-compilation (`patc1.exe` compiling its own source into
`patc2.exe`, producing identical output), through closures, design by
contract, and the browser-based tooling.

## Tests

```bash
cd rust-runtime
cargo test
```
