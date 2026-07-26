# PatLang

PatLang is a self-hosted programming language: its lexer, parser, lowerer,
and code generator are written in PatLang itself, not just as a bootstrap
exercise but as the actual, ongoing way PatLang programs get compiled.
Alongside the usual imperative/functional core it has a built-in
goal-oriented/logic-programming layer (facts, rules, `solve`, real
backward-chaining inference, `action_add`/`plan` GOAP planning) and an
inductive-synthesis (ILP) engine that can learn rules — and, increasingly,
whole small programs — from BDD-style example scenarios, verified by
actually searching for them rather than being told the answer.

Importantly, it is basically an experiment in developing a programming
language that covers all of the major paradigms of programming: imperative,
functional, goal-oriented, logic-programming, OO (including real single
inheritance, composable traits, and method dispatch), design by contract,
and so on. But it is also an experiment in doing so without writing a single
line of code, nor any of the formalised BDD specs, by hand — the
human-in-the-loop designed the concept, directs the development, and
AI agents developed the code, and the documentation. Part of that
experiment is treating every claimed result as something to be verified,
not assumed: several results in this project's history (including some in
its own synthesis-registry work) were caught as vacuous or outright wrong
*after* looking correct, and the fix each time was a genuine RED→GREEN
discipline, not a stricter-sounding claim.

This README describes the system as it exists today. If you're looking at
one of the many `*_REPORT.md` / `*_PLAN.md` files in the repo root and it
disagrees with this file, trust this file — most of those documents
describe an earlier, abandoned Ruby prototype and are kept only as
historical record.

## Requirements

- **Rust, stable, supporting the 2024 edition** (Rust 1.85+; developed
  against 1.88). `cargo build --release` fetches its own dependencies
  (`tokio`, `hyper`, `serde`, `uuid`, etc.) from crates.io, so the first
  build needs network access.
- **A working system linker** for whatever target you're compiling to —
  `rustc` (invoked by `pat --patc` and by `patc1.exe`) shells out to the
  platform linker to turn generated Rust into a real executable (MSVC's
  `link.exe` on Windows, `cc`/`ld` on Linux/macOS). This is the same
  linker your Rust toolchain already needs to build anything else.
- **Python 3**, needed only for `tools/regen_runtime_rs.py` — the script
  that keeps the self-hosted compiler's own mirror of the Rust runtime's
  host-function text in sync after a `hosts.rs`/`codegen.rs` change (see
  `CLAUDE.md`'s "Do not leave the self-hosted mirror behind"). Not needed
  for ordinary compiling or running PatLang programs.
- **Optional, for WebAssembly targets**:
  - `rustup target add wasm32-wasip1` for the ordinary (non-threaded) WASM
    target.
  - A **nightly** Rust toolchain (`rustup toolchain install nightly`,
    `rustup target add wasm32-wasip1-threads --toolchain nightly`) for the
    threaded WASM target, since real OS-thread-backed fibers/`budgeted(...)`
    compiled to WASM need atomics/shared-memory support that's only
    prebuilt against the standard library on nightly.
  - `wasmtime` (or any WASI-preview1 runtime with threads support), only
    if you want to run a compiled `.wasm` binary locally outside a
    browser — the portfolio demos' own "run in browser" buttons don't
    need it, they run in the browser's own WebAssembly engine via a
    hand-rolled WASI-threads JS shim.

Nothing else is required for everyday use: `pat --ir-run` (the
interpreter) needs only the `pat` binary itself once built.

## What actually works

- **A native Rust runtime** (`rust-runtime/`) — a real lexer, parser,
  interpreter, and native code generator, built as the `pat` binary.
- **A self-hosted compiler** (`self_hosting/lib/{lexer,parser,lower,codegen,
  runtime_rs}.patlang`) — the same pipeline, written in PatLang, bootstrapped
  into a standalone native binary (`patc1.exe`) that compiles ordinary
  PatLang programs without going through the Rust-native path.
- **Four execution paths, kept in parity on purpose**: interpreted
  (`pat --ir-run`), natively compiled via the Rust codegen (`pat --patc`),
  compiled by the self-hosted compiler (`patc1.exe`), and compiled to
  WebAssembly (plain `wasm32-wasip1`, or `wasm32-wasip1-threads` for real
  OS-thread-backed concurrency, including live in a browser). The test
  suite checks these agree — this cross-checking is how most real bugs in
  this project get found, including a lexer bug that silently corrupted
  non-ASCII string literals and a native-compiled-fibers bug that only
  ever showed up on the compiled path, not the interpreter.
- **A numeric tower**: Int/Float/BigInt/Rational/Complex, auto-promoting on
  overflow or inexact operations rather than wrapping or crashing.
- **A goal-oriented/logic layer with real inference, not just fact lookup**:
  `rule_add`/`solve` do genuine backward-chaining resolution over declared
  rules (including recursive ones, with real unification), and
  `action_add`/`plan` is a real STRIPS-style, uniform-cost-search GOAP
  planner — both usable from otherwise-imperative code, and both used as
  the substrate for genuine program synthesis (below), not just toy
  querying.
- **An inductive synthesis engine** (`self_hosting/lib/synthesis*.patlang`,
  plus newer generic search extensions in `friendly_cli/lib/`):
  least-general-generalization-based rule learning over BDD-authored
  example scenarios, extended to accumulator-threading and conditional
  ("toggle") relations found by search rather than hand-specified, and a
  GOAP-side analogue that composes a single discovered action across
  multiple simultaneous examples and packages it into a new, reusable,
  callable action — verified with deliberate decoys and held-back blind
  cases specifically to catch results that only *look* like discovery.
- **Real classes, inheritance, and traits**: an optional `class`/`inherits`
  keyword with single inheritance, real method dispatch via `send`,
  composable traits (last-listed wins on collision), and an inline form
  via `new(...)` needing no formal class block at all.
- **A transaction/backtracking pattern needing no engine changes**: PatLang
  closures already capture free variables as value copies (confirmed
  directly in the interpreter), so "try a candidate, keep the result only
  on success" is the natural shape of an ordinary closure call — a small
  pure-PatLang library (`friendly_cli/lib/vfs_transaction.patlang`) closes
  the one real gap (file state) on top of the existing VFS, with named,
  honest limits (not concurrency-safe for overlapping files; doesn't cover
  facts/rules, which have no retract yet).
- **Contracts, a message queue, TCP sockets, non-blocking process spawn,
  and a signal/task-discovery layer** built on top of the message queue —
  enough to write small self-orchestrated multi-process demos entirely in
  PatLang (see `self_hosting/examples/microservices_demo.patlang`).
- **A real, if informal, test corpus**: 100+ Rust integration tests
  (`rust-runtime/tests/`), a BDD/cucumber feature suite, and dozens of
  self-hosted PatLang selftests (`self_hosting/*_selftest.patlang`)
  exercising the synthesis engine, regex DSL, reflection/transpilation, and
  more — plus a large, ongoing spec-discovery/verification initiative
  (`spec_library/`) covering shell commands, PatLang's own standard
  library, and language features via mechanically-verified Gherkin specs.
- **A library of working example programs** (`self_hosting/examples/`,
  `portfolio/demos/`, `friendly_cli/`) — a CSV-backed transactional RDBMS
  with a SQL console, a hex-grid RTS economy sim, a build daemon, a maze
  solver, a family-tree/demographic simulator, a combined GOAP-planning +
  transactional + fiber-based worker demo, and others — each runnable and
  each built to prove out a real language feature rather than as a toy.
- **Developer tooling**, all self-hosted (`self_hosting/tools/`):
  - `parity_main.patlang` — runs a file through all execution paths and
    diffs the output, to catch a divergence between the native and
    self-hosted compiler in one command.
  - `depgraph_main.patlang` — an include-dependency graph over
    `self_hosting/` with cycle detection, text or `--html` report.
  - `format_main.patlang` — a line-based re-indenter (deliberately not a
    full AST pretty-printer, since the lexer discards comments entirely
    and a parse-rebuild formatter would delete them).
  - `fuzz_main.patlang` — generates random nested control-flow programs
    and checks that the native and self-hosted parsers agree on each one.
  - Runtime errors from `--ir-run` also get a plain-language suggestion
    line alongside the raw message (`rust-runtime/src/main.rs`'s
    `suggest_runtime_fix`), mirroring the existing parse-error reasoning.

## Performance: real numbers now exist, and the honest state of them

A real, external comparison (a Ruby-to-PatLang port of a predator-prey
ecosystem simulation, done in a sibling project) found `pat --patc`
compiled output running **~21x slower than equivalent Ruby** (24.77s vs
1.15s on the same workload), and directly profiling it — rather than
guessing — found the actual cause was not the numeric tower (the first
hypothesis), but that compiled programs still run as bytecode through a
shared, embedded interpreter loop, with local variables and function
calls resolved via string-hashed lookups. Fixing that (caching
per-function dispatch tables instead of re-hashing names on every access
— with one attempted intermediate version *causing* a real regression
before landing on the correct per-function-not-per-call design) brought
the same benchmark to **~11.4s, roughly a 2x speed-up over the original
PatLang time** — genuine, measured progress, but still around 10x slower
than Ruby on this particular workload, not parity. Two of this project's
own longstanding benchmarks (`bench_sumloop.patlang`, `bench_sort.patlang`)
came out 29-35% faster from the same fix, with no measurable overhead
added to trivial programs.

Stated plainly, since this whole project treats an unverified performance
claim the same as any other unverified claim: **`pat --patc`'s "compiled"
backend does not yet do genuine native code generation.** It serializes a
function's IR as data and executes it through a generic bytecode VM
embedded in the output binary, rather than translating PatLang control
flow into real Rust control flow. That remaining gap is understood, but a
real fix for it is a substantially bigger undertaking than the fixes
already made, and hasn't been started.

## What it doesn't do

- **No package manager or module registry.** `include` is textual file
  concatenation; there's no versioning or dependency resolution.
- **No sandboxing.** Host functions give a PatLang program the same
  privileges as the user running it: arbitrary process execution
  (`exec_capture`), unrestricted filesystem read/write/delete, and raw TCP.
  Fine for scripts you wrote yourself; do not run untrusted PatLang source
  without wrapping it in an external sandbox (container, VM, restricted
  user account) first.
- **No editor tooling.** No LSP, no debugger. A basic re-indenter exists
  (see Developer tooling above) but there's no linter yet and no IDE
  integration beyond the standalone `tools/vscode-patlang/` syntax
  highlighter.
- **No genuine native code generation yet** — see Performance above.
  `pat --patc`/`patc1.exe` produce real standalone binaries, but their
  runtime behavior is still bytecode interpretation, not compiled control
  flow.
- **No fact/rule retraction.** `rule_add` is accumulate-only; nothing
  registered as a fact or GOAP action can currently be un-registered,
  which limits how far the transaction/backtracking pattern above can
  reach (file state only, not logic/planning state).
- **Single-maintainer, no external users yet.** Everything above is
  proven against its own test suite and example programs, not against
  outside use.

## Quick start

You need a Rust toolchain for one bootstrap step only — see Requirements
above for the exact version and optional extras.

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

# Compile to WebAssembly -- via the self-hosted compiler with an extra
# positional target argument (pat --patc itself only ever produces a
# native binary; WASM output goes through patc1.exe)
./patc1.exe hello.patlang hello.wasm wasm32-wasip1
```

`hello.patlang`:

```patlang
let name = "world"
print("hello, " + name)
```

See [`TUTORIAL.md`](TUTORIAL.md) for a fuller walkthrough of all
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
├── friendly_cli/           # Curriculum/synthesis experiments, GOAP demos,
│                           # the VFS transaction pattern, and a self-
│                           # healing engine that tries known solutions
│                           # before falling back to an LLM.
├── spec_library/           # Mechanically-discovered/verified BDD specs
│                           # (shell commands, PatLang stdlib, language
│                           # features) plus a genuine synthesis registry,
│                           # kept structurally separate from anything
│                           # hand-authored.
├── portfolio/demos/        # Browser-facing HTML wrappers for demos.
├── patc1.exe                # The bootstrapped self-hosted compiler binary
│                            # (rebuild via self_hosting/build_patc1.patlang).
├── TUTORIAL.md              # Start here for a hands-on introduction.
└── CLAUDE.md                # Working conventions for this repo.
```

Most of the other root-level `*.md` files predate the current
architecture and are kept for historical reference only.

---

**PatLang** — a self-hosted language for exploring goal-oriented,
logic-programming, and genuine program-synthesis constructs alongside an
ordinary imperative core.
