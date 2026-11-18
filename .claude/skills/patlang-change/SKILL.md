---
name: patlang-change
description: Use when taking any change to PatLang from start to commit -- a language or runtime change, a new runtime function, a library fix, a new or changed test, runner or tool. The checklist from scenario to gates to commit, with the extra steps a runtime function, a selftest, a fixture and a gates suite each need, and the checks to run before handing anything to a long gates run.
---

# patlang-change

The order a change goes in, and what each kind of change also needs. CLAUDE.md
says why; this says what to do next. Work through it in order and say in your
report which steps ran and which did not.

## 1. Before touching code

- Read the code the claim is about. A plan doc or a comment is a claim, not a
  fact (CLAUDE.md 2.6).
- Is a gates run going? (`bash self_hosting/v2/tools/gates.sh --status`.) If so,
  edit nothing it reads; a runtime file is read by the compiler unit.
- If the fix only works because "values here are always X", stop and ask the
  owner whether the language should make the distinction.

## 2. RED

- Language or runtime behaviour: a scenario in `spec_library/values_and_memory/`
  (part 1) with a fixture in `self_hosting/v2/spec/fixtures/`, its step and
  expected output in `self_hosting/v2/spec/run_values_and_memory.patlang`.
- Library behaviour: a check in that library's `*_selftest.patlang`.
- Run it and see it fail for the reason you expect:
  `self_hosting/build/v2_interp.exe FIXTURE.patlang < /dev/null`.

## 3. GREEN, on every engine it claims

- Interpreted: `self_hosting/build/v2_interp.exe F < /dev/null`.
- Compiled: `self_hosting/build/v2.exe F OUT.exe`, then `OUT.exe < /dev/null`.
- Compare the two outputs with `cmp`. Where the browser host matters, also
  `--wasm` and `node self_hosting/v2/wasm/run_node.mjs OUT.wasm`.
- A runtime change needs the interpreter rebuilt before the interpreted run means
  anything (CLAUDE.md section 1).

## 4. What each kind of change also needs

**A new or changed runtime function** (`self_hosting/v2/runtime/`):
- a contract that is true for every input, including `..` paths, empty strings
  and non-ASCII text;
- a line in `docs/spec/values-and-memory.md` in the section it belongs to;
- a fixture and scenario, and the fixture's name in `st_engines_agree`'s list;
- if it calls `extern_call`, the same entry point in the WASM host
  (`self_hosting/v2/wasm/executor.mjs`), answering as the browser can;
- the interpreter rebuilt.

**A new selftest** (`*_selftest.patlang`):
- its path in `self_hosting/tools/run_selftests.patlang`'s list, or in the
  retired list with a reason; the repository checks fail otherwise;
- scratch files under `spec_out()` (from `lib/v2_engines.patlang`), never in the
  source tree;
- programs it writes run through `lib/program_run.patlang` (`run_interpreted`,
  `run_compiled`, `printed`); a library they include is named by
  `path_absolute(...)`;
- an external tool it needs is checked with `expect(ctx, ..., has_program(NAME), true)`;
- it ends with `ctx_report(ctx)`, or prints `ALL TESTS PASSED` only when it did.

**A new runner, suite or fixture directory**: its unit and inputs in
`self_hosting/v2/tools/gates.patlang` (see the `gates` skill), and a line in
`docs/plans/gates.md`.

**A rule that a set must stay complete**: a scenario in
`spec_library/repository/repository.feature`, with its step in
`self_hosting/tools/run_repository_checks.patlang`. Prove the check works by
adding a file that breaks it, seeing it fail, and deleting the file.

## 5. Before the gates

- Edits to many files go through `py -3 -I tools/edit_files.py SPEC` (CLAUDE.md
  2.5), with `--check` first when unsure.
- Reread every loop you touched for `s = s + ...` (CLAUDE.md 4.5).
- Run the changed path by hand on a real input: a rewritten runner with one real
  argument, a changed selftest through `run_selftests.patlang PATH`.
- Make a failure path fail once and read the exit code without a pipe after the
  command.
- `self_hosting/build/v2_interp.exe self_hosting/tools/run_repository_checks.patlang`
  (about a minute) catches unlisted selftests, unrun fixtures and retired-tool
  references.

## 5.5 Measuring a change (an optimisation, or a claim about cost)

- Measure before and after at three or four sizes, and say which runs are
  comparable: a trial compiler with a different cache key rebuilds everything on
  its first run.
- **A trial must be shown to differ before it is timed.** A trial build meant to
  change generated code has `--ir` output that differs from the baseline's (`cmp`);
  print the edited function before building it. A trial that changed nothing
  times the same as the baseline, and reads as "this costs nothing".
- **A baseline for a runtime change comes from the old sources.** A compiled
  program reads the runtime from the working directory's
  `self_hosting/v2/runtime/`, not from the compiler binary: two compilers run in
  the edited tree build the same runtime. Build the baseline from a checkout of
  the old sources (the gates snapshot, or a `git worktree`), and check it lacks
  the change (grep for a new function's name).
- Before fixing a suspected cost, take it away in a trial and time that: a real
  quadratic can still be no part of a real workload's time.
- **A scaling check in a test counts `cpu_cycles()`, not `clock_ms()`.** The gates
  run units on every core at once, and a clock reading counts the time a unit
  waited for a processor: three checks comparing clock times failed there and
  nowhere else. The clock is for what really is about time: deadlines, sleeps,
  threads working together.
- **A scaling check leaves room on both sides.** `cpu_cycles` still moves by a
  third from one run to the next (the processor's speed, a busy core sibling).
  Compare sizes four times apart against a bound of eight: linear work gives
  four, quadratic sixteen, and eight is a factor of two from each. Twice the
  size against a bound of three leaves a factor of 1.5, and 2.5 times against
  three left 1.2, which failed. Time the two sizes in turn and keep the
  cheapest of each.

## 6. Gates, docs, commit

- `bash self_hosting/v2/tools/gates.sh` in the background with a long timeout;
  wait for it rather than polling.
- Docs and spec in the same commit as the code. Report what ran: the command,
  the counts, and anything not run.
- Commit only when asked, staged explicitly, with the Co-Authored-By line; push
  only when asked. New issues go on board 5.
