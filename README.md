# PatLang

PatLang is a programming language written in itself. Its compiler, v2, and its
interpreter are PatLang programs, and so is the runtime they share. The compiler
turns a program into a Windows x64 executable, with its own assembler and
linker, or into a WebAssembly module for the browser.

PatLang is an experiment in covering the major paradigms of programming in one
language: imperative and functional code, objects with inheritance and traits,
events, logic programming with backward chaining, goal-oriented planning,
design by contract, threads and fibres. It is also an experiment in building a
language without writing any of its code, or its formal specifications, by
hand. The project owner designed the concept and directs the work, and AI
agents wrote the code and the documentation. Every claimed result is checked by
running it, since several results in the project's history looked correct and
turned out to be wrong.

## Requirements

- Windows on x64.
- Python 3, to build the first compiler from its IR (once).
- Optional: Node.js, to run WebAssembly builds outside a browser.

## Quick start

From the repository root:

```bash
py -3 bootstrap/ir_reader.py bootstrap/v2_compiler.ir self_hosting/build/v2.exe
self_hosting/build/v2.exe self_hosting/v2/interp.patlang self_hosting/build/v2_interp.exe --workers 4
```

This builds the compiler, then the interpreter. `hello.patlang`:

```patlang
let name = "world"
print("hello, " + name)
```

```bash
self_hosting/build/v2_interp.exe hello.patlang           # interpret
self_hosting/build/v2.exe hello.patlang hello.exe        # compile
self_hosting/build/v2.exe hello.patlang hello.wasm --wasm
node self_hosting/v2/wasm/run_node.mjs hello.wasm
```

Run `v2.exe` from the repository root, where it finds the runtime.
[`TUTORIAL.md`](TUTORIAL.md) walks through the language.

## What it has

- **The compiler** (`self_hosting/v2/`): lowering to an IR, reference counting
  inserted by an ownership stage, x64 code generation, assembly and linking,
  each function's build cached by a hash of its inputs and run on parallel
  workers. It compiles itself, and two generations are byte identical.
- **The interpreter** (`self_hosting/v2/interpreter.patlang`): the compiler's
  own front end and runtime, walking the IR, so a program prints the same
  interpreted and compiled.
- **A bootstrap from the IR**: `bootstrap/ir_reader.py`, under 1,000 lines
  of Python, builds the compiler from `bootstrap/v2_compiler.ir`. The IR is
  specified (`docs/spec/ir.md`), so a reader in another language is a
  self-contained job.
- **WebAssembly with threads and fibres**: the host in `self_hosting/v2/wasm/`
  runs a module in a browser or Node, each thread and fibre a Worker over one
  shared memory.
- **Exact numbers**: ints overflow to bigints, dividing ints gives a rational
  when the result is not whole, and there are floats, complex numbers,
  intervals, and integers modulo n with a check that code using them takes
  the same time whatever the secret values (`self_hosting/v2/examples/`).
- **Logic and planning**: rules solved by backward chaining, in stores a
  program can make and name; a planner that finds the cheapest sequence of
  actions to a goal; `goal`, `pursue` and `activate` to run a plan.
- **Objects and events**: classes with fields, methods, single inheritance and
  traits; operators as methods; `when`/`emit` handlers; methods that declare the
  events they raise.
- **Concurrency**: OS threads, `parallel_map`, fibres, and worlds, each an
  object holding a program's state, in which another program's text can run.
- **Contracts, files, processes, TCP, signals and a message queue**: enough for
  programs that run as several processes and report their progress.
- **Packages** (`packages/`): deflate, zip, SHA-256, package resolution and
  trust, each with its own features.
- **A portfolio** (`portfolio/`): example programs run in the browser, with a
  playground, a REPL, and an IDE with a debugger.

## Tests

The specification is in Gherkin (`spec_library/`), and every scenario is
executable. `self_hosting/v2/tools/gates.sh` runs them on both engines, with the
compiler's self-build, the bootstrap and the WebAssembly writers:

```bash
bash self_hosting/v2/tools/gates.sh           # what has changed since it last passed
bash self_hosting/v2/tools/gates.sh --plan    # say what would run
bash self_hosting/v2/tools/gates.sh --all     # everything
```

The gates run only what a change could affect, in parallel, leaving two cores
and 4 GB of memory free. A full run from a fresh clone takes between two and
three hours on a 20-core machine (`docs/plans/gates.md`).

## What it doesn't do

- **No sandbox.** A program can run processes, read and write any file the user
  can, and open TCP connections. Run only programs you trust.
- **Native builds are Windows x64 only.** Other systems can run the WebAssembly
  builds.
- **No random source yet**, so programs needing keys or seeds derive them from
  fixed text.

## Layout

```
bootstrap/            the IR reader and WebAssembly writer in Python, and the compiler's IR
docs/spec/            the specifications: values and memory, the IR
docs/plans/           design and progress notes
docs/guides/          closures, threads, fibres and worlds; passing parameters
self_hosting/v2/      the compiler, the interpreter, the runtime and the WASM host
self_hosting/lib/     libraries: lexer and parser, assembler and linker, signals, Gherkin, ...
self_hosting/tools/   the suite runners, the portfolio and site builders
spec_library/         the Gherkin features
packages/             packages, each with a manifest and features
portfolio/            the browser portfolio
friendly_cli/         synthesis and curriculum experiments, GOAP demos, a terminal
rust-runtime/         the earlier implementation in Rust; nothing above needs it
```

The repository also holds the earlier compiler (`patc1`, the block-model
backend and their libraries in `self_hosting/`), which some suites still test.
