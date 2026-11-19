---
name: patlang-development
description: Use whenever doing PatLang development work in this repo -- writing or editing .patlang files, adding a language feature, running the v2 compiler or interpreter, compiling to native x64 or WASM, or designing any long-running PatLang program. Covers BDD-first (Gherkin before code, no exceptions), the v2 toolchain and its commands, checking WASM builds under the v2 host, the full paradigm list PatLang supports, signal-based monitoring/clean-shutdown discipline, verified performance traps, and backend-specific gotchas discovered the hard way.
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

The `patlang-change` skill is the checklist from scenario to commit, including
what a new runtime function, selftest or gates suite also needs.

Formal feature work lives in `spec_library/**/*.feature`, run by
`self_hosting/lib/gherkin.patlang`'s Gherkin runner. A language scenario
carries its program in a doc string and says what both engines print
(`Given the program`, `When it runs interpreted and compiled`, `Then both
print`: `self_hosting/lib/spec_steps_program.patlang`), so no step is
narration that checks nothing. Run the whole language gate with:

```
bash self_hosting/v2/tools/gates.sh --only language
```

## 2. The toolchain is v2

The compiler (`self_hosting/build/v2.exe`, from `self_hosting/v2/compile.patlang`)
and the interpreter (`self_hosting/build/v2_interp.exe`, from
`self_hosting/v2/interp.patlang`) are PatLang, on one runtime
(`self_hosting/v2/runtime/`). A program prints the same on both, and the gates
check that. Nothing needs Rust.

- Interpret for the quick loop: `self_hosting/build/v2_interp.exe SRC.patlang`.
- Compile: `self_hosting/build/v2.exe SRC.patlang OUT.exe --workers 4`, run from the
  repository root.
- WASM: `v2.exe SRC OUT.wasm --wasm`, then
  `node self_hosting/v2/wasm/run_node.mjs OUT.wasm`, or
  `self_hosting/v2/wasm/run_browser.py` in headless Chrome. Compare against the
  native build's output.

`pat --ir-run`, `pat --patc`, `patc1.exe` and rustc are the old route. Don't use
them for new work, and don't add Rust to solve something PatLang can express.

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

Start new tools from `self_hosting/templates/budgeted_tool.patlang`:
budgeted slices driven by one orchestrator, status/pause/resume/quit
signals, and state held in objects rather than in `__vars`. Its checker,
`check_budgeted_tool.sh`, runs the live status test described below.

Any program expected to run more than a few seconds, or as a daemon, needs
this built in from the start, not bolted on after a hang is discovered (see
project `CLAUDE.md` §6 for the canonical statement -- summarized here):

- Declare `status` and `quit` signal handlers at the top level, at minimum
  (`signal_claim`/`signal_poll`/`signal_query`/`signal_reply`), and name them in
  `signal_allow([...])` after `signal_claim`: a signal whose name is not allowed
  is ignored, so an internal `when` event cannot be raised from outside.
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

- **Indexing a non-ASCII string walks from its start** (spec 1.10): v2
  indexes an all-ASCII string in O(1), but one non-ASCII character anywhere
  (an em dash in a comment is enough) makes `s[i]`, `substr` and `char_code`
  O(i), so a character scan of the text is O(length²). Measured: the
  repository checks took over 3 minutes searching source files with an
  interpreted `contains_text`, and 27 s with the runtime's `str_contains`.
  Search with `str_contains` or `sed`, scan with the string cursor
  (`str_intern`, `sc_code`) or a `List<Int>` of bytes, and build strings with
  `sb_push`.
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

## 7. Gotchas

On v2:

- `v2.exe` reads the runtime relative to the working directory: run it from the
  repository root. The interpreter finds the root from its own path.
- `and` and `or` short-circuit on both engines
  (`spec_library/language/logical_operators.feature`): `(i < n) and xs[i] == 0`
  is safe, with no nested `if` needed.
- There is no `str_split`; a runtime function is in `self_hosting/v2/runtime/`
  or it does not exist: grep for `make a function called NAME` before using one.
- There is no `**`: use `pow(a, b)`. `/` of ints gives a rational when the result
  is not whole.
- `thread_spawn` takes a closure (`thread_spawn(|| do ... end)`), read with
  `thread_result`. `fiber_new` takes a function's name, and `fiber_resume(id, v)`
  passes a value in.
- A `match` default is `case _ then`, not `else`.
- Rules live in stores (`logic_store_new`, `rule_add_to`, `solve_in`); `rule` and
  `solve` use the default store. `set_var` and the other globals are gone.
- `signal_claim` and the rest come from `include`-ing `self_hosting/lib/signals.patlang`.

On the old compiler (`patc1.exe`, kept for reference):


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
  (`./hello.exe`, `.\hello.exe`) -- a bare filename can fail with a
  `CreateProcess` error in some Windows shells.
- Path separator direction is tool-dependent, not a style choice: the Bash
  tool (git-bash) can silently swallow unescaped backslashes; `cmd.exe`
  builtins and some Windows console tools (`findstr`, `find`) treat `/` as
  a flag prefix and misparse forward-slash paths. If a path-related command
  fails mysteriously, try switching separator direction before assuming a
  logic bug.

## 9. Mirror-sync debt is the old route's

The `mirror-check` skill keeps the old compiler's Rust mirror in step. It does not
apply to v2, which has no Rust side.

## 10. Issues and the project board

After `gh issue create`, always follow with
`gh project item-add 5 --owner PatParslow --url URL`: an issue that isn't on
the board is easy to lose track of.

## 11. Build/test command cheat sheet

```
# The first compiler, when self_hosting/build/v2.exe is missing
py -3 bootstrap/ir_reader.py bootstrap/v2_compiler.ir self_hosting/build/v2.exe

# Interpret
self_hosting/build/v2_interp.exe <file>.patlang [args...]

# Compile, from the repository root
self_hosting/build/v2.exe <file>.patlang <out>.exe --workers 4

# WASM
self_hosting/build/v2.exe <file>.patlang <out>.wasm --wasm
node self_hosting/v2/wasm/run_node.mjs <out>.wasm

# Rebuild the interpreter after a runtime or interpreter change
self_hosting/build/v2.exe self_hosting/v2/interp.patlang self_hosting/build/v2_interp.exe --workers 4

# The gates: what changed since it last passed; --plan, --all, --only PREFIX
bash self_hosting/v2/tools/gates.sh
```
