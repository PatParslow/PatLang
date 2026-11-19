# PatLang: conventions for working in this repo

## v2 is the toolchain

The compiler (`self_hosting/v2/compile.patlang`, built as `self_hosting/build/v2.exe`),
the interpreter (`self_hosting/v2/interp.patlang`, built as
`self_hosting/build/v2_interp.exe`) and the runtime they share
(`self_hosting/v2/runtime/`) are PatLang. Building, running and testing need no
Rust: a fresh clone with no `rust-runtime/` and no Rust on the PATH builds itself
and passes every gate (checked 2026-11-15).

`rust-runtime/` (`pat`) and the earlier compiler (`patc1.exe`,
`self_hosting/build_patc1*.patlang`, `self_hosting/block_model/`,
`self_hosting/lib/codegen*.patlang`, `x64_runtime.patlang`) are the old route.
Don't develop on them or fix their failures unless asked. The gates no longer run
the block-model suite (`spec_library/block_model/`, retired 2026-11-16); the
libraries its parity feature exercised are selftests on v2. Notes that were
only about the old route are in `docs/history/claude-md-old-route-notes.md`.

Skills in `.claude/skills/` hold the step-by-step procedures:
`patlang-development` (writing PatLang), `patlang-change` (taking any change from
scenario to commit), `gates` (running, stopping and extending the gates) and
`retrospective` (turning what went wrong into checks and rules).

---

## 1. Commands

Run from the repository root: `v2.exe` reads the runtime from
`self_hosting/v2/runtime/` relative to the working directory.

* First compiler, when there is none:
  `py -3 bootstrap/ir_reader.py bootstrap/v2_compiler.ir self_hosting/build/v2.exe`
* Compile: `self_hosting/build/v2.exe SRC.patlang OUT.exe [--workers N]`; also
  `OUT.ir --ir`, `OUT.wasm --wasm`, and `SRC --constant-time`. `--check-runtime` also checks
  the runtime's `ensure` clauses, which a build leaves out by default (spec 2.4).
* Interpret: `self_hosting/build/v2_interp.exe SRC.patlang [args...]`
* Rebuild the interpreter after a runtime or interpreter change:
  `self_hosting/build/v2.exe self_hosting/v2/interp.patlang self_hosting/build/v2_interp.exe --workers 4`
* Rebuild the compiler from its sources: let the gates do it. The `compiler` unit
  builds two generations, checks they are byte identical, and installs the second.
  When a change alters the code the compiler generates, the first two differ, so it
  builds a third and checks that the second and third are identical.
* WASM: `node self_hosting/v2/wasm/run_node.mjs [--files DIR] PROGRAM.wasm [ARGS...]`,
  or `self_hosting/v2/wasm/run_browser.py` for headless Chrome. `--real-files` puts the
  program's file calls on the disk (the compiler built as WASM can then build programs),
  and `--fail NAME:N` makes the Nth call to a host function fail.
* Without Windows: `bash tools/ci_wasm.sh` builds the compiler from the bootstrap IR as
  WASM and builds and runs the demos with it under Node (`.github/workflows/v2-wasm.yml`).
* Scripted edits: `py -3 -I tools/edit_files.py SPEC [--check]` (§2.5).

---

## 2. Gates

`bash self_hosting/v2/tools/gates.sh [--plan] [--all] [--only PREFIX] [--failed] [--cap N]`
builds the first compiler from the IR if needed, then the gates tool. It runs every
stale unit (a build, a selftest, or one feature file of one suite on one engine, or
one scenario of a long one) in parallel, leaving two cores and 4 GB free.
`--failed` reruns what failed last time.

- Results go to `self_hosting/build/gates/record`, and logs to
  `self_hosting/build/gates/logs/UNIT.log`.
- `gates.sh --status` asks a running tool what it is doing; `--quit` starts no more
  units and lets the running ones finish; `--kill` stops the tool and every unit it
  started. Killing the shell that started the gates does not stop the tool: its
  units go on as orphans.
- A unit's inputs are declared in `self_hosting/v2/tools/gates.patlang`. A new
  suite, runner or fixture directory needs its unit and inputs declared there.
  See `docs/plans/gates.md` and the `gates` skill.

Don't edit files a running gate reads. A runtime file is read by the compiler unit,
so a runtime edit waits for a running gates run to finish.

---

## 2.5 Working habits that have each cost time more than once

- **Edits:** use the Edit tool. A scripted edit (many files, or anchors with quotes
  or backslashes) is a spec for `tools/edit_files.py`, written with the Write tool:
  it keeps each file's line endings, applies every block or none, and refuses an
  anchor that is missing or found the wrong number of times. Never a Python or
  shell heredoc carrying anchors: shell quoting mangles them.
- **Probes:** run a program from the shell with `< /dev/null`. An interpreter left
  with an open stdin can wait on it, and the call looks hung.
- **Exit codes:** read a command's status without a pipe after it; `cmd | tail`
  reports tail's.
- **Before a long gates run:** run the changed code path once by hand on a real
  input. A runner's `--list` does not exercise its run path, and a failure path is
  checked by making something fail.
- **Waiting on a file another run writes:** match something only the new run
  writes. A previous run's file can already contain the text you wait for.
- **A fix that works because "values here are always X"** is a question for the
  owner: check whether the sentinel can also be a legitimate value, and whether the
  language should make the distinction.
- **Tests assert on what the program prints,** never on what an engine adds after
  it. Run programs through `self_hosting/lib/program_run.patlang`.

---

## 2.6 Engineering practices

- **Test first.** Write the scenario or selftest check, see it fail for the reason
  you expect, then change the code. A characterisation test of behaviour already
  there says so in its comment.
- **Principled fixes.** Fix the mismatch, never add a compensating constant, a
  special case or a defensive cap. When a fix lands at one call site, look for the
  same pattern elsewhere and fix it where it starts.
- **Correct over bug-compatible.** Where v2 and the old engine differ, make v2
  correct and consistent, and say what changed. A baseline is evidence, not the
  target: work out which side is right.
- **Code over plan docs.** A plan doc can be stale. Check a claim in the code before
  acting on it, and correct the doc when it is wrong.
- **Docs move with code.** The spec, the docs and the code change in the same
  commit. Report status only as verified: "the fixture passes on both engines, the
  gates have not run" rather than "done".
- **Flaky means broken.** An intermittent failure is a timing bug or a race: find
  its cause and fix it in the session. "Environmental" is not a diagnosis.
- **No silent skips.** A test that cannot run says why and fails, unless the engine
  itself lacks the capability (no processes in the browser). A missing tool fails
  by name (`has_program`).
- **Arbitrary timeouts are not evidence.** A wall-clock bound proves only that
  something did not finish in that window. Check scaling over several sizes, and
  use the signals pattern (§6) to tell slow from stuck.
- **Registries stay complete.** A list that must name every member of a set (the
  selftests, the files that may start a retired tool, the fixtures both engines
  run) gets a repository check (`spec_library/repository/`), so the next new member
  cannot be forgotten.
- **Shared mutable state in workers.** Nothing a `parallel_map` or `thread_spawn`
  worker can reach is written during the parallel phase: derive unique names from
  something unique per unit, accumulate per worker and merge after. PatLang has no
  mutex, and none of these needs one.
- **Issues** go on the project board: `gh issue create`, then
  `gh project item-add 5 --owner PatParslow --url URL`.
- **Commits:** only when asked, staged explicitly, ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push only when asked.
- **Hardening loop.** When something goes wrong twice, the fix is a check, a tool,
  a line here or a skill step. A memory alone does not stop it happening again.
  Run a retrospective after a burst of live debugging (`retrospective` skill).

---

## 3. BDD Testing Workflow

1. **RED**: Write Given/When/Then first. Confirm scenario fails.
2. **GREEN**: Test exact scenario prose claims.
3. **Verify**: Match spec claims against real runtime output.
4. **Report**: State command, output, and exact spec alignment.
5. **The suites**:
   - `spec_library/values_and_memory/`: part 1 on both engines, and part 2 (`@runtime`).
   - `spec_library/language/`: `self_hosting/tools/run_language_spec_suite.patlang` on
     both engines, and `match_pattern` by `run_match_spec_suite.patlang`.
   - The selftests: `self_hosting/tools/run_selftests.patlang` runs every
     `*_selftest.patlang` a gate runs, and lists the retired ones with their reasons.
     A new selftest goes in its list, or the repository checks fail.
   - `spec_library/repository/`: `self_hosting/tools/run_repository_checks.patlang`
     checks the repository's own rules over every tracked file.

   Step registrations are in `self_hosting/lib/spec_steps_*.patlang`, on the Gherkin
   runner `self_hosting/lib/gherkin.patlang`. A runner lists its feature files with
   `--list`, and takes its scratch paths from `PATLANG_SPEC_OUT` (`spec_out()`).

   Any language-semantics change needs a scenario, RED before and GREEN after. For
   representation invariants, use `And ensure <var> == <literal>` against
   `numeric_kind(x)` or `type_of(x)`.

---

## 4. Control flow

* **No nested `else if`**: it causes silent execution failures (exit 0, no output,
  no parse error). Use `elif`:

```patlang
if cond1 then
  ...
elif cond2 then
  ...
end
```

* **Early returns**: prefer `if cond then return val end`.

---

## 4.5 String building: never `s = s + ...` in a loop

`out = out + x` in a loop copies the whole accumulated string each time, so an O(n)
scan becomes O(n²). It has been reintroduced, and caught, in several files across
several sessions (`syntax_dsl.patlang` took 30 minutes on a 700 KB file before it
was fixed).

* **Rule**: a loop that accumulates a string uses `sb_new()`/`sb_push(b, x)`/
  `sb_str(b)`, decided when the loop is written.
* **Self-check**: before an edit to a `.patlang` file is done, reread every loop you
  touched and ask whether it reassigns a string to itself plus something.
* **Clean up neighbours**: the same pattern elsewhere in a file you are editing is
  fixed in the same pass.
* **Scanning text**: indexing a string with a non-ASCII character in it walks from
  its start, so a character-by-character scan of a large text is quadratic. Search
  with `str_contains` or `sed`, walk a `List<Int>` of bytes, or use the string
  cursor (spec 1.10).

---

## 4.6 Top-level `let` bindings are not shared with functions

A top-level `let x = ...` belongs to the synthesized top-level `main`. A function
declared elsewhere does not see it (both engines refuse: `undefined variable x`),
and a function declared with `make a function
called` is not a value you can pass by its bare name from another function.

* Pass values as parameters. Use a top-level `let` only when nothing but the
  following top-level statements needs it.
* A function used as a value (for `parallel_map`, `thread_spawn`, a list) is a
  closure literal (`let step = |args| do ... end`) in the scope that uses it.
* **A `let` in a loop body is the function's variable.** There is no block scope:
  `let s = 1` inside an inner loop rebinds an outer loop's `s` and breaks it,
  silently (the gates tool lost all but its first suite this way). Give each
  loop's index a name of its own.

---

## 5. Output rules

* Keep turn narration lean; summarize results, don't paste full stdout; save
  detailed write-ups for milestones.
* **Avoid `| head -N` / `| tail -N`**: they truncate before you have seen what
  matters. Count with `wc -l` or `grep -c`, and filter with a targeted `grep`.

---

## 6. Long-running programs: signals, queue, budgeted yields

A program that runs for more than a few seconds, or as a daemon, is built with
monitoring and resumability from the start.

- **`status` and `quit` handlers** at the top level, at minimum, and
  `signal_allow(["status", "quit"])` after `signal_claim`: a peer reaches only the
  handlers the program allows, and only with the run's token (`lib/signals.patlang`).
- **The handler answers while the work runs**: the main loop is in
  `budgeted(ms) { ... }` or yields as often. Verify it on a realistic workload with a
  real `signal_query(port, "status", "")` while it is busy.
- **Durable work uses the queue** (`queue_publish`/`queue_consume`/`queue_ack`), and
  `queue_ack` only once the work is verifiably complete. Signals are live and in
  memory.
- **`signal_announce`** right after claiming the port when another program may need
  to find this one, listing only the handlers that exist.
- **Report it either way**: say whether status reporting and crash-safe resumption
  are in, or were scoped out.

---

## 7. Batch tools write progress to a file

A long-running or batch tool (a suite runner, a benchmark, a multi-file checker)
writes per-unit progress to a named file as it goes, since redirected stdout is
buffered until the process ends. A tool that runs many units answers `status` with
the signals pattern (§6). Keep instrumentation out of a timed region: report from
the driver, between timed runs. The spec-suite runners do not do this yet; the gates
report per unit.
