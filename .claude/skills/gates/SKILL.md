---
name: gates
description: Use when running, watching, stopping or reading v2's gates (self_hosting/v2/tools/gates.sh), or when adding a suite, runner, selftest, fixture directory or tool test to them. Covers starting a run, --status/--quit/--kill, reading the record and logs, declaring a unit's inputs so staleness is right, and what makes a run slow.
---

# gates

`docs/plans/gates.md` is the design; `self_hosting/v2/tools/gates.patlang` is the
truth. This is how to use them.

## Running

- From the repository root: `bash self_hosting/v2/tools/gates.sh` runs every stale
  unit. `--plan` lists them without running, `--only PREFIX` narrows to units whose
  names start with it, `--failed` to the units that failed last time, `--all`
  ignores the record, `--cap N` caps the cores.
- A full run after a runtime change is about three hours. Start it with the Bash
  tool in the background and a timeout of 7200000 ms or more, then wait for the
  notification. Do not poll.
- Results: `self_hosting/build/gates/record` (unit, key, pass, ms, peak bytes);
  logs: `self_hosting/build/gates/logs/UNIT.log`, with `/` in the name as `__`.
- A unit passes when its command exits 0. A suite unit's log ends with its
  `tests: N passed, M failed` line.

## Watching and stopping

- `bash self_hosting/v2/tools/gates.sh --status`: what is running, waiting, done.
- `--quit`: start no more units; running ones finish and are recorded, so the next
  run takes up the rest. Exit status 2.
- `--kill`: stop the tool and every unit it started (taskkill on its process tree).
- Never stop a run by killing the shell or the background task that started it:
  the tool goes on, orphaned. If that happened, find `v2_gates_tool.exe` by name and
  use `--kill`, then check that no `v2_gates_tool.exe` is left.
- A finished run's status file starts with `finished` and names no port.

## While a run is going

Edit nothing it reads. The compiler unit reads `self_hosting/v2/runtime/` and
`compile.patlang`; the repository suite reads every tracked file under
`self_hosting`, `friendly_cli` and `spec_library`. Work on files outside the repo
(memories, the scratchpad) or wait.

## Adding a unit

- **A feature file** in an existing suite: nothing to do; the runner's `--list`
  names it.
- **A selftest**: add it to `self_hosting/tools/run_selftests.patlang`. It becomes
  `selftests/NAME`, hashed with the files it includes. Data it reads outside its
  includes goes in the selftests suite's input list in `gt_suites`.
- **A suite**: an entry in `gt_suites`: name, program (the interpreter), its
  arguments before the feature file or program, the units it needs, its inputs,
  and a lane ("" for none). The runner must answer `--list` and exit 1 on failure.
- **A build or a tool test**: an entry in `gt_build_units` with `gt_unit(name,
  needs, inputs, cores, lane, ["cmd", program, args], product)`; `edit_tool`
  is the example for a Python test.
- **Inputs**: `["program", path]` hashes a file with everything it includes,
  `["file", path]` one file, `["dir", path]` a tree, `["dir_except", path, [names]]`
  a tree without some subdirectories. Generated files (`.exe`, `.log`, ...) and any
  `build` directory are left out. An input that is missing means a stale verdict;
  an input that is too wide means needless reruns (part2 once reran for every
  change under `self_hosting/tools`).
- Check the plan: `gates.sh --plan` should list the new units and nothing that has
  no reason to be stale.

## What makes a run slow

The longest units set the wall clock, and they start first. A feature file whose
whole run took more than ten minutes runs as one unit per scenario
(`SUITE/NAME@N`), so its scenarios share the cores; to run one by hand, give the
runner `FILE.feature@N`. A single slow scenario still sets a floor: split its
work, or make the scenario cheaper.
