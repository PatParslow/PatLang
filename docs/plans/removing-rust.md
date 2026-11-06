# Removing Rust

PatLang's toolchain should build and run with no Rust in it. v2 (`docs/plans/v2-implementation.md`)
is part of that. Three things still depend on Rust:

- `pat --ir-run` runs the compiler, the suite runners and everyday development.
- WASM goes through generated Rust source and `rustc`.
- A clean checkout starts from a Rust build.

## Decisions

Made by the project owner on 2026-11-05:

- Work moves to v2 as and when that is viable, and `pat --ir-run` retires with it.
- WASM's main target is the browser, with fibres and threads, as on the old route.
- Bootstrapping will use a small IR reader written in other languages. It takes an IR produced for
  this purpose and compiles it.

## Order

1. **Close the gaps the survey found.** This shows whether v2 is viable as the everyday route.
2. **Move tooling off `pat --ir-run`** ([#246](https://github.com/PatParslow/PatLang/issues/246)).
   The compiler, suite runners and portfolio build run on the native v2 compiler and the v2
   interpreter.
3. **Specify the IR and write the first reader**
   ([#247](https://github.com/PatParslow/PatLang/issues/247)). The reader builds the compiler from
   the IR, that compiler builds itself, and the generations must be byte identical.
4. **Build the browser WASM backend and host**
   ([#248](https://github.com/PatParslow/PatLang/issues/248)). This can run alongside steps 2 and 3.
   The old compiler can't retire until it is done, being the only WASM route.

## The survey

On 2026-11-05, 418 programs that existed at the `pre-v2` tag were compiled with v2, from
`self_hosting/examples`, `benchmarks`, `cross_backend_benchmarks` and `tools`, `rust-runtime/examples`,
`spreadsheet` and `friendly_cli`. Programs whose file and includes show no side effect were also run
on v2, the v2 interpreter and `pat --ir-run`, with 120 s allowed per run. `friendly_cli` was compiled
only, as its owner will run it. The filter for side effects is a text search and is not complete:
`self_hosting/tools/build_all.patlang` got through it.

| | Programs | Compile on v2 | Fail to compile |
|---|---:|---:|---:|
| Run on all three | 185 | 169 | 16 |
| Not run: side effects | 106 | 77 | 29 |
| `friendly_cli`, compile only | 127 | 101 | 26 |
| **Total** | **418** | **347** | **71** |

Of the 185 that were run:

| Outcome | Programs |
|---|---:|
| Exit 0 on all three, same output once numbers and `pat`'s final value are set aside | 89 |
| Exit 0 on v2 and its interpreter, and `pat` fails | 7 |
| Exit 0 on all three, output differs | 4 |
| v2 finishes, its interpreter doesn't in 120 s | 3 |
| Run on `pat`, stop with an error on v2 | 14 |
| Run on `pat`, rejected at compile time on v2 | 12 |
| Run on `pat`, unfinished on v2 in 120 s | 2 |
| Fail on `pat` too | 54 |

Of the 54 that fail on `pat` too, 50 compile on v2 and 41 of those stop on `host fn 'X' not found`.
24 of those 41 are `x64_*` programs, most calling the old runtime's internals, such as `rt_print_i64`. Others are fragments that rely on being included. Some in this group, such as contract
demos, fail on purpose. They aren't gaps in v2.

Not covered: `archive/`, `agent_work/`, and `self_hosting/block_model` and `self_hosting/lib`, which
are exercised through the suites and as compiler code. The 106 programs with side effects remain
unproven at run time, and so do `friendly_cli`'s programs.

### Second run

The survey was run again on 2026-11-06, after the gaps below were worked on. The side-effect filter
now also catches programs calling builders such as `build_*`, `exec_*` and `spawn_*`, so
`build_all.patlang` was compiled and not run, and 180 programs were run where there had been 185.

- **Compile on v2:** 385 of 418, against 347 before.
- **The 33 that fail:**

  | Failures | Cause |
  |---:|---|
  | 16 | `undefined variable unit` ([#244](https://github.com/PatParslow/PatLang/issues/244)) |
  | 9 | an include path that doesn't exist |
  | 4 | bare undefined names in `rust-runtime/examples` |
  | 3 | parse errors |
  | 1 | `CHUNK_MARKERS` |

- **Run:** 174 of the 180 compiled.
  - Same output on v2 and its interpreter: 165, different: 9.
  - Same output as `pat`: 97, different: 77. Many of the 77 print timings, or report errors in
    `pat`'s own format.

The four in `rust-runtime/examples` are unchanged. They test the Rust runtime, and one,
`oo_logic_mix`, asserts that a bare `X` reads as itself.

## Gaps

### Wrong results

- **`bnot` gave a bool** ([#235](https://github.com/PatParslow/PatLang/issues/235)). `bnot 0` gave
  `true` where `pat` gives `-1`, with no error and no scenario covering it. Fixed, with scenarios in
  `math.feature` that pass on both engines.
- **The engines disagreed** on `x64_plan_with_state_demo`, which spec 1.7 doesn't allow
  ([#245](https://github.com/PatParslow/PatLang/issues/245)). They agree now.
- **Threads shared the system-call count word** ([#249](https://github.com/PatParslow/PatLang/issues/249)),
  found by the compile-time benchmark below. Fixed, with a scenario in `concurrency.feature`.

### Programs that run on `pat` and not on v2

| Programs | Failure | Issue |
|---:|---|---|
| 31 | `declared twice` | [#243](https://github.com/PatParslow/PatLang/issues/243) |
| 16 | `undefined variable unit`, including `build_portfolio` and `build_site` | [#244](https://github.com/PatParslow/PatLang/issues/244) |
| 7 | `undefined variable AST`, in syntax definitions | [#242](https://github.com/PatParslow/PatLang/issues/242) |
| 5 | Contract in `apply_subst`, from goals and actions: now pass, see below | [#240](https://github.com/PatParslow/PatLang/issues/240) |
| 3 | `no method X for Y`: 2 now pass, see below | [#241](https://github.com/PatParslow/PatLang/issues/241) |
| 5 | Smaller cases | [#245](https://github.com/PatParslow/PatLang/issues/245) |

Since the survey, by the project owner's decisions below, with the gates passing on 2026-11-06:

- **#243.** A program may define a name the runtime has, and its own calls use its definition. Two
  program files defining one name is still an error.
- **#240.** Six `paradigm_gallery` demos wrote facts flat, `["has_wood", "yard"]`, where the tutorial
  and 40+ other uses write `["has_wood", ["yard"]]`. Facts are nested only, and the demos now use the
  nested form. The 5 that failed this way give the same output on v2, its interpreter and `pat`.
- **#241.** A string holding an object's name could assign a field but not read it. Now it can do
  both (spec 1.1, `values_are_objects.feature`, on both engines). `functional_oo` and `oo_event`
  give the same output on all three. `new` with arguments it doesn't take is an error, and
  `oo_inline_inherit` uses `class ... inherits ...`.
- **#242.** Spec 1.9 includes `AST`, and the 7 syntax-definition demos give the same output as
  `pat`. In those demos the `AST` route builds nodes and then drops them.
- **#245.** Bare undefined names stay an error, and the programs using them were changed, apart from
  the four in `rust-runtime/examples`.
- **#244.** The name `unit` is the unit value unless a program binds it (spec 1.13), as on `pat`.
  The 16 programs that stopped on it now compile on v2. The 15 that use the `world`
  libraries, and `interp_budget_probe`, then stop on `set_var`, which is gone, and they fail on `pat` too.
  `build_portfolio` read two top-level `let`s inside functions, and these are functions now. It
  defined `q` and `nl` three times, through `codegen`, `html` and `transpile_ruby`, which now
  share them from `lib/chars.patlang`. It compiles on v2; it has not been run, as it writes the
  site and calls `patc1` and `rustc`.

The first two rows count every program with that failure, whether or not it was run, so not all of
them were seen working on `pat`. `friendly_cli` compiled with 3 failures on the old route and has 26
on v2.

Expected differences, needing no fix in v2: `set_var` is gone, as decided
(`closure_stored`, `x64_to_s_and_rational_mod`). `world_run` belongs to the old route. 9 files fail on
an include path that doesn't exist; the one checked, `family_tree_main`, fails on `pat` too.

### Speed

| Benchmark | `pat` | v2 native | v2 interpreter |
|---|---:|---:|---:|
| `bench_fib` | 1,964 ms | 115 ms | 73,556 ms |
| `bench_manycalls` | 2,832 ms | 145 ms | 136,448 ms |
| `bench_sumloop` | 3,325 ms | 155 ms | 164,633 ms |
| `bench_strconcat` | 1,951 ms | 266,366 ms | 273,249 ms |

- **v2 native** is 17-21 times faster than `pat` on the first three.
- **The v2 interpreter** is 37-50 times slower than `pat`
  ([#238](https://github.com/PatParslow/PatLang/issues/238)). This is the main obstacle to step 2.
- **The native compiler** takes 103 s on a tiny program where the same compiler on `pat` takes 30 s,
  81 s of it linking ([#239](https://github.com/PatParslow/PatLang/issues/239)). Half of the link
  was `let xs = list_push(xs, f(xs))` copying the list on each push; with that fixed, the
  compiler's link of itself takes 73 s, where it took 151 s, and its self-compile 369 s, where it
  took 456 s.
- **Named objects** took quadratic time: 814 ms at 1,000 objects and 49.7 s at 8,000, where `pat` goes
  from 57 ms to 84 ms ([#236](https://github.com/PatParslow/PatLang/issues/236)). Now 0.63 s at 8,000,
  growing about linearly.
- **`s = s + x`** copied the whole string each time
  ([#237](https://github.com/PatParslow/PatLang/issues/237)). `bench_strconcat` now takes 0.18 s on
  v2 and 4.8 s on its interpreter, where it took 266 s and 273 s.

### Compile time

Measured on 2026-11-06 on 24 programs that v2 compiles, spread evenly by size. Each was compiled
cold, with only the runtime in the compiler's store, and then warm, the same program unchanged.
`lines` counts lines that are neither blank nor comments, with each include expanded once. The old
compiler is `patc1.exe --x64`, with its own object cache; its x64 route uses one thread. v2 ran with
`--workers 8`, on `pat --ir-run` and as the native compiler.

23 programs compiled on both. `logic_dsl` fails on the old compiler. Four v2 native runs first
failed on #249, so those four programs were measured again with the fix in.

| Compiler | Median, cold | Cold, against lines | R² | Median, warm | Warm, against lines | R² |
|---|---:|---|---:|---:|---|---:|
| Old | 17.9 s | −1.3 s + 45.6 s per 1,000 | 0.98 | 17.2 s | 14.3 s + 34.6 s per 1,000 | 0.98 |
| v2 on `pat` | 31.8 s | 27.4 s + 9.6 s per 1,000 | 0.98 | 29.3 s | 26.7 s + 3.9 s per 1,000 | 0.93 |
| v2 native | 102.0 s | 86.1 s + 29.5 s per 1,000 | 0.99 | 91.6 s | 83.0 s + 11.5 s per 1,000 | 0.95 |

| Program | Lines | Old, cold / warm | v2 on `pat` | v2 native |
|---|---:|---:|---:|---:|
| `host_caps_probe` | 1 | 11.9 / 12.6 s | 37.0 / 23.4 s | 77.6 / 82.8 s |
| `peg_check_main` | 669 | 24.3 / 22.7 s | 32.9 / 27.3 s | 105.5 / 86.7 s |
| `queue_bdd_demo` | 1,491 | 47.7 / 97.2 s | 37.2 / 29.3 s | 122.6 / 92.7 s |
| `synth_demo_ticket_state_machine` | 3,330 | 126.6 / 141.3 s | 51.3 / 35.6 s | 166.0 / 112.2 s |
| `synthesis_experiment_goap_package_loop` | 5,540 | 193.8 / 196.5 s | 84.9 / 48.3 s | 271.9 / 150.4 s |
| `discover_patlang_stdlib_specs` | 15,241 | 731.0 / 542.9 s | 175.1 / 89.0 s | 531.9 / 261.4 s |

- **Small programs:** the old compiler is fastest, at about 12 s. v2 has a fixed cost of about 28 s on
  `pat`, and about 89 s native, of which 65 to 72 s is linking
  ([#239](https://github.com/PatParslow/PatLang/issues/239)).
- **Large programs:** v2 grows more slowly. By the fits, v2 on `pat` is faster than the old compiler
  cold from about 800 lines, and v2 native from about 5,500. Of the programs measured, v2 native is
  faster only on the largest, at 15,241 lines.
- **Warm builds:** v2 reuses each unchanged function, so a warm build costs a little over the fixed
  cost. The old compiler's warm builds are no faster than its cold ones, and on several large
  programs they are slower.
- **The survey** compiled 385 programs with v2 on `pat`, 4 at a time, with a store already warm
  from earlier builds: median 46.8 s, and 40.2 s + 14.7 s per 1,000 lines, R² 0.68.

### Workers

The native v2 compiler built each program cold at 1, 2, 4, 8 and 16 workers, on a machine with 12
cores and 20 threads. `hello` was built with `--no-cache`, which compiles the runtime as well.

| Program | Lines | 1 | 2 | 4 | 8 | 16 | Speed-up at 16 |
|---|---:|---:|---:|---:|---:|---:|---:|
| `host_caps_probe` | 1 | 97.9 s | 83.8 s | 76.3 s | 72.5 s | 70.3 s | 1.39 |
| `peg_check_main` | 669 | 146.3 s | 121.8 s | 100.5 s | 93.2 s | 89.5 s | 1.63 |
| `queue_bdd_demo` | 1,491 | 211.5 s | 161.2 s | 128.7 s | 114.8 s | 102.2 s | 2.07 |
| `compile.patlang`, v2 itself | 9,174 | 995.3 s | 646.2 s | 478.3 s | 385.5 s | 326.3 s | 3.05 |
| `discover_patlang_stdlib_specs` | 15,241 | 1,548.6 s | 1,005.2 s | 692.1 s | 562.9 s | 496.4 s | 3.12 |
| `hello`, `--no-cache` | 1 | 576.6 s | 360.6 s | 241.2 s | 181.4 s | 154.1 s | 3.74 |

- **What doesn't run in parallel:** the link takes 60 s for a small program and 215 s for the largest,
  whatever the worker count. The front end and the keys add 6 to 22 s.
- **The jobs** scale better than the whole build. For `hello` with `--no-cache` they take 508 s at 1
  worker and 83 s at 16, 6.1 times faster.
- **Contention:** the time the workers spend assembling, summed over all of them, grows with their
  number. For `hello` it is 494 s at 1 worker and 1,052 s at 16. What they contend for has not been
  measured.
- **The default of 1 worker** is the slowest setting in every case. 8 workers give most of the gain.
