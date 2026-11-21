# Gates that run what changed, in parallel

`self_hosting/v2/tools/gates.sh` ran every gate one after another. Its run of
2026-11-15 took 4 h 52 min:

| Stage | Time |
|---|---:|
| Block-model suite | 1 h 35 min |
| Part 1, compiled | 59 min |
| Part 2 | 56 min |
| Part 1, interpreted | 24 min |
| Engines agree | 18 min |
| Language suite, both engines | 20 min |
| Compilers, reader, WASM, interpreter | 18 min |
| Selftests, match | 4 min |

The machine has 20 logical cores, and outside the compiler builds that run kept
one or two busy. Every scenario ran again whether or not anything it depends on
had changed.

## Goal

The gates give the same verdict as a full sequential run, in less time:

- **Only what is stale runs.** A unit of work that passed is not run again while
  everything it depends on is unchanged.
- **Independent work runs at once,** within what the machine can spare while
  someone is using it.
- **A full run stays one flag away** (`--all`), for before a push and to check
  the cache against reality.

## Units and their inputs

A unit is one action: building something (a compiler, the interpreter, a suite's
executable) or running one feature file of one suite on one engine. Each unit
declares:

- **what it needs:** the units whose products it uses (the interpreter, the
  compiler);
- **its inputs:** files and directories whose contents decide its result. A
  runner's own source counts with every file it includes, found by walking its
  include lines; the files its steps read at run time (fixtures, the WASM host,
  the runtime's files a browser page is given) are declared, as directories where
  a step can read any file under one;
- **its weight:** the cores it keeps busy (a compile with `--workers 4` weighs 4);
- **what it writes:** a directory of its own (below).

A unit's key is the hash of its inputs' contents and its needs' keys. A unit
that passed is recorded with its key, its time and its peak memory. It is stale
when its key differs from the recorded one, or it has no pass recorded. A unit
with no declared run-time inputs is always stale, so a missing declaration costs
time, never a wrong verdict.

## Logic and planning

The units, their needs and inputs are facts (`fact`), and staleness is a rule: a
unit is stale if it has no pass with its current key, or a unit it needs is
stale and will be rebuilt. A query gives the stale set. The planner (`plan`, over
`action_add` actions whose preconditions are the products their needs make)
orders the builds the stale suites need; a unit runs once everything it needs has
finished.

## Running at once, sharing the machine

- **Cores:** at most the logical cores less two are given to units, by weight.
  Before starting a unit the dispatcher measures how busy the machine is
  (`GetSystemTimes`); cores busy beyond what its own units account for are
  someone else's, and the budget shrinks by them, never below one unit at a time.
- **Memory:** before starting a unit, the free physical memory
  (`GlobalMemoryStatusEx`) must cover the unit's recorded peak (or a default for
  a unit never run) plus a reserve of 4 GB kept for the user. Otherwise the unit
  waits for one to finish.
- **Isolation:** a unit writes only under its own directory,
  `self_hosting/build/gates/<unit>/`, given to the runner as `PATLANG_SPEC_OUT`.
  Runners take their scratch paths from it (the executables they build, the files
  they write), so two units never write the same file. Ports are already safe:
  the fixtures listen on port 0. A program a test writes includes a library by
  its full path (`path_absolute`, spec 1.13), so it runs from the unit's
  directory.
- **Status:** the dispatcher claims a signal port and answers `status` with the
  units running, waiting and done, and their times; it writes the same to
  `self_hosting/build/gates/status` as each unit finishes. `quit` starts no more
  units and lets the running ones finish; since each result is recorded as it
  comes, the next run takes up the rest. `gates.sh --status` and `--quit` send
  these; `--kill` stops the tool and every unit it started. A finished run's
  status file names no port.

## Steps

1. **Isolation.** The suite runners take their scratch paths from
   `PATLANG_SPEC_OUT`; each suite still gives the same counts run sequentially.
2. **The machine's state as runtime functions:** cores, how busy they are, and
   memory, with their contracts and scenarios (spec 1.13).
3. **Units, keys and the dispatcher,** without the cache: a full run in
   parallel must give the same verdicts as `gates.sh`.
4. **The cache:** a second run with nothing changed runs nothing, and a change to
   one file runs exactly the units whose inputs include it.
5. **`gates.sh` becomes the bootstrap:** build the first compiler from the IR when
   there is none, then build and run the dispatcher.

## Progress

2026-11-15:

- **Steps 1 to 4 are built** (`self_hosting/v2/tools/gates.patlang`, built as
  `self_hosting/build/v2_gates_tool.exe`):
  - The suite runners take their scratch paths from `PATLANG_SPEC_OUT`
    (`spec_out()`, `lib/v2_engines.patlang`), and three fixtures that wrote fixed
    paths write there. Each runner runs a list of feature files, or lists its own
    with `--list` (`run_suite`, `lib/gherkin.patlang`), and exits 1 when a test
    fails. A suite whose runner lists nothing becomes one failing unit,
    `SUITE/listing` (`self_hosting/v2/tools/gates_fail.patlang`), so it cannot pass
    by running nothing: `language_linux` once did, its runner's arguments put where
    its source belongs (a suite's arguments start with the runner's source, which
    is what lists it). The build-daemon feature backed up its shared history file in a step of
    the signals feature; it takes the backup itself now, so each feature runs alone.
  - `cpu_count`, `cpu_times`, `memory_status` and `exec_measured` are in the runtime
    (spec 1.13). `exec_measured` runs the command in a job object, so its peak is the
    whole process tree's: a suite's compiles and programs count.
  - The planner it orders the builds with was fixed for it
    ([#262](https://github.com/PatParslow/PatLang/issues/262)): A* with an estimate
    that never overestimates, a hashed set of the states expanded, and no limit
    that answered "no plan" for a problem that had one. 160 independent goals take
    about 9 s.
  - Each unit's key, time and peak go to `self_hosting/build/gates/record`; a `status`
    signal on the port the status file names gives what is running.
- **Checked:** with no record, the 30 part1 units (both engines) ran in parallel
  after the compiler and the interpreter were built: all passed, 184 tests on each
  engine, as the sequential runs count them with this session's new scenarios. The
  suites took about 28 minutes, where the two sequential part1 runs took 83. A second
  run with nothing changed ran nothing, in 4 s; a blank line added to `text.feature`
  made exactly its two units stale.
- **The full run:** with part1 fresh, the other 146 units (7 builds, 139 feature
  files) all passed in 2 h 36 min, where the sequential run took 4 h 52 min. Each
  suite gave the sequential count: part2 136, the language suite 297 on each engine,
  match 26, the block model 210, engines agree 62, `interp_run_selftest` 54 and
  `isolate_selftest` 65; the bootstrap and WASM checks were identical.
- **Step 5 is built:** `gates.sh` builds the first `v2.exe` from the IR when there is
  none, builds the tool with it, and runs the tool with its own arguments.
- **What limits a run now:** two feature files, `library_selftest_parity` (block
  model, 135 min) and `compiler_structure` (part2, 97 min), each longer than its whole
  suite took run alone (95 and 56 min), since everything else competes with them for
  the cores. They start first, so the rest of the run fits inside them. Splitting each
  into units by scenario would shorten a full run further.

2026-11-16:

- **The selftests are a suite:** `self_hosting/tools/run_selftests.patlang` lists
  the 50 selftests it runs with `--list`, and the 21 retired ones, each with its
  reason, with `--retired`. Each runs as a unit (`selftests/NAME`), hashed with the
  files it includes and the data it reads. A runner may list programs (`.patlang`)
  as well as feature files.
- **The repository suite** (`self_hosting/tools/run_repository_checks.patlang`,
  `spec_library/repository/repository.feature`) checks every tracked file:
  - no program keeps its state in globals (moved out of part2's
    `compiler_structure`, so part2 no longer depends on `self_hosting/tools`);
  - every selftest is run by a gate or retired with a reason;
  - no program starts a retired tool, but for an allowlist where each entry has
    its reason ([#266](https://github.com/PatParslow/PatLang/issues/266) for the
    unported ones);
  - no program tests a missing field with `"" + get(`.
- **Long feature files run by scenario.** A feature file whose whole run took more
  than ten minutes becomes one unit per scenario, `SUITE/NAME@N`, and stays split
  once it has scenario rows. The Gherkin runner takes `FILE.feature@N` and lists
  them with `--list-scenarios` (`self_hosting/gherkin_select_selftest.patlang`).
  From the record of the last full run that splits twelve features into 116 units,
  among them `block_model/library_selftest_parity` (11), `part2/compiler_structure`
  (24) and `part1_v2/programs` (23).
- **`--failed`** reruns only the units whose last run failed, and the record drops
  rows for units that no longer exist at the end of each run.
- **`tools/edit_files.py`** has its tests as the `edit_tool` unit.
- **A unit that reports a failed test fails** even when it exits 0: its last
  `tests: N passed, M failed` line decides too. `interp_run_selftest` had passed
  that way with two checks failing after `get` began giving `unit`.
- **The block-model suite is retired.** It tested the old route's block-model
  engine, and its longest scenarios (zs_refine and zs_explore re-run inside that
  engine, 83 and 28 minutes) set the floor of a full run. The eleven library
  selftests its parity feature ran are in `run_selftests.patlang`, on v2, where
  they take 2 to 25 seconds each.
- **The demos are a suite:** `self_hosting/tools/run_demos.patlang` lists the
  programs in `demos/` with `--list`. Each runs as a unit (`demos/NAME`),
  interpreted and compiled, and both outputs are compared with
  `demos/expected/NAME.txt`. The repository suite checks that every program in
  `demos/` is listed and has its expected output.

2026-11-19:

- **The packages' specs are suites,** `pkg_deflate`, `pkg_zip`, `pkg_sha256`,
  `pkg_resolve` and `pkg_trust`: each package's `spec/run_spec.patlang` on the
  interpreter, which lists its feature files with `--list` (`run_suite`) and
  exits 1 on a failure. They read `packages/` and `self_hosting/lib`, and call
  Python's oracle (`spec/oracle.py`) as their steps say. Until now they ran only
  by hand, and none was in a gate.
- **The strict-names suite** (`names`, `self_hosting/tools/run_names_check.patlang`):
  each demo and gated selftest is a unit, `v2.exe PROGRAM --names`, failing when the
  program calls a name nothing declares. It found `lean_run.patlang` calling `to_str`
  and `random_int`, which v2 has neither of, on a path no test took.
- **`ci_wasm`, v2 without Windows** (`tools/ci_wasm.sh`): the compiler built from the
  bootstrap IR by `bootstrap/ir_wasm.py`, run under Node with the disk as its files
  (`run_node.mjs --real-files`), builds each demo as WebAssembly, and each runs and
  prints its expected output; the demos using sockets are skipped. The same script is
  the Linux CI job, `.github/workflows/v2-wasm.yml`. It found the compiler built as
  WebAssembly stopping on `v2_own_path`'s contract (a browser has no program path).
- **Failure injection** (`self_hosting/wasm_fail_selftest.patlang`): the browser's
  host makes the nth call to a named system function fail (`run_node.mjs --fail
  NAME:N`), and a program reading a file with its open, size or read made to fail
  gives what `read_file` gives for a file that cannot be read. The selftests suite
  reads the host's directory for it.
- **Engine fuzzing** (`self_hosting/engine_fuzz_selftest.patlang`,
  `lib/engine_fuzz.patlang`): programs made from seeds, of the calls findings B1 and B2
  were about, print the same interpreted and compiled.
- **Planning takes seconds:** the planner (`plan`, runtime `logic.patlang`)
  grew as the cube of the stale units, 546 s for 511 of them; it now grows as
  their square.

2026-11-20:

- **`part1_linux`** runs the part-1 fixtures as Linux executables: each is built
  with `v2.exe --linux` (a static ELF, lib/x64_elf_link.patlang) and run under
  WSL's Ubuntu-24.04 (`v2_linux_run`, lib/v2_engines.patlang), through
  `spec/linux_peak.patlang`, itself a Linux build, which gives the fixture's
  output and its peak resident set from `wait4` (wsl.exe's own peak would say
  nothing about the fixture).
- **`language_linux`** runs the language scenarios with `--linux` given to the
  runner: "compiled" is then a Linux build run under WSL (`run_compiled_linux`,
  lib/program_run.patlang). A scenario whose program starts the interpreter
  starts the Linux build, `self_hosting/build/v2_interp_linux` (the unit
  `interpreter_linux`), since a Windows interpreter started through WSL's
  interop listens on a loopback the Linux program cannot reach.
- **`showcase`, `showcase_linux` and `showcase_compare`** run the showcase
  programs (docs/plans/showcase-programs.md): `run_demos.patlang --dir showcase`
  runs each interpreted and compiled (or, with `--linux`, as a Linux build) against
  `showcase/expected/NAME.txt`, and gives a program with
  `expected/NAME.constant_time.txt` to `v2.exe --constant-time` as well. A
  program with `expected/NAME.html` is run with `--page PATH` on each engine, and
  the page each writes (to a file of its own under `spec_out()`, removed first) is
  compared with that file;
  `run_showcase_compare.patlang` runs each Python sketch in `showcase/compare/`
  against the program's expected output, or the sketch's own in
  `showcase/compare/expected/`. `demos_linux` runs the demos as Linux builds. The two
  showcase engines share the lane `showcase`, and the demos' the lane `demos`.
- **Lanes are per feature file.** A suite's lane names a set of resources its
  scenarios hold (a fixed port, a queue topic, a file in the tree); unit
  `SUITE/FEATURE` gets the lane `LANE/FEATURE`. `language_interp`,
  `language_v2`, `language_linux` and `match` share the lane `language`, so
  one feature never runs on two engines at once, and different features run
  side by side. (`language_linux` first had a lane of its own: its
  `build_daemon_exemplar` ran beside `language_v2`'s, and the two shared
  port 9410, the task registry and the daemon's history file.)
