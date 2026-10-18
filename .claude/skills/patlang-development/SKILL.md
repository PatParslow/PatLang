---
name: patlang-development
description: Use whenever doing PatLang development work in this repo -- writing or editing .patlang files, adding a language feature, running pat --ir-run/patc1.exe, compiling to native x64 or WASM, or designing any long-running PatLang program. Covers BDD-first (Gherkin before code, no exceptions), the native-PatLang-before-Rust backend preference order, wasmtime for WASM verification, the full paradigm list PatLang supports, signal-based monitoring/clean-shutdown discipline, verified performance traps, and backend-specific gotchas discovered the hard way.
---

# patlang-development

Consolidated, hard-won discipline for building things IN PatLang and FOR the
PatLang toolchain. Load this before starting PatLang work, not after hitting
the first gotcha it would have prevented.

## 1. BDD-first is absolute -- Gherkin before code, always

Write the Given/When/Then scenario **before** writing any implementation,
including quick diagnostic or exploratory scripts, not just "real" features.
A throwaway repro still gets a one-paragraph Given/When/Then comment at the
top stating what's being checked and what's expected, before the checking
code is written.

1. **RED**: write the scenario first. Confirm it actually fails (or, for a
   diagnostic, confirm you don't yet know the answer it predicts).
2. **GREEN**: make the exact scenario pass -- match what the spec/prose
   claims, not just whatever makes some other test pass.
3. **Verify**: check claims against real runtime output, not assumed or
   expected behavior.
4. **Report**: state the command run, the output, and how it aligns with the
   spec -- not just "done."

This was NOT followed consistently for this session's own exploratory work
(e.g. Phase 9 debugging, the WASM viability check) -- ad hoc `.patlang`
diagnostic files were written first and Gherkin formalized only after
something worked. That's the failure mode this rule exists to close.

Formal feature work lives in `spec_library/**/*.feature`, wired through
`self_hosting/lib/test.patlang`'s Gherkin runner and (for language-level
semantics) `self_hosting/lib/spec_steps_language.patlang`'s `step()`
registrations, or `gherkin_contracts.patlang`'s `ensure` steps for
representation/type invariants. Run the whole language gate with:

```
rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/run_language_spec_suite.patlang
```

## 2. Backend preference: native PatLang first, Rust only as last resort

Three real execution/compilation paths exist. Prefer them in this order,
falling through only when the current one genuinely cannot do the job:

1. **`pat --ir-run`** -- the Rust-native interpreter running PatLang source
   directly. Fastest iteration loop; default for everyday development and
   diagnostics.
2. **Self-hosted native x64 backend** -- `./patc1.exe <src> <out> --x64`,
   using `self_hosting/lib/{lexer,parser,lower,codegen_x64}.patlang`, all
   PatLang-authored. This produces real machine code with **zero rustc
   dependency at the final step** -- this is what "native PatLang" means in
   this repo, and it is the goal path, not `pat --patc`.
3. **Rust-backed pathways -- last resort only**:
   - `pat --patc` (Rust-native `codegen.rs`): testing/comparison only, never
     for routine builds (per project `CLAUDE.md` §1).
   - `self_hosting/lib/codegen.patlang`'s `emit_program_rs` (a self-hosted
     MIRROR of `codegen.rs` that emits Rust **source text**, then shells out
     to `rustc`): today the **only** path to WASM
     (`rustc --target wasm32-wasip1[-threads]`). Use the
     `patc1.exe <src> <out> wasm32-wasip1` CLI wrapper for ordinary
     programs; hand-roll `emit_program_rs` + a raw `rustc` call only when
     feeding in IR that `lower_program` itself wouldn't produce.

Do not reach for hand-written Rust, or a new Rust runtime primitive, to
solve something that's expressible in PatLang -- that includes tooling
*for* PatLang (build scripts, checkers), not just PatLang programs
themselves.

**wasmtime** is the WASM verification tool: confirmed at
`/c/Program Files/Wasmtime/bin/wasmtime`. Verify any WASM build with
`wasmtime run <file>.wasm` and compare output against the same program run
via `pat --ir-run` and `pat --patc` -- all three must match exactly.

## 3. Paradigms PatLang actually supports

Reference list so a paradigm-specific capability isn't overlooked or
rediscovered piecemeal:

- **Imperative core**: `let`/`mut`, `if`/`elif`/`end`, `while`.
- **Closures**: `|params| body end`, whole-capture-by-snapshot (see real
  `lower_closure_literal`) -- not by-reference capture.
- **Object orientation**: classes, methods, inheritance/traits.
- **Design by contract**: `require`/`ensure`/`assert` -> `contract_check`.
- **Logic programming / GOAP planning**: `fact`/`rule`/`query`,
  `goal`/`pursue`/`activate`, `action_add`/`plan`.
- **Event-driven programming**: `when EVENT do ... end`, `emit`,
  `register_event_handler`.
- **Concurrency**: real OS threads (`thread_spawn`), cooperative fibers
  (`fiber_new`/`fiber_yield`/`fiber_resume`/`fiber_alive`), `parallel_map`.
- **Process/system integration**: `spawn`/`exec_capture`, file I/O, TCP
  networking, `argv`.
- **A real auto-promoting numeric tower**: int / bigint / rational / float /
  complex / interval.
- **Durable messaging + live signals**: `queue_publish`/`consume`/`ack` for
  crash-safe checkpointing; `signal_claim`/`poll`/`query`/`reply`/`announce`
  for live, in-memory cross-process discovery and monitoring (see §4).
- **Declared Z-style schemas** (`zs_*` library) for formal specification.
- **Synthesis / GOAP-composition engine**: primitive/composite registry,
  enumerative synthesis by example.

A feature request phrased in terms of only one of these paradigms may
still have a cleaner expression in another already-supported one -- check
this list before assuming something needs to be built from scratch.

## 4. Long-running programs: signals, queue, budgeted yields

Any program expected to run more than a few seconds, or as a daemon, needs
this built in from the start, not bolted on after a hang is discovered (see
project `CLAUDE.md` §6 for the canonical statement -- summarized here):

- Declare `status` and `quit` signal handlers at the top level, at minimum
  (`signal_claim`/`signal_poll`/`signal_query`/`signal_reply`).
- **A `status` handler that can't respond promptly while real work is
  running does not count as done.** Wrap the actual work loop in
  `budgeted(ms) { ... }` (or an equivalent yield schedule) so the
  signal-polling loop gets a genuine, regular turn. Verify this against a
  *realistically sized* workload -- issue a real `signal_query(..., "status",
  "")` while it's genuinely still busy and confirm the reply is prompt. A
  short demo-sized run proves nothing here.
- Use the message queue (`queue_publish`/`queue_consume`/`queue_ack`) for
  any unit of work whose loss would matter on a crash -- signals are live
  and in-memory only. Only `queue_ack` once the work is verifiably complete.
- If another PatLang program might need to find this one without a
  pre-shared port, call `signal_announce` right after claiming the port,
  with an action list that accurately reflects the `when` handlers actually
  implemented.
- When delivering: state plainly whether progress reporting and crash-safe
  resumability were actually included, or explicitly scoped out. "It runs
  and produces the right output eventually" and "it can be checked on and
  safely interrupted" are different claims -- never conflate them in a
  summary.
- `self_hosting/lib/signals.patlang` is the primitive layer;
  `self_hosting/lib/build_progress.patlang` is the reference example of
  this whole pattern applied to a real long build.

## 5. Verified performance traps

- **String indexing is O(n) per call, not O(1)**: `char_code`, `substr`,
  and `s[i]` each re-check `s.is_ascii()` on the WHOLE string every call
  (`rust-runtime/src/ir/hosts.rs`). Any character-scanning loop over a
  PatLang String costs O(length²) overall. Use `List<Int>` (genuinely
  O(1)-indexed) for any parsing/scanning code that could plausibly process
  more than a short, fixed literal. Build a String only for short, final,
  already-bounded output via `chr(byte)` + `sb_push(...)`.
- **String concatenation in a loop is O(n²)**: PatLang strings are
  immutable, so `out = out + x` inside a loop copies the entire accumulated
  string every iteration. Always use `sb_new()`/`sb_push(b, ...)`/`sb_str(b)`
  instead, decided at the moment the loop is *written* -- this exact bug has
  recurred across multiple separate files/sessions after already being
  documented once (`syntax_dsl.patlang`, `glob_to_regex`/
  `parse_glob_pattern`, three JSON builders in `interp.patlang`). Before
  considering any loop-touching edit done, re-read every loop you touched
  and ask "does this reassign the same string to itself plus something,
  every iteration?"
- **Benchmark scaling, don't just eyeball correctness**: before trusting a
  loop/sort/scan/parser at scale, benchmark across 3-4 increasing input
  sizes (doubling each time). A hand-built test fixture is too small to
  expose O(n²)+ behavior; a ~4x cost per doubling means O(n²) is hiding.
  Never justify an O(n²) algorithm with an unverified "N is always small
  here" comment.

## 6. Control flow: no nested `else if`

Nested `else if` causes silent execution failures (exit 0, no output, no
parse error). Always use `elif`:

```patlang
if cond1 then
  ...
elif cond2 then
  ...
end
```

Prefer early returns (`if cond then return val end`) over deep nesting.

## 7. Backend-specific quirks discovered the hard way

- **`print` convention differs by backend.** `codegen_x64.patlang` rejects
  `CallHost "print"` outright ("not a real function and not in the
  OS-boundary allowlist") -- it requires an ordinary `Call` to
  `x64_runtime.patlang`'s own PatLang-defined `print`. `codegen.patlang`
  (the Rust-source / WASM path) treats `print` as a genuine host primitive
  via `CallHost` (`host_chunk_of` maps it to `"io_misc"`). These are
  opposite conventions -- check which backend you're targeting, don't
  assume uniformity, and thread a `print_op` parameter through shared
  translation code that needs to serve both.
- **`x64_runtime.patlang` cannot be `include`d directly into an ordinary
  `--ir-run` driver script.** It uses a parameter name (e.g. `rule` or
  `class`) that's a reserved keyword in the native Rust parser used for
  ordinary scripts -- fine only when consumed exclusively through
  `patc1.exe`'s own internal self-hosted lexer/parser pipeline. Confirm any
  suspected case like this in isolation (a minimal standalone repro) before
  concluding it's a pre-existing incompatibility rather than something your
  own combination caused. Work around it by inlining the small amount of
  logic actually needed (e.g. a `spawn("rustc", ...)` wrapper) rather than
  including the whole file.
- **`patc1.exe --x64` auto-bundles `x64_runtime.patlang` as built-in
  "shadowing primitives."** Explicitly `include`-ing it too in the same
  program produces a "defined BOTH by this program and by
  x64_runtime.patlang's own shadowing primitives" error.
- **`lower_program` always synthesizes an empty `main`** for any source
  unit with zero top-level statements, even a pure library file. Bundling
  two independently-lowered programs into one compilation unit needs these
  filtered out first (nasm otherwise reports `label 'main' inconsistently
  redefined`) -- see the `x64_name_in_list` filter pattern in
  `run_full_runtime_test.sh`.
- **`codegen_x64.patlang` hardcodes some runtime calls as raw asm text**
  (e.g. `call rt_bigint_from_i64`, `call rt_dynamic_binop`) for
  overflow-checked arithmetic -- these are invisible to any IR-level
  `Call`/`MakeClosure` rename or rewrite pass. Textual "salting" (renaming)
  of bundled runtime function names to dodge a link collision will break
  silently at the nasm/link stage on these. Use real, separate compilation
  units instead (a pre-built `.obj`, linked via `emit_program_x64`'s own
  `extern_names` parameter, which exists specifically for this).
- **Known native x64 bugs, not fixed by the Block Ownership Model design**:
  `list_push`/`list_set` alias shared storage in place when the underlying
  block has spare capacity, where the interpreter correctly copies on write
  (issue #145) -- reproduce with a list built via repeated pushes, not a
  fresh small literal, which has no spare capacity yet to expose the bug.
  Separately, `==` on structurally identical Lists built via different code
  paths returns `false` natively but `true` interpreted (issue #113) -- a
  distinct, orthogonal bug; don't claim a false connection between the two.
  Separately again, the dynamic-dispatch `/` path (`x64_binop_asm_div_
  dynamic`) has no Float case at all -- a genuine Float operand not visible
  as a literal in the function's own body (e.g. a plain parameter) either
  segfaults or silently produces garbage, since the fast/slow path only
  knows fixnum/BigInt/Rational shapes (issue #211). `%` almost certainly
  shares the same gap (documented together, not separately confirmed).
  `+`/`-`/`*`/comparisons are fine (`rt_dynamic_binop` already has the
  correct float-unbox-operate-rebox branch to copy from).

## 8. Windows path handling

- Run local executables with an explicit relative/full path
  (`./patc1.exe`, `.\patc1.exe`) -- a bare filename can fail with a
  `CreateProcess` error in some Windows shells.
- Path separator direction is tool-dependent, not a style choice: the Bash
  tool (git-bash) can silently swallow unescaped backslashes; `cmd.exe`
  builtins and some Windows console tools (`findstr`, `find`) treat `/` as
  a flag prefix and misparse forward-slash paths. If a path-related command
  fails mysteriously, try switching separator direction before assuming a
  logic bug.

## 9. Mirror-sync debt is separate from everything above

Any change to the Rust runtime (`codegen.rs`, new host functions, new
keywords/operators) can silently desync the self-hosted compiler mirror.
This has its own dedicated skill -- invoke **`mirror-check`** rather than
duplicating its steps here. It covers two independent kinds of debt (host-
function-body text parity, and lexer/parser/lower/codegen grammar parity)
that each need checking separately.

## 10. Issues and the project board

After `gh issue create`, always follow with `gh project item-add` to add it
to the PatParslow/PatLang project board -- an issue that isn't on the board
is easy to lose track of.

## 11. Build/test command cheat sheet

```
# Everyday interpreted run
rust-runtime/target/release/pat.exe --ir-run <file>.patlang [args...]

# Rebuild the self-hosted compiler (only when self_hosting/lib/*.patlang changed)
rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang

# Native x64 build (native PatLang, zero rustc at final step)
./patc1.exe <src>.patlang <out>.exe --x64
./out.exe

# WASM build (last-resort Rust-source path -- currently the only WASM route)
./patc1.exe <src>.patlang <out>.wasm wasm32-wasip1
wasmtime run <out>.wasm

# Full language spec gate (Gherkin-backed, 37/37 .feature files)
rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/run_language_spec_suite.patlang

# Rust<->self-host mirror parity check (see the mirror-check skill for the full workflow)
cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity
```
