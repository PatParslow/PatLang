# PatLang

PatLang is a self-hosted programming language: its lexer, parser, lowerer,
and code generator are written in PatLang itself, not just as a bootstrap
exercise but as the actual, ongoing way PatLang programs get compiled.
Alongside the usual imperative/functional core it has a built-in
goal-oriented/logic-programming layer (facts, rules, `solve`, `plan`) and
an inductive-synthesis (ILP) engine that can learn rules from BDD-style
example scenarios.

This README describes the system as it exists today. If you're looking at
one of the many `*_REPORT.md` / `*_PLAN.md` files in the repo root and it
disagrees with this file, trust this file — most of those documents
describe an earlier, abandoned Ruby prototype and are kept only as
historical record.

## What actually works

- **A native Rust runtime** (`rust-runtime/`) — a real lexer, parser,
  interpreter, and native code generator, built as the `pat` binary.
- **A self-hosted compiler** (`self_hosting/lib/{lexer,parser,lower,codegen,
  runtime_rs}.patlang`) — the same pipeline, written in PatLang, bootstrapped
  into a standalone native binary (`patc1.exe`) that compiles ordinary
  PatLang programs without going through the Rust-native path.
- **Three execution paths, kept in parity on purpose**: interpreted
  (`pat --ir-run`), natively compiled via the Rust codegen (`pat --patc`),
  and compiled by the self-hosted compiler (`patc1.exe`). The test suite
  checks that all three agree — this cross-checking is how most real bugs
  in this project get found, including bugs in the self-hosted parser
  itself.
- **A numeric tower**: Int/Float/BigInt/Rational, auto-promoting on
  overflow rather than wrapping or crashing.
- **A goal-oriented/logic layer**: `fact`/`rule_add`/`solve`/`action_add`/
  `plan` — Prolog-ish querying and STRIPS-ish planning available as
  ordinary host functions, usable from otherwise-imperative code.
- **An inductive synthesis engine** (`self_hosting/lib/synthesis*.patlang`):
  least-general-generalization-based rule learning over BDD-authored
  example scenarios.
- **Contracts, a message queue, TCP sockets, non-blocking process spawn,
  and a signal/task-discovery layer** built on top of the message queue —
  enough to write small self-orchestrated multi-process demos entirely in
  PatLang (see `self_hosting/examples/microservices_demo.patlang`).
- **A real, if informal, test corpus**: 60+ Rust integration tests
  (`rust-runtime/tests/`), a BDD feature suite, and 25+ self-hosted
  PatLang selftests (`self_hosting/*_selftest.patlang`) exercising the
  synthesis engine, regex DSL, reflection/transpilation, and more.
- **A library of working example programs** (`self_hosting/examples/`,
  `portfolio/demos/`) — a CSV-backed transactional RDBMS with a SQL
  console, a hex-grid RTS economy sim, a build daemon, a maze solver, a
  family-tree/demographic simulator, and others — each runnable and each
  built to prove out a real language feature rather than as a toy.

## What it doesn't do

- **No package manager or module registry.** `include` is textual file
  concatenation; there's no versioning or dependency resolution.
- **No sandboxing.** Host functions give a PatLang program the same
  privileges as the user running it: arbitrary process execution
  (`exec_capture`), unrestricted filesystem read/write/delete, and raw TCP.
  Fine for scripts you wrote yourself; do not run untrusted PatLang source
  without wrapping it in an external sandbox (container, VM, restricted
  user account) first.
- **No editor tooling.** No LSP, no debugger, no formatter, no linter.
- **No performance benchmarking against other languages.** The runtime is
  Rust-backed and the self-hosted path produces real native binaries, but
  there's no published data on how either compares to established
  languages on non-trivial workloads.
- **Single-maintainer, no external users yet.** Everything above is
  proven against its own test suite and example programs, not against
  outside use.

## Quick start

You need a Rust toolchain for one bootstrap step only.

```bash
cd rust-runtime
cargo build --release
```

This produces `pat` (`pat.exe` on Windows) — the runner and compiler
driver. From the repo root:

```bash
# Interpret directly (recommended for everyday use)
rust-runtime/target/release/pat --ir-run hello.patlang

# Compile via the native Rust codegen
rust-runtime/target/release/pat --patc hello.patlang --out hello.exe

# Compile via the self-hosted compiler (rebuild it first if it's stale)
rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang
./patc1.exe hello.patlang hello.exe
```

`hello.patlang`:

```patlang
let name = "world"
print("hello, " + name)
```

See [`TUTORIAL.md`](TUTORIAL.md) for a fuller walkthrough of all three
execution paths and the language's main paradigms, and
[`CLAUDE.md`](CLAUDE.md) for the project's own working conventions
(when to use `patc1.exe` vs the native pipeline, and the discipline for
keeping the self-hosted mirror in sync with the Rust runtime).

## Running the tests

```bash
cargo test --release --manifest-path rust-runtime/Cargo.toml
```

Self-hosted selftests are run directly as PatLang programs, e.g.:

```bash
rust-runtime/target/release/pat --ir-run self_hosting/synthesis_lgg_selftest.patlang
```

## Project layout

```
/
├── rust-runtime/          # The native Rust implementation: lexer, parser,
│                           # interpreter, native codegen, host functions,
│                           # and the Rust-side integration test suite.
├── self_hosting/
│   ├── lib/                # The self-hosted compiler and standard library,
│   │                        # written in PatLang (lexer/parser/lower/codegen,
│   │                        # synthesis engine, RDBMS, regex, math, etc.)
│   ├── examples/            # Runnable demo programs.
│   └── *_selftest.patlang   # Self-hosted test suites.
├── portfolio/demos/        # Browser-facing HTML wrappers for demos.
├── patc1.exe                # The bootstrapped self-hosted compiler binary
│                            # (rebuild via self_hosting/build_patc1.patlang).
├── TUTORIAL.md              # Start here for a hands-on introduction.
└── CLAUDE.md                # Working conventions for this repo.
```

Most of the other root-level `*.md` files predate the current
architecture and are kept for historical reference only.

---

**PatLang** — a self-hosted language for exploring goal-oriented and
logic-programming constructs alongside an ordinary imperative core.
