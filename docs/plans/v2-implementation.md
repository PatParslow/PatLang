# The new compiler and runtime (v2): implementation plan

Status: started 2026-11-02; section 7 and 7a give what is built and verified. Implements `docs/spec/values-and-memory.md` as
decided in `docs/plans/memory-design-review.md` (section 6). The spec's
executable form, `spec_library/values_and_memory/`, is the gate, run by
`self_hosting/v2/spec/run_values_and_memory.patlang` against the
interpreter (`interp`) or v2 (`v2`).

## 1. What is reused, what is new

Reused unchanged: the lexer and parser (`self_hosting/lib/lexer.patlang`,
`parser.patlang`), extended only for new syntax (operator method names,
`raises`); the assembler (`x64_asm.patlang`, NASM-subset text to a chunk
image); the PE linker (`x64_pe_link.patlang`).

New, in `self_hosting/v2/`:

| file | job |
|---|---|
| `compile.patlang` | the driver: runs the stages as jobs, in order |
| `ir.patlang` | the intermediate representation and its well-formedness contract |
| `lower.patlang` | one declaration's AST to IR |
| `own.patlang` | inserts retains and releases by the five rules (spec 2.2) |
| `x64.patlang` | one function's IR to assembly text |
| `contracts.patlang` | the one place that decides whether contracts are checked |
| `runtime/*.patlang` | the runtime, compiled by the same stages as any program |

The interpreter runs the compiler during development (`pat --ir-run
self_hosting/v2/compile.patlang SRC OUT.exe`).

## 2. Values in machine code

- **Two words.** Type word, then data word. In a frame, a list slot or an
  argument, a value takes 16 bytes, type at the lower address. A function
  returns its result's type word in `rax` and data word in `rdx`.
- **Type word**: bits 0-31 the class id; bit 32 set when the data word
  points to a counted heap block (the only test retain and release make);
  bit 33 reserved for per-value metadata. Built-in class ids: 0 unit,
  1 bool, 2 int, 3 float, 4 bigint, 5 rational, 6 complex, 7 interval,
  8 string, 9 list, 10 closure, 11 string_builder, 12 vec, 13 bool_array;
  ids from 64 up are classes a program declares, named in the class table.
- **Heap block**: a 16-byte header, `[count:8][size:8]`, then the payload.
  The block records its own size, so freeing it never recomputes the size
  from the contents (the BigInt size-class bug of 6d cannot recur).
- **Calls.** The caller pushes each argument's two words, last argument
  first, and pops them after the call. Arguments are borrowed. The callee
  addresses its parameters above `rbp` and its locals below it, 16 bytes
  each. Calls to the operating system use the Windows x64 convention,
  through `extern_call` (section 4).

## 3. The IR

A function is a list of instructions over numbered slots, each a two-word
value in the frame:

- `["const", dst, kind, text]`: an int, float, bool, unit or string literal;
- `["copy", dst, src]`;
- `["call", dst, name, [args]]`: a PatLang function, user or runtime alike;
- `["op", dst, op, a, b]`: a binary operator (section 5);
- `["prim", dst, name, [args]]`: a machine primitive (section 4);
- `["label", L]`, `["jump", L]`, `["branch", slot, L_true, L_false]`;
- `["return", slot]`;
- `["retain", slot]`, `["release", slot]`, inserted only by `own.patlang`.

`ir_well_formed(fn)` is the IR's contract: every jump has its label, every
slot is written before it is read, `retain`/`release` appear only after the
ownership stage. Each stage `require`s it of its input and `ensure`s it of
its output.

## 4. Primitives

The runtime is PatLang. What PatLang cannot say in terms of other PatLang
is a primitive: a fixed set, part of the language, each compiled inline:

- memory: `mem_load(addr, off)`, `mem_store(addr, off, word)` (raw 64-bit
  words), `mem_load_value`/`mem_store_value` (a two-word value, the store
  taking a reference to it), `mem_load_byte`, `mem_store_byte`;
- words: `word_add`, `word_sub`, `word_mul`, `word_and`, `word_or`,
  `word_shl`, `word_shr`, `word_lt`, ... on raw 64-bit words, no overflow
  promotion;
- `value_make(type_word, data_word)`, `value_type(v)`, `value_data(v)`;
- `atomic_add(addr, n)`;
- `extern_call(dll, function, args...)`: a Windows x64 call.

The compiler knows these by their fixed definitions, as it knows `+`. It
knows nothing about any runtime function by name.

## 5. Operators and events

`a + b` compiles to an inline fast path, under its condition, and the
method call otherwise:

- if both type words are int, and int's event flag says no handler is
  registered for `+`'s events: a machine add, with overflow promotion to
  bigint through int's `+` method;
- otherwise: a call to the left operand's class method `+`, which raises
  its declared events (with the re-entrancy rule of spec 1.4).

## 6. Milestones

Each milestone ends with its scenarios GREEN on v2, the earlier ones still
GREEN, and the interpreter results unchanged.

1. **Skeleton.** Driver, IR, lowering of ints, bools, `let`, `if`/`elif`,
   `while`, functions and calls; code generation; a runtime with
   `print` of an int and process exit. `print(1 + 2)` runs. Contracts on
   the IR from the first stage.
2. **Memory and strings.** The memory manager (spec 2.3, one thread
   first), counted blocks, the ownership stage, strings, string `+`,
   `to_s`, `type_of`.
3. **Lists**, with value semantics by count: a list whose count is 1 is
   changed in place, any other is copied. Bounded-memory loops for
   strings and lists.
4. **The numeric tower**: floats, bigints, rationals, complex, intervals,
   with their printing. `integers.feature`.
5. **Classes and events**: class declarations, `new`, methods, operator
   methods, `raises`, `when`/`emit`, named objects, `object_delete`.
   `operator_events.feature`, `value_and_identity.feature`.
6. **Closures, builders, vecs, bool arrays, files, processes, `argv`.**
   All of `spec_library/values_and_memory` Part 1 on v2, and
   `engines_agree.feature` against the interpreter's results.
7. **Part 2 scenarios** (`@runtime`): representation, ownership, the
   per-thread memory manager, contracts, compiler structure.
8. **Jobs and artefacts**: the ledger, content-addressed artefacts,
   caching, then parallel workers (`memory-design-review.md` section 7).
9. **The rest of the language** to pass `spec_library/language` on v2.
10. **Self-hosting**: v2 compiles its own compiler and runtime.
11. **The interpreter on the new runtime**, so Part 1's agreement holds by
    construction.

## 7. Progress

As of 2026-11-03, milestones 1 to 6 are built: `self_hosting/v2/` compiles
and runs every Part 1 scenario's fixture, and `run_values_and_memory.patlang
v2` passes 42 of 42 checks (every `@language` feature but
`engines_agree.feature`, which needs the interpreter to meet Part 1 too:
milestone 11). What they needed beyond this plan's first draft:

- **Arguments hold a reference of their own.** A variable passed to a call
  goes through a temporary that takes one, released after the call
  (`own.patlang`). A count of 1 in a callee then means nothing else holds
  the value, so `list_push`/`list_set` change a list in place exactly
  then. `let l = list_push(l, x)` gives `l`'s value to the call (`take`),
  so building a list is amortised O(1). The count must be read directly
  from the parameter's block: passing it to a helper adds a reference.
- **Parameters are borrowed**, never released by the callee; one the body
  reassigns is copied into a local first.
- **`quiet_operators()`**, a primitive declaration at a file's top level:
  that file's operators raise no events. The runtime's files declare it,
  so its own arithmetic never raises a program's `added` events.
- **Calls are fitted to the declaration**: missing arguments are unit,
  and a last parameter named `rest` receives the remaining arguments as a
  list (`send`, `exec_capture`). The symbol index this needs is the swarm
  plan's barrier B1.
- **`extern_call_float`**, for C functions taking and returning doubles.
- **Intervals** came last, as spec 1.12 (`intervals.feature`): class 7, in `runtime/numbers.patlang`,
  freed by the same `rt_finalize` branch as rationals and complex numbers. They were missing
  until a read-through of the spec against the runtime on 2026-11-04 found them.

Milestone 7, as of 2026-11-03: `run_runtime.patlang` passed 38 of 44
checks, and `run_values_and_memory.patlang v2` 42 of 42 with every
runtime function's contract checked; the assembler's shared state and
three milestone-8 scenarios were left, all since done (below). What it
needed:

- **Every runtime function has its contract**: `require` on its
  parameters (a function with none has nothing to require) and `ensure`
  before every return, the returned value first bound to the declared
  result name. `rt_live(v)` is the contract for a parameter that may be
  any value.
- **A temporary nothing reads is released when it is made.** A call made
  for its effect (`b.v = x` as a statement, whose value is `x`) otherwise
  held its result until the function returned, so an overwritten field's
  old value outlived the overwrite.
- **A lock moves a batch, never a block**: a thread reusing another's
  freed blocks takes the pool's lock about once per half batch
  (`rt_batch_high()`), 14 times for 2000 blocks, when its local free list
  spills or refills.

Milestone 8, as of 2026-11-03: `run_runtime.patlang` passes 49 of 51
checks, the two left the scenarios below that do not fit two-word values
as written; `run_values_and_memory.patlang v2` passes 42 of 42. The
values-and-memory suite takes 77 minutes with artefacts reused, most of it
its own long-running fixtures, linking (20 s a build) and reading
artefacts back (15 s).

- **Program facts are an artefact** (`OUT.facts`): the events handled, the
  names passed for `by_name` parameters and the rules, each recorded by
  the lowering where it is declared. A rule is registered at start as data
  (`runtime/logic.patlang`); queries over rules are milestone 9.
- **One job per function** (`jobs.patlang`): the ownership stage, code
  generation and assembly, giving the function's chunk; the chunks are
  linked in declaration order. A job's key hashes the function's IR, what
  code generation reads of the facts (`xv_facts_used`), the summary of
  every function it calls, and the compiler stages' source. Its
  artefacts (`self_hosting/build/v2_artefacts`) are reused by any later
  build with the same key. A second program reuses all 238 of the
  runtime's jobs and builds its own 5; a warm build of a fixture takes
  about 40 s, of which linking 241 chunks is 20 s.
- **A caller depends on its callee's summary**: under the ownership
  stage's uniform rules a summary is a function's arity, borrowed
  parameters and an owned result. Changing g's body leaves f's key, so f
  is reused and only g built.
- **Workers**: `--workers 8 --shuffle 7` runs the jobs on eight threads in
  a shuffled order; the jobs took 46 s against 206 s on one, and the two
  executables are byte-identical.
- **The assembler keeps no shared state**: `lib/x64_asm.patlang`'s state
  is a vec local to each assembly, no longer a named object whose name
  came from a counter (GitHub #197). The current compiler uses it too;
  its gates pass with the change (native 126/126, block model 224/224,
  language 184/184, a Gen B self-compile whose output runs).

A job's record now gives the length of each of its artefacts and ends in a marker line; an
artefact shorter than that is built again rather than used, whether an interrupted build or
another build writing it at that moment cut it short. No rename is needed, since a job's
artefacts are the same bytes whoever writes them.

Eviction is explicit (GitHub #234): `compile.patlang --evict KEEP_MB` removes whole jobs, least
recently used first. A build marks each job it reuses by rewriting its record.

Existing programs on v2 were surveyed on 2026-11-05. The results, the gaps they showed and the work
that follows are in `docs/plans/removing-rust.md`. The `friendly_cli` results under "Removing the
globals" below are from `pat --ir-run` and the old route, so they say nothing about v2.

Three behaviours the project owner decided to keep on 2026-11-05, now in spec 1.13 and
`programs.feature`: a function without `return` gives its last statement's value, `exec_capture`
gives both outputs, and a file is included once. With these in, Part 1 is 69/69 on v2 and on the
interpreter and `engines_agree.feature` 50/50. No compiler or runtime source changed, so the other
gates were not rerun.

Questions found on the way, for the project owner:

- Some `@runtime` scenarios do not fit two-word values as written:
  `contracts.feature`'s "an int type word and a pointer in its data word"
  is simply an int, and returning a borrowed argument without a reference
  cannot be written, since the ownership stage adds the reference.
- The events whose handlers are running are kept per thread (each
  thread's memory context), so two threads raising events never share a
  list. A handler that starts a `parallel_map` whose worker raises the
  handler's own event therefore runs that handler again on the worker's
  thread. Spec 1.4 does not say whether a worker's operations are the
  handler's own.
- `include` in v2 and the v2 interpreter takes a file once, by its normalised path, before
  the files that include it, as `compiler_structure.feature` states. `pat --ir-run` and the old
  compiler were recorded as splicing text every time, so a file reached by two includes would run
  its top-level statements twice there.
- A contract clause that holds is a `contract_holds` fact once in v2, on
  the first thread; the interpreter adds a rule at every pass, which grows
  without limit in a loop. `solve` therefore counts clauses in v2 and passes
  in the interpreter. The spec's bounded-memory rule decides for v2's.
- The reused assembler keeps its state in named objects (`new`/`send`),
  shared mutable state that `compiler_structure.feature` rules out for a
  stage.
- Each language construct compiles to a call of a runtime function that
  implements it (`op_add`, `send`, `rt_member`, `rt_on`, `class_define`,
  `rt_list_alloc`, `rt_retain`/`rt_release`, ...). These are the
  construct's protocol, not ownership facts: the compiler holds no fact
  about any function's ownership, which the ownership stage derives the
  same way for all.

## 7a. Milestone 9: the language suite without globals

The language suite (`spec_library/language`, run by
`self_hosting/tools/run_language_spec_suite.patlang`) runs its steps as
PatLang functions under the Gherkin runner `lib/test.patlang`. For v2 to
run it, v2 compiles the runner, the steps and the libraries they test as
one program. The runner and steps keep their state in globals
(`set_global`/`get_global`, `set_var`/`get("__vars", ...)`), which v2 does
not provide and the project is removing, so they move to an explicit
context first, keeping the suite green under the interpreter throughout:

- `lib/gherkin.patlang`, the runner: a run's state is one context, a vec. Its
  functions take it: `expect(ctx, label, actual, expected)`, `step(ctx, text,
  fname)`, `run_feature(ctx, text)`; a step function takes `ctx` (called by name
  through `apply`). Feature text is read as bytes, so the runner has no
  interpreter-only string cursor.
- `lib/context.patlang`, the store under it: named values in hashed buckets, which
  stay fast with thousands of names (`ctx_get`, `ctx_set`, `ctx_has`, `ctx_num`,
  `ctx_text`, `ctx_counter`). An unset name reads as `false`, 0 or `""` by which
  accessor reads it. A top-level `when` handler takes no arguments, so a program
  whose handlers use its context holds it in a named object (`context_hold`,
  `context_held`). A vec belongs to its thread, so a `parallel_map` worker is handed
  its values as items and makes its own context.
- `spec_steps_language.patlang` moves to it: a step's values in the run's
  variables (`ctx_set`/`ctx_get`); a top-level `when` handler, which can
  take no context, records what it sees in a named object. Done: the suite
  passes 184 of 184 under the interpreter with output identical, line for
  line, to `test.patlang`'s. The clause helpers both runners use are in
  `lib/gherkin_clauses.patlang`, the text helpers in
  `lib/gherkin_text.patlang`.
- Then v2 compiles the suite: what it needs is found by compiling it
  (`include`, the libraries the steps test).
- The libraries the steps test (signals, queue, sql, task_registry) are
  checked for globals the same way when v2 reaches them.

Status of milestones 9 to 11, 2026-11-04. The results below were run on the migrated
sources described under "Removing the globals".

- **Milestone 9.** The language suite, now with the five
  `spec_library/language/symbolic_*.feature` files, compiles as one v2 program and
  passes 242 of 242 on `pat --ir-run`, v2 and the v2 interpreter. Its output on v2 and
  on the v2 interpreter is identical but for lines that vary by run; `pat` also prints
  the program's last value. Scenarios that compare engines by spawning `pat --ir-run`
  and `patc1 --x64` still run those engines as subprocesses, so they check them, not v2.
- **`match`** is built in v2's lowering, and the match suite passed 26 of 26 on `pat
  --ir-run`, v2 and the v2 interpreter when last run on each. A value no case takes
  stops the program with a contract violation and exit code 3.
- **Built since:** fibers, `budgeted` and `thread_spawn` (`runtime/fibers.patlang`), and
  `syntax` definitions threaded across a program's files (`front.patlang`), with
  `concurrency.feature` and `syntax_definitions.feature`. `thread_result` takes a result
  once and frees the thread's memory; a second call stops the program. Powers,
  trigonometry, rounding, `to_fixed`, the bit functions and the smaller file functions
  (`runtime/math.patlang`, `math.feature`), and strings that count characters
  (`text.feature`).
- **Found on the way:** a frame longer than a page crashed at start when its first write
  fell below the committed stack and past the guard page. A long frame now touches each
  page on the way down. Non-ASCII text was truncated to bytes: `chr(233)`, `.length`,
  indexes and literals all disagreed with the interpreter.
- **A loop's peak memory** settles over its first iterations, so a comparison has to
  start past that. Threads settle by 2000: 13.8 MB, flat to 32000. The check runs from
  2000.
- **Not built in v2:** `goal`, `action_add_numeric`, `action_clear`, `plan_incremental`,
  `plan_numeric`, `fluent_set`, `class_def`, `tcp_try_connect`, `tls_counter_next`,
  `progress_report`, `exec_peak_memory`, `world_run`, and the functions tied to the Rust
  engine (`run_ir`, `compile_ir`, `compile_shape`, `rustc_build*`, `codegen_prelude*`). A
  call to one stops the program when reached, with the interpreter's message. No
  language scenario reaches them.
- **The block-model suite on v2** builds and passes 211 of 211. It tests the old engine,
  which its scenarios start as `pat --ir-run` subprocesses. It was 199 of 224 after the
  migration, and both causes came from the migration. 24 checks read `t_pass` and `t_fail`
  from a selftest's globals, which are now in its context: 13 of those checks are gone and
  11 now read the totals line the program prints. In `named_objects.feature`, `lib/interp`
  stored a guest's `set_var` in the context and read its `get("__vars", ...)` from the
  host's globals; both now use the context.
- **Found by the match suite and the new contract:** a build with errors exited 0
  (now 1, and 2 for a usage error); a closure with two or more captures crashed on
  the v2 interpreter, which moved the captures block out at its first read; a
  `raises` function whose result was no variable lost it on the same path. Lowering
  now keeps both as variables, and `ir_temps_read_once` is part of lowering's
  contract: one instruction reads a temporary.
- **What it took**, each found by a failing run and matched to the interpreter:
  a block's value is its last statement's (`returns NAME` first, when the body
  assigns it); a bare expression that can only give a value prints it; `and`
  and `or` give bools; what counts as true; `to_num` on text; out-of-range reads
  give unit or `""`; `write_file` makes directories; a program path with a
  directory gets `./`; unit prints as nothing. Floats from text, bigints and
  rationals round exactly once (`rt_ratio_bits`).
- **Speed.** Inline counting (`lock xadd`, the runtime called only at the last
  reference), `value_live` as a primitive, and held slots (own.patlang) took
  `l[3]` from 1880 to 245 ns or less and an allocation with its free from 3 us
  to under 1 us. Small ints no longer go through limbs (`10 / 2`: 90 ms to 50 us).
- **Milestone 11.** `self_hosting/v2/interp.patlang` is the interpreter: written
  in PatLang, built by v2, on the v2 runtime, walking the IR the compiler's own
  front end gives. Part 1 passes 59 of 59 on it, `engines_agree.feature` 35 of 35, the
  language suite 242 of 242 and the match suite 26 of 26. `pat --ir-run` still hosts the
  older suites and the spec runners.
- **Threads calling a function for the first time** raced on the interpreter's vec caches:
  a push moves the list out of the vec, so another thread saw it dead, and 19 of 40 cold
  runs of a language suite failed in different ways. The function table is now a plain list
  built before any thread starts, and each call site's cached target is a write-once cell.
  `concurrency.feature` has the scenario: 20 of 20 failed before, 100 of 100 pass after.
- **Milestone 10.** v2 compiles itself to a fixed point on the migrated sources: the
  compiler built by `pat --ir-run`, its build of itself and that build's build of itself
  are byte identical, as is their assembly, and the last one builds a program that runs.
  Rerun after intervals joined the runtime, with the same result. A cold self-compile takes about
  8.5 minutes on 8 workers, most of it allocation in the assembler.
- **Files and directories (spec 1.7).** The interpreter read the runtime's source relative to the
  current directory, and a file it could not read counted as empty. Started outside the repository,
  it lost the runtime's declarations, so `exec_capture`, `spawn`, `send` and `apply` got unfitted
  arguments; a missing program exited 0 with no output, and a missing include was ignored. The
  interpreter now finds the runtime from its own executable's path, so it must stay at
  `self_hosting/build/` in the repository, and the front end reports a file it cannot read on both
  engines. The compiler itself still runs from the repository's root.
- **Threads calling the system together (GitHub #249).** Every thread wrote the counts from
  `ReadFile`, `WriteFile`, `GetExitCodeProcess` and `PeekNamedPipe` to one word, and formatted
  numbers in one 64-byte buffer, so one thread could read another's count. The native compiler,
  run with `--workers 8`, failed at random on 4 of 21 compiles: `read_file_bytes` returned more
  bytes than asked for. Each thread's context now holds its own word and buffer (`rt_out_word`,
  `rt_scratch` in `memory.patlang`). `concurrency.feature` has the scenario: 8 threads each read
  their own length of one file 400 times and print a number of seven copies of their own digit.
  Before the fix it failed on the contract, with 197 to 236 of each worker's 400 lines printed.
  After it, 16 of 16 pass on both engines.
- **v2 gates on 2026-11-06, after that fix:** Part 1 87/87 on v2 and on the interpreter;
  `engines_agree.feature` 61/61; Part 2 83/83; the language suite 242/242 on the interpreter and
  compiled by v2; the match suite 26/26 and the block-model suite 211/211 on the interpreter; the
  compiler built by `pat --ir-run`, its build of itself and that build's build of itself byte
  identical. A cold self-compile on 8 workers takes about 7.8 minutes.
- **v2 gates, rerun one at a time on 2026-11-05 with intervals and the artefact check in:** Part 1
  65/65 on v2 and on the interpreter; `engines_agree.feature` 47/47; Part 2 75/75; the language suite
  242/242 and the match suite 26/26, each on v2 and on the interpreter; the block-model suite 211/211
  on v2 and on the interpreter; the language suite 242/242 on `pat --ir-run`; the second and third
  generations of the compiler byte identical. Two cold builds of one program at once, sharing the
  artefact store, at 100, 200, 400 and 800 new functions: both exit 0, both print the right total,
  and the executables are byte identical. The old compiler's gates
  were not rerun. Earlier results, before intervals, were: Part 1 59/59 on v2 and on the interpreter; `engines_agree.feature` 35/35;
  Part 2 67/67; the language
  suite 242/242 on `pat --ir-run`, v2 and the interpreter. Part 1 and `engines_agree` ran
  before `lib/test.patlang` and its neighbours were deleted; they do not include them.
  `FAIL: require violated by synthesized plan` in the language log is a diagnostic the
  scenario expects.
- **Restated scenarios.** `contracts.feature`'s representation scenario described an int
  type word with a pointer in its data word, which in two-word values is simply an int.
  It now describes a type word naming no class, or a heap type word with a freed block in
  its data word, given to a function requiring a live value; the project
  owner agreed this on 2026-11-05. "Returning a borrowed argument" is now tested through `value_make`,
  which can build a value with no reference of its own.

### Removing the globals

As decided by the project owner, `set_global`, `get_global`, `set_var` and
`get("__vars", ...)` go in favour of explicit contexts. Status, 2026-11-04:

- **Applied** to `self_hosting` and `friendly_cli`. In `self_hosting`, about 225 files moved from `lib/test.patlang` to
  `lib/gherkin.patlang`, with the libraries they test. A run's state belongs to the function
  that starts the run (`lower_program`, `bm_lower_program_as`, `bi_run_counting`), so those
  keep their signatures. What a compiler's worker threads read (the fingerprint, the
  float-returning functions) is a value, `x64_unit_env`, handed to each. `lib/test.patlang`,
  `lib/gherkin_contracts.patlang` and `lib/block_model_compat.patlang` are deleted.
- **Checked:** `compiler_structure.feature`'s "no program keeps its state in globals"
  searches every tracked PatLang file and those not yet tracked in `self_hosting`, and no
  tracked program includes a deleted file.
- **Compared against recorded output on `pat --ir-run`.** 132 of the runs compared match
  once times and ports are set aside. Of those that differ, 7 failed before the migration
  too, with wrong include paths or a parse error: `image_bdd_demo` and the GPU and triton
  demos. 4 are harmless: a line number in a note, a pool count that also varies between
  runs of the old code, one corpus file skipped because it gained an include, and
  `run_one_feature` with no argument reporting no tests.
- **The old compiler on the migrated sources:** `patc1` and the runtime object rebuild;
  native 125/126, the one being an executable a leftover process held, which passes alone;
  match 26/26; the parity check passes; Gen B builds, and the program it builds runs. These
  ran before the `lib/interp` repair above; the language suite on `pat --ir-run` and the
  block-model suite ran after it. The v2 compiler, the v2 interpreter and the suite runners
  do not include `lib/interp`.
- **`friendly_cli` on the migrated sources.** 68 files moved, the source its programs
  generate was moved by hand, and the 12 `*_expanded` files were regenerated. Many of its
  programs spawn commands, delete files, or use the network or an LLM, so only what is safe
  was run:
  - The 34 programs with none of that in their includes print the same before and after;
    32 exit 0, and `run_demo` and `test_expansion` exit 1 on both.
  - 24 more spawn only `pat`, `pandoc` or PowerShell, on paths inside the scratch tree each
    ran in. All print the same before and after on the same test data; 21 exit 0, and
    `synthesis_experiment_goap_string_domains_honest`, `test_concat_spec` and
    `test_concat_expanded` exit 1 on both.
  - All 127 tracked files were compiled without running. The same 3 fail on both:
    `canvas_host`, `terminal_native` and `test_expansion`.
  - Every call to a function a program's includes define passes the right number of
    arguments.
  - The other 39 have not been run; the project owner will run them. All were compiled, except `canvas_host` and
    `terminal_native`, which fail on both. Sorted by the first of these their includes
    mention: an LLM (16), deleting files, killing processes or an open shell (10), `patc1.exe`
    (6), the network (5), and the terminal or probing `PATH` (2).
  - Faults found that the old sources share, left as they are: the generated healing spec's
    "target file exists" compares `true` with `"1"`; `batch_delete_files` reports files
    removed but never removes one, so `test_bdd`'s check of it passes without a deletion;
    `test_concat_expanded` calls a function that is not defined.
- **Staying, as the project owner decided on 2026-11-05:** `lib/x64_runtime.patlang`,
  `lib/world_native.patlang` and `block_model/heap.patlang` keep theirs as the old native
  runtime's private state, the old compiler's own fixtures test `set_var` as a language
  feature, and `lib/interp.patlang` implements it for the programs it runs. These go when
  the old compiler is retired.

Open questions from this work:

- An unfinished fiber keeps its stack, and its id can still resume it.
- A fiber that yields inside an event handler shares its thread's list of running events.
- `thread_spawn` of a closure with parameters is not caught: a thread passes it none.
- A `syntax` definition must start a line.

## 8. Baseline

The interpreter, 2026-11-02, against Part 1: 32 passed, 10 failed. The
failures are what Part 1 adds or changes: bool arrays; `new` returning an
object; operator methods and `raises`; int's operator events and the
re-entrancy rule; identity equality for unnamed objects; and the bool
array memory loop. `exec` grew from 10 to 11 MB between 20 and 200 runs,
to be rechecked at larger counts.
