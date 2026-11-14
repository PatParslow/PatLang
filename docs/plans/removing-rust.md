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
   Done: [#245](https://github.com/PatParslow/PatLang/issues/245) and
   [#233](https://github.com/PatParslow/PatLang/issues/233) were closed on 2026-11-14 after
   checking them against the current v2. The gaps left are speed, under step 2.
2. **Move tooling off `pat --ir-run`** ([#246](https://github.com/PatParslow/PatLang/issues/246)).
   The compiler, suite runners and portfolio build run on the native v2 compiler and the v2
   interpreter.

   Progress, 2026-11-07:
   - The language and match suites start their programs on v2 (`self_hosting/lib/v2_engines.patlang`),
     and `gates.sh` runs every suite on the v2 interpreter. In the run of 2026-11-07 the fixpoint
     was byte identical, and the counts were:
     - Part 1: 99/99 on both engines;
     - `engines_agree`: 62/62;
     - Part 2: 83/83;
     - language: 245/245 on the interpreter and compiled by v2;
     - match: 26/26;
     - block model: 211/211.
   - v2 gained what the scenarios needed: `sed`, the stage-0 shims, `progress_report` and
     `progress_status`, `plan_incremental`, and `action_clear` (spec 1.10 and 1.13).
   - Spec 1.10 now says `chr` of anything but an int stops the program. The old engine truncated,
     and `self_hosting/lib/utf8.patlang`'s `utf8_encode` still relies on that.
   - `build_daemon_demo` announces itself once it has claimed its port, and the suite waits for
     that announcement.
   - Still on `pat`: the first `v2.exe` when there is none, the block-model suite's own steps
     (they test the old engine), and the portfolio build.

   Progress, 2026-11-14:
   - **The block-model suite** runs its fixtures and their reference programs on the v2
     interpreter (`bm_v2_engine` in `spec_steps_block_model.patlang`), and nothing in it starts
     `pat` or `patc1`. The engine's boxes are on v2's allocator (`block_model/heap_v2.patlang`),
     and its contract checks, shared with `lib/interp.patlang`, on v2's contract runtime
     (`lib/contracts_v2.patlang`). It now registers classes with v2's `class_define`, runs a
     `budgeted` body on v2's `rt_budgeted`, and keeps its own table of action bodies. Where the
     scenarios asserted what `pat` printed, they now assert what v2 prints:
     - a program's value is not printed (spec 1.13);
     - `object_delete` gives `true`;
     - a missing field reads as `false`;
     - a named object's `name` field is its name;
     - `set_var` is gone.

     A parameter named `rest` takes the further arguments as a list (spec 1.13). The engine's
     own `list_concat_one(first, rest)` collected its arguments that way, and is now
     `(first, items)`. `lib/interp_run.patlang`'s child interpreter is the v2 interpreter, run
     on the program's file. In the gates of 2026-11-14 the suite, compiled by v2, passed all
     210 tests, and every other gate passed (fixpoint, bootstrap reader, WASM, part 1 on
     both engines 163/163, engines agree 62/62, part 2 117/117, language 297/297 on both
     engines, match 26/26).
   - **`build_site`** runs compiled by v2, taking the site's folder as an argument. Run on a
     copy of the site, it wrote the same files as `pat` running it. It copies the portfolio's
     current layout, `demos/` and the service worker included. It reads the self-hosting
     roadmap from `archive/legacy-root-2025/docs/`, where the roadmap went in 9cbdd71, and
     stops on a document it cannot read rather than writing an empty page.
   - **`build_portfolio`** runs compiled by v2. It builds every demo with v2, natively for
     its transcript and as WebAssembly for the page, with no `patc1`, `rustc` or `pat`:
     - Each page runs its module on v2's browser host (`tools/portfolio_runner.js` over
       `v2/wasm/`'s layout, launcher and executor), with the executor started from a Blob.
     - `portfolio/coi-sw.js`, a service worker, makes a page cross-origin isolated on a host
       that sends no headers.
     - A demo card runs its own module. The playground, the REPL and the IDE still compile
       and run the user's source in the page, with `lib/interp.patlang`'s `interpret_ir`
       where `pat`'s host `run_ir` was.
     - The build caches on the demo's source and v2's compiler key, and builds four demos at
       a time.
     - `patbuild`'s page is gone, since it builds its targets with `rustc`.
     - The demos that had not followed their libraries' change to `ctx` parameters (maze, pos,
       pos tests, report, the signals and build-daemon drivers) now pass the context.
     - The libraries' calls of `goal(...)`, a no-op host function of `pat`'s, are gone.

     In headless Chrome, every demo page ran its program and printed what it should, both with
     the server sending the isolation headers and, for four of them, with the service worker
     supplying them. `contracts` ends in the precondition it breaks on purpose.
   - **A call to a name nothing declares** made a WebAssembly build fail: its stub took no
     parameters, and the call passed arguments. A call of such a name now passes none, and
     the scenario "a call with arguments to a name nothing declares stops there in a
     WebAssembly build too" covers it.
   - **Worlds** ([#256](https://github.com/PatParslow/PatLang/issues/256), spec 1.15). `pat`'s
     host `world_run` ran a program in-process by swapping every global store for an empty one.
     v2 has worlds instead, each an object holding a program's state: its named objects,
     classes, handlers, functions reached by name, logic stores, contract facts and virtual
     files (`runtime/worlds.patlang`):
     - `world_call(w, f)` runs a closure in a world, on a fiber. A stop there ends the call, not
       the program, and what the world prints stays in it.
     - A fiber runs in the world it was made in and a thread in the world that started it.
       Worlds nest, and a world can have a step budget, which the interpreter spends.
     - Nothing is swapped. The runtime finds the world through the thread's context.

     `lib/interp_run.patlang`'s world backend compiles a program's text with the compiler's
     front end and runs it in a fresh world on the v2 interpreter, which is now a library
     (`v2/interpreter.patlang`) as well as a command (`v2/interp.patlang`). The world backend
     and the process backend therefore run the same interpreter and print the same.
     Isolates' turns run in worlds too. The interpreter lowers a program against the runtime's
     declarations alone, since it calls the runtime's compiled functions, which takes its start
     from 3.9 s to 1.7 s. A run in a world costs about 100 ms. `interp_run_selftest` (54
     tests) and `isolate_selftest` (65) are in the gates now. The gates' first run with worlds
     passed everything except `queue_signals_vfs_selftest` under block-model: its isolate
     section brought in the v2 interpreter, which block-model's IR interpreter cannot run, and
     interpreting a program that asks for every runtime function by name overflowed the stack
     (the program's own registrations hid the runtime's; fixed in `iv_table`). That section
     is now in `isolate_selftest`. After the fix the affected suites were re-run on their own,
     since the full gates take about five and a half hours: part1 on the interpreter 174/174,
     the worlds feature 11/11 on both engines, the language suite 297/297 interpreted,
     `queue_signals_vfs_selftest` 28/28 under block-model and the interpreter alike,
     `isolate_selftest` 65/65 compiled and interpreted, `interp_run_selftest` 54/54
     compiled and interpreted.
3. **Specify the IR and write the first reader**
   ([#247](https://github.com/PatParslow/PatLang/issues/247)). The reader builds the compiler from
   the IR, that compiler builds itself, and the generations must be byte identical. Done, and
   the issue was closed on 2026-11-14; `gates.sh` checks the chain on every run.

   Progress, 2026-11-07:
   - The IR is specified in `docs/spec/ir.md`, and `compile.patlang ... --ir` writes it. The
     compiler's own IR is 4.1 MB.
   - The first reader, `bootstrap/ir_reader.py`, is written in Python, as the project owner chose.
     It builds a compiler from the compiler's IR in about 3 seconds.
   - That compiler built the compiler with `--no-cache` in 6 minutes. Its build is byte identical
     to v2's own build of the compiler, and to the build it then made of itself.
   - `gates.sh` builds its first `v2.exe` this way, from `bootstrap/v2_compiler.ir`, and checks the
     chain on every run. Since 2026-11-14 no step of any suite starts `pat`.
   - The `compiler_structure.feature` scenario builds a program reaching every kind of
     instruction from its IR, and checks that it gives the same output as v2's own build.
4. **Build the browser WASM backend and host**
   ([#248](https://github.com/PatParslow/PatLang/issues/248)). This can run alongside steps 2 and 3.
   The old compiler can't retire until it is done, being the only WASM route.

   Progress, 2026-11-07:
   - `compile.patlang ... --wasm` writes a WebAssembly module from the IR
     (`self_hosting/v2/wasm.patlang`). It uses its own encoder, with no `rustc` or LLVM.
     `bootstrap/ir_wasm.py` writes the same bytes from the IR text. The two agree byte for byte
     on the compiler's own 8.5 MB module, and `gates.sh` checks this.
   - The host in `self_hosting/v2/wasm/` runs the module in a browser or in Node. Each thread
     and each fibre is a Worker over one shared memory, and the program runs in a Worker,
     never on a browser's main thread. A fibre takes the per-thread context of the thread that
     resumes it. `docs/spec/ir.md` gives the module's form and the host.
   - Of v2's 99 runtime spec fixtures, 85 give the same output and exit code under Node as
     on the v2 interpreter. Of the other 14:
     - 8 use files or processes, which a browser does not have;
     - 4 are where the interpreter differs from the native build, and WASM gives what the
       scenarios expect;
     - 3 are fixtures that must fail to compile.
   - The `compiler_structure.feature` scenario runs a program with a fibre, a thread, an
     operator event and a broken contract in headless Chrome. It checks that the program
     prints what v2's own build prints.
   - **The IR keeps enough structure.** Functions are laid out as nested WASM loops and
     blocks. Where the jumps cross, a loop is lengthened or a block started earlier. All
     829 of the compiler's functions are laid out this way, and so are the 6,456 of
     `rt_big_frame` and the fixtures' functions. A jump into a loop other than at its head
     could not be, and v2's lowering never makes one.
   - In the gates run of 2026-11-07, every suite passed: part 1 on both engines (99), engines
     agree (62), part 2 (93), the language suite on both engines (245), match (26) and the
     block model (211).
   - **Not done:**
     - **Huge functions.** A function with tens of thousands of slots is slow to start in V8's
       first compiler tier, where each branch costs time in proportion to the locals
       ([#250](https://github.com/PatParslow/PatLang/issues/250)). Since 2026-11-08, slots never
       live at the same time share a pair of locals. The compiler's 913 functions need 16,960
       pairs for their 62,487 slots, but `rt_big_frame`'s `__main` still needs 3,005 pairs for
       15,049 slots, and takes 26 s in that tier (38 s before; 1.1 s optimised). Its 3,000 `if`
       conditions are temporaries that a branch reads, which the ownership stage holds until the
       return, so each keeps a pair. The browser is a presentation layer: the compiler is built
       as WebAssembly only to check the two writers against each other, never to run there, so
       this waits until a program that size has to run in a browser.
     - **Writer speed.** The PatLang writer takes about 10 s per MB of module.

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
  the four in `rust-runtime/examples`. Checked again on 2026-11-08, the issue's other four programs
  give the same output on v2 and its interpreter:
  - `mandelbrot_demo` prints what `pat` prints, apart from its own timing line.
  - `x64_float_bitwise_native` stops at `band` on a float, as spec 1.11 says and its header
    records; `pat` prints 62.
  - `robots_demo` prints a `SIGNAL` line each time a robot's fiber emits, as its header says it
    should. `pat` prints none: its handler no longer fires for an event emitted inside a fiber.
  - `cga_classifier` prints everything `pat` prints except a last `true`: `pat` prints the value
    of the program's last top-level expression, and v2 does not. The project owner decided on
    2026-11-08 that a program's value is treated as any function's: nothing prints it unless the
    program does (spec 1.13). v2 is right.
- **#244.** The name `unit` is the unit value unless a program binds it (spec 1.13), as on `pat`.
  The 16 programs that stopped on it now compile on v2. The 15 that use the `world`
  libraries, and `interp_budget_probe`, then stop on `set_var`, which is gone, and they fail on `pat` too.
  `build_portfolio` read two top-level `let`s inside functions, and these are functions now. It
  defined `q` and `nl` three times, through `codegen`, `html` and `transpile_ruby`, which now
  share them from `lib/chars.patlang`. Since 2026-11-14 it runs on v2 and builds every demo
  with v2 (step 2 above).

The first two rows count every program with that failure, whether or not it was run, so not all of
them were seen working on `pat`. `friendly_cli` compiled with 3 failures on the old route and has 26
on v2.

Expected differences, needing no fix in v2: `set_var` is gone, as decided
(`closure_stored`, `x64_to_s_and_rational_mod`). `world_run` belongs to the old route; v2's worlds (spec 1.15) do what it did. 9 files fail on
an include path that doesn't exist; the one checked, `family_tree_main`, fails on `pat` too.

### Speed

| Benchmark | `pat` | v2 native | v2 interpreter |
|---|---:|---:|---:|
| `bench_fib` | 1,964 ms | 115 ms | 73,556 ms |
| `bench_manycalls` | 2,832 ms | 145 ms | 136,448 ms |
| `bench_sumloop` | 3,325 ms | 155 ms | 164,633 ms |
| `bench_strconcat` | 1,951 ms | 266,366 ms | 273,249 ms |

- **v2 native** is 17-21 times faster than `pat` on the first three.
- **The v2 interpreter** was 37-50 times slower than `pat`
  ([#238](https://github.com/PatParslow/PatLang/issues/238)), the main obstacle to step 2. Its
  translated code is now one list of ints, its frames come from one block, and two ints add
  directly: `bench_fib` 14.8 s, `bench_manycalls` 26.1 s, `bench_sumloop` 32.1 s and
  `bench_strconcat` 3.2 s, measured while other programs were running, so 1.6-10 times
  slower than `pat`. On 2026-11-14 the translated code began holding byte offsets in place of
  slot numbers, and the compiler stopped testing the heap bit of slots that only ever hold
  inline values: `bench_fib` 8.9 s (`pat` 2.1 s), `bench_manycalls` 14.6 s (2.9 s),
  `bench_sumloop` 15.4 s (3.4 s) and `bench_strconcat` 2.8 s (6.9 s), so 4-5 times slower than
  `pat` on the first three and faster on the fourth. Most of what remains is the compiled code
  itself: every temporary goes to the stack, every reference count is an atomic add, and
  contracts are checked as it runs.
- **The native compiler** takes 103 s on a tiny program where the same compiler on `pat` takes 30 s,
  81 s of it linking ([#239](https://github.com/PatParslow/PatLang/issues/239)). Half of the link
  was `let xs = list_push(xs, f(xs))` copying the list on each push; with that fixed, the
  compiler's link of itself takes 73 s, where it took 151 s, and its self-compile 369 s, where it
  took 456 s. Encoding the assembler's bytes from the top down took the link to about 50 s, and
  sizing the linker's name index to its names took it to 30.4 s (`rt_facts`: 20.9 s to 12.5 s).
  On 2026-11-08 a warm build of a one-line program took 32 s: front end 2.6 s, keys 4.5 s, reading
  its 457 stored functions 8.9 s and linking 15.1 s. Writing relocations straight into the
  sections, resolving local targets per chunk and reading stored records as text took the reading
  to 2.7 s and the link to 8.2 s, about 18 s in all; the compiler's own warm link went from
  49.2 s to 22.0 s. Hashing keys with the lanes in locals and integers as bytes took the keys from
  4.1 s to 1.05 s, and a `vec_extend` that makes room once took the link to 6.7 s: about 12.3 s in
  all; the gates pass on both.
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
