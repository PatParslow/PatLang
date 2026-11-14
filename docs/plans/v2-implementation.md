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
- **Calls are fitted to the declaration**: a last parameter named `rest`
  receives the remaining arguments as a list (`send`, `exec_capture`).
  Missing arguments were unit and extra ones dropped, silently, on every
  engine including `pat`; since the project owner's decision of 2026-11-08
  a wrong number is an error (spec 1.13): refused when compiling a call by
  name (`lw_fit_args`), a failed precondition when calling a closure. A
  closure's block now holds how many parameters it takes (at 32) and whether
  the last is named `rest` (at 40), its captured values moving to 48. A
  `callv` whose closure takes as many parameters as it is given, none of
  them `rest`, calls it directly; otherwise the same arguments go to
  `rt_closure_call_N` (`runtime/closures.patlang`), which fits them as a
  named call does (`rt_closure_fit`) and calls the closure through
  `closure_call_unchecked`, a `callv` marked as already fitted. So a closure
  is fitted alike through a variable, `apply`, `send`, `parallel_map` and
  `thread_spawn(closure, args...)`. This is the x64 and WebAssembly code
  generators, the interpreter, and both Python bootstrap readers. A closure
  call has at most 8 arguments, refused beyond that when compiling. Each
  layout or runtime-interface change was bootstrapped in two steps (the new
  compiler built first against the runtime the installed one was built
  with), and the fixpoint holds. `takes none` now means no parameters, in
  `self_hosting/lib/parser.patlang` (a language scenario in
  `function_definition_and_return.feature`); before, it declared a
  parameter named `none`, which the padding of missing arguments hid.
  `new`'s optional name is now its `rest`. The gates pass (2026-11-09):
  fixpoint, bootstrap and WebAssembly identical; part 1 119/119 on both
  engines, engines agree 62/62, part 2 104/104, language 251/251 on both,
  match 26/26, block model 211/211. A program's value is not printed (spec 1.13),
  now a scenario in `programs.feature`, which passed before this change. The cache reused code from the old code
  generator during this change, because a job's key hashes the compiler's
  sources on disk rather than the compiler that runs
  ([#254](https://github.com/PatParslow/PatLang/issues/254)). The symbol
  index this needs is the swarm plan's barrier B1.
- **A compiler's key is recorded when it is built (#254).** When v2 builds a program that
  declares `jb_compiler_key`, it writes `OUT.key` beside it: the hash of every source the
  program was built from, as they were read. The compiler reads the key beside itself
  (`jb_compiler_key`, `jobs.patlang`) and mixes it into every job's key, so sources changed
  on disk since it was built no longer take part. A compiler with no key, the IR reader's
  first one for instance, builds without the cache and says so. The gates install
  compiler b's key with it. The scenario "a compiler's cache key is the one recorded when
  it was built" failed before (RED: a keyless copy of v2.exe reused stored code) and now
  passes. Gates: part 1 121/121 on both engines, engines agree 62/62, part 2 111/111,
  language 251/251 on both, match 26/26, block model 211/211.
- **The logic engine's work grows with what each call needs (#252).** The rules are a vec,
  and a second index keeps each predicate's rules in a vec of its own (`logic.patlang`,
  state 4224 and 4464), so `rule_add` pushes in place and a goal visits only its own
  predicate's rules. A rule whose head holds a constant the goal contradicts is skipped
  before renaming, and a ground fact is not renamed at all; solutions gather in a vec.
  The issue's probe: 8,000 rules added in 69 ms (was 8,784), and a bound goal over 6,400
  facts in 9.9 ms (was 96). The scenario "the logic engine's work grows with what each call
  needs" (programs.feature) failed on all three counts before and passes on both engines.
  Gates: part 1 122/122 on both engines, engines agree 62/62, part 2 111/111, language
  251/251 on both, match 26/26, block model 211/211.
- **Rules live in stores (#255).** A store is a cell, class `rule_store` (14), holding its
  rules, its index by predicate and a hash of its ground facts, so it holds each fact once.
  Named stores are a list at state 4464 (4224 is now unused): the program's rules are in
  `"default"`, contract facts in `"contracts"`, and `solve`, `query` and `plan` read both.
  `solve_in`, `solve_into` and `plan_in` take a store or a list of stores; a rule's
  `in NAME` and a body goal's `from NAME` (`self_hosting/lib/parser.patlang`) name a store,
  looked up when solving, so a rule never holds a store and no cycle forms. `rules_clear`
  empties the default store, and `store_delete` forgets a name. Spec 1.13; the scenario "rules
  live in stores, which goals draw from together and solve into" (programs.feature), a
  `rule_store` row in bounded_memory.feature and `type_of` in values_are_objects.feature,
  and in the language suite "a rule declaration can name the store it goes in…"
  (rule_declaration_sugar.feature). The grammar (`docs/grammar/patlang-full.peg`) has
  `in` and `from`. A new built-in class moves `value_live`'s limit from 13 to 14 in every
  back end (`x64.patlang`, `wasm.patlang`, `bootstrap/ir_reader.py`, `bootstrap/ir_wasm.py`)
  and in `docs/spec/ir.md`, so the first compiler with it came from the IR reader: the
  compiler the old one builds rejects a store. The old engine (`pat`, `patc1`) does not have
  `in` or `from`, so its own language run cannot read the steps file. `list_dir` of a path
  with no directory now gives `[]` instead of ending the program (the scenario "list_dir of a
  path with no directory gives an empty list"). Both scenarios in programs.feature failed
  before and pass on both engines. `plan_with_state(goals)` keeps its one-argument form; the
  planner over a list of stores is `rt_plan_from`. Gates: part 1 125 on each engine, engines
  agree 62, part 2 111, language 254 on each engine, match 26, block model 211; the compiler
  reaches a fixpoint and the IR reader's and WASM builds match.
- **`using` blocks (#253).** As the project owner decided on 2026-11-10, the default store
  stays, and `using kb as logic do ... end` gives the plain logic forms (`rule_add`, `fact`,
  `solve`, `query`, `rules_clear`, `plan`, `plan_incremental`, `plan_with_state` and a `rule`
  declaration with no `in`) the store `kb` instead. The parser gives `["Using", [[expr, role],
  ...], body]`; `lw_using_rewrite` (`self_hosting/v2/lower.patlang`) rewrites the body to the
  forms taking a store, binding the store once to a hidden local, so a closure written inside
  captures it and a named function called from inside is untouched. It stops at an inner block
  giving the same role. New runtime forms `fact_in`, `query_in`, `rules_clear_in` and
  `plan_with_state_in`. `logic` is the one role: the planner's actions, event handlers and
  signals are not yet store values, and another role is an error when compiling. Spec 1.13,
  the grammar, `using_store_blocks.feature` (six scenarios) in the language suite, and "a using
  block naming a role with no store is refused when compiling" in programs.feature. Both
  failed before and pass on both engines. The gates pass (2026-11-10): part 1 127/127 on
  both engines, engines agree 62/62, part 2 111/111, language 270/270 on both engines, match
  26/26, block model 211/211.
- **Integers modulo n (#251, first of three increments).** As the project owner decided on
  2026-11-10: `mod_make(x, n)`, `mod_value` and `mod_modulus`, no new syntax; `type_of` gives
  `modint`, printing as `3 mod 7`; the bit operators, and the new `rotl` and `rotr`, only when
  n is 2^k (k up to 62), stopping the program otherwise. Class 15, in `runtime/numbers.patlang`:
  residue at 16 and modulus at 32, freed by the `rt_finalize` branch for rationals, so
  `value_live`'s limit is 15 in x64, WASM, both Python readers and `ir.md`. Operators reach it
  through `op_add_quiet`, `op_sub`, `op_mul`, `op_div` and the `op_b*`/`op_sh*` slow paths;
  `/` multiplies by the inverse from the extended Euclidean algorithm, and `pow` squares and
  multiplies. Spec 1.14 and `modular_integers.feature` (nine scenarios, including a SHA-256
  written on modint words against the four FIPS 180-4 example digests), plus a modint row in
  bounded_memory, and `modular_integers.feature` (two scenarios) in the language suite. The
  feature failed before and passes on both engines (19/19), as do bounded_memory (22/22) and
  the language feature (16/16 interpreted and compiled). The gates pass (2026-11-10):
  part 1 147/147 on both engines, engines agree 62/62, part 2 111/111, language 286/286 on both
  engines, match 26/26, block model 211/211. The third increment is X25519 and Ed25519
  against RFC 7748/8032 and Wycheproof.
- **Constant-time modints and the check (#251, second increment).** As the project owner
  decided on 2026-11-10: every modint operation's time depends on n alone, `pow` also on the
  exponent's sign and size; inversion is inside that promise for every n; and the check is a
  compiler mode, `compile.patlang SRC --constant-time` (spec 1.14, 2.7). The runtime keeps a
  residue as 32-bit limbs in its block, after a header computed from n: Montgomery
  multiplication for an odd n, masking for 2^k, and a fixed shift-and-subtract reduction
  otherwise. Every choice is a mask. Inversion is Möller's binary algorithm (GMP's
  `mpn_sec_invert`) in 2 * bits(n) steps for an odd n, Newton's iteration for 2^k, and the two
  joined by the Chinese remainder theorem for any other even n; `pow` is a ladder over the
  exponent's limbs. `self_hosting/v2/ct.patlang` follows the IR before ownership, with a
  state per slot (secrecy as pointer depth, possible classes, small known values, type-word
  classes) and summaries keyed by a coarse form of the argument states, joined within a key.
  Three unit primitives, `ct_secret`, `ct_public` and `ct_reveal`, mark what the IR cannot
  show, in every backend and both Python readers. On the way: the first form, without class
  tracking, followed string code from inside `op_add_quiet` for a modint; keyed by exact
  states it made a summary for every intermediate state; values read from lists could be
  modints, until a value with no secret behind it is known not to be one; and a freed scratch
  block made the allocator's lists secret, until freeing marks its pointer public.
  `constant_time.feature` (four scenarios): a program using every operation is reported
  clean, and a branch on `a == b`, arithmetic and an address from a residue's word, and
  `mod_value` are each reported. The modint features pass natively on the new runtime, with
  new cases for each inverse; the check takes about 150 s a program, most of it following the
  runtime's public code. Gates pass: part 1 156/156 on each engine,
  engines agree 62/62, part 2 111/111, language 286/286 on each engine,
  match 26/26, block model 211/211.
- **X25519 and Ed25519 in PatLang (#251, third increment).** `self_hosting/v2/lib/sha512.patlang`
  (SHA-512 on words modulo 2^64) and `self_hosting/v2/lib/curve25519.patlang` (X25519 by the
  Montgomery ladder of RFC 7748, Ed25519 key making, signing and verifying by RFC 8032 in
  extended coordinates), written on modints with no choice made by a secret: every scalar bit
  is a modint, and the ladders pick their points by arithmetic on it. For them the runtime
  gained words up to 2^64, `mod_make` of a modint (its residue reduced modulo the new
  modulus, in time that depends on the two moduli alone) and of a modint's modulus, which
  reuses the header already worked out. `self_hosting/v2/tools/curve25519_vectors.py` writes
  `cv_vectors.patlang` from RFC 7748, RFC 8032 and Wycheproof. `curve25519.feature` (five
  scenarios): the FIPS 180-4 digests, RFC 7748's outputs and its 1,000-iteration case (the
  1,000,000-iteration one runs outside the suite, at about 167 ms an iteration, with
  self_hosting/v2/tools/x25519_million.patlang, which saves a checkpoint every 1,000
  iterations and resumes from it; a run stopped at 2,000 and resumed reaches the same k at
  3,000 as one run straight through; the full run, started 2026-11-11 and resumed once from
  its checkpoint at 10,000, finished on 2026-11-14 with k =
  `7c3911e0ab2586fd864497297e575e6f3bc601c0883c30df5f4dd2d24f665424`, RFC 7748 section
  5.2's value, its last 990,000 iterations taking 179,845 s at 181 ms each on the runtime
  before the modint speed-up below), all 518 Wycheproof X25519 cases, RFC 8032's keys and
  signatures, and Wycheproof Ed25519 verification (117 valid accepted, 64 invalid rejected,
  and the 29 marked acceptable all accepted). Two new scenarios in the language suite's
  `modular_integers.feature`, and a fifth in `constant_time.feature`: the check finds no
  value-dependent step in X25519, Ed25519 key making or signing. On the way, the check
  exploded on these programs into hundreds of reports over an hour, all from values read
  out of lists. Three changes brought it to about 4 minutes and none: the list code marks
  a list's length, count, room and type words public; a call whose argument may be of
  several classes is followed once per kind of class, each with the secrecy that kind can
  carry, so a callee's `require` prunes the rest; and the libraries read each element
  through `mod_make(x, shape)`, which settles its class. Tracking what classes each block
  holds, tried first, gave eight times the summaries and still lost the classes, because
  the slots a store is traced back to are gathered across the whole function, so a store
  into a fresh block was charged to an argument; lists of lists of secrets are still
  reported (spec 2.7). The vector fixtures pass natively and the check passes the curve
  fixture. The v2 gates on 2026-11-11 pass: compilers a and b byte identical, the bootstrap
  reader's build and the WASM identical; part1_v2 163/163, part1_interp 163/163, engines_agree
  62/62, part2 111/111, language 297/297 on both engines, match 26/26, block model 211/211.
  Measured on 2026-11-12, most of a modint operation's time was the check that its operands
  share a modulus: two values each made by `mod_make(x, n)` hold separate bigints for n, and
  comparing bigints took about 13 of the 24 microseconds an addition modulo 2^255 - 19 took.
  `rt_mod_same_modulus` now compares the limb count, kind, bit count and n's limbs already in
  the two blocks; `rt_mod_like` copies the modulus value without `mod_modulus`'s comparison
  with 2; `rt_mod_set_int` skips the bit-by-bit reduction for an integer of fewer limbs than
  n, which is already below n; and modular addition and subtraction use one scratch array,
  not two. An addition went from 24 to about 7.5 microseconds, a multiplication from 27 to
  about 11, `mod_make` of a small integer from 55 to about 12, and one X25519 from 174 to
  about 95 ms. What is left is mostly the generated code's own cost, about 15 ns a word
  operation. The gates on 2026-11-12 pass, with the same counts as above.
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
- **Not built in v2:** `goal`, `action_add_numeric`, `plan_numeric`, `fluent_set`,
  `class_def`, `tcp_try_connect`, `tls_counter_next`, `world_run`,
  and the functions tied to the Rust
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
- **The name `unit` (GitHub #244).** Spec 1.13: `unit` is the unit value unless the program binds
  it, as a parameter or with `let`. The lowerer gives the constant when the name has no slot.
  `vi_unit` checks both cases on both engines.
- **`let xs = list_push(xs, f(xs))` copied the list (GitHub #239).** The lowerer gave `xs` to the
  call only when no other argument mentioned it, so a push whose value read the list copied all of
  it each time. Every argument is evaluated before the value is given, so the other arguments may
  read it. 16,000 such pushes took 2,574 ms and now take 3 ms; `bm_push_scale` checks that twice
  the pushes take at most about three times as long. The native compiler's own link went from
  151 s to 73 s.
- **The interpreter's speed (GitHub #238).** Each function is translated once into one list of
  ints, read word by word, with its constants in a second list; frames come from one block the
  interpreter allocates, not a list per call; the rarely run kinds sit in a function of their own
  so that the loop's frame on the machine's stack stays small; and `op_add` adds two ints
  directly when no handler is registered. `bench_fib` runs in 14.8 s, where it took 104.9 s,
  measured on the same loaded machine. Taking the string into a local before `op_add_taken`
  kept a second reference, so every `s = s + x` copied the string; `bm_append_scale` now appends
  16 characters at a time, so that a copy costs more than the loop, and fails on that mistake.
  400,000 appends take 887 ms, where they took 3,326 ms.
- **The signals scenarios claimed fixed ports.** A claim of 9601 failed once because another
  program held the port for a moment. They now claim port 0, so the system picks a free one,
  and the second claim takes the port the first one got; the language suite passes 242/242 on
  `pat`, on the interpreter and compiled by v2.
- **The linker's name index (GitHub #239).** `xpl_build_index` gave every index 4096 buckets,
  and the link builds one for each chunk's own local names as well as the whole symbol table,
  hundreds in all, so making and freeing empty buckets took about a quarter of the link. The
  bucket count now doubles up to the number of names. The compiler's link of itself went from
  47.8 s to 30.4 s, and `rt_facts` links in 12.5 s, where it took 20.9 s.
- **The link's relocations (GitHub #239).** Each relocation built its value's bytes as lists
  (`xa_int_to_bytes_le`), and one to a chunk's local symbol made a `$L` key and was looked up
  twice, once among the chunk's locals and once in the whole table. A relocation's bytes now go
  straight into the section with `band` and `shr`, a local target is resolved to its symbol in
  the first pass, and the symbol table indexed for the rest holds only global names. On
  2026-11-08 a warm build of a one-line program linked in 8.2 s, where it took 16.1 s, and the
  compiler's link of itself took 22.0 s, where it took 49.2 s. Both executables are byte
  identical to before, and the compiler's build of itself is byte identical to its own.
- **Reading a stored artefact (GitHub #239).** The record was read byte by byte, each byte made
  into a one-character string and each number read back from text, which took most of a warm
  build's jobs. It is now read as text through `str_intern`'s handle, each field cut out with
  `sc_substr` and each number read digit by digit. The jobs of a warm build of the compiler take
  7.8 s, where they took 29.0 s. The old reader also turned each byte of a non-ASCII name into its
  own character. Identifiers are ASCII, so no program met it, but the new scenario "a stored
  record reads back as written, whatever characters its names hold" failed on it (RED) and passes
  on the new reader.
- **A job's key (GitHub #239).** Hashing a function's IR allocated a list for every byte mixed, and
  turned every integer into decimal text first. The two lanes are now kept in locals for a whole
  string or integer, and an integer is mixed as its eight bytes. A warm build of a one-line program
  computes its keys in 1.06 s, where it took 4.08 s, and the compiler hash in 0.13 s, where it took
  0.43 s; the executable is byte identical. The new scenario "a job's key tells values apart by
  their structure" passes on both engines, and fails on a copy that mixes only an integer's low
  byte. Gates pass (below).
- **`vec_extend` (GitHub #239).** It pushed its items one call at a time, each through
  `list_push`'s checks. It now makes room once (`rt_list_reserve`, new in `runtime/lists.patlang`)
  and copies each element in with a reference of its own, as `rt_list_copy` does. The link of a
  warm one-line build takes 6.7 s, where it took 7.6 s, so the whole warm build is about 12.3 s
  (front end 2.2, keys 1.05, jobs 2.2, link 6.7). The program built is byte identical to the same
  program built by the previous compiler from the same runtime sources. A new scenario, "a vec
  extended with a list keeps its order, and a list taken from it before keeps its value", passes;
  peak memory stays at 5.4 MB from 500 to 4,000 rounds of extending and dropping vecs. Gates
  pass (below).
- **The interpreter's slots and the compiler's inline slots (GitHub #238), 2026-11-14.** The
  translated code now holds each operand as its byte offset in the frame, and each jump as the
  byte offset of its target, so the loop no longer multiplies a slot number on every read. The
  x64 code generator also works out, per function, which slots only ever hold inline values
  (every write a literal, a machine word or a copy of another such slot) and emits no heap-bit
  test for their retains and releases (spec 2.2, rule 5). The interpreter's heap-bit tests fell
  from 118,089 to 76,699. Measured on the same machine: `bench_fib` 8.9 s, where it took 15.7 s;
  `bench_manycalls` 14.6 s (24.3 s); `bench_sumloop` 15.4 s (31.5 s); `bench_strconcat` 2.8 s
  (4.2 s). The new scenario "a slot that only ever holds an inline value is never tested for a
  heap block" failed before the change (RED) and passes. Gates pass (below).
- **v2 gates on 2026-11-14, after the inline slots:** fixpoint byte identical, bootstrap and WASM
  identical; part1_v2 163/163, part1_interp 163/163, engines_agree 62/62, part2 114/114,
  language 297/297 on both engines, match 26/26, block model 211/211.
- **v2 gates on 2026-11-08, after the keys and `vec_extend`:** fixpoint byte identical, bootstrap
  and WASM identical; part1_v2 100/100, part1_interp 100/100, engines_agree 62/62, part2 104/104,
  language 250/250 on both engines, match 26/26, block model 211/211.
- **v2 gates on 2026-11-08, after the relocations and the reader:** compilers a and b byte
  identical; the bootstrap reader's build identical to v2.exe; the WebAssembly writers agree;
  Part 1 99/99 on v2 and on the interpreter; engines agree 62/62; Part 2 103/103; the language
  suite 245/245 on the interpreter and compiled by v2; match 26/26; the block model suite
  211/211.
- **v2 gates on 2026-11-07, after the name index:** Part 1 89/89 on v2 and on the interpreter;
  `engines_agree.feature` 62/62; Part 2 83/83; the language suite 242/242 on the interpreter
  and compiled by v2; the match suite 26/26 and the block-model suite 211/211 on the
  interpreter; the three compiler generations byte identical.
- **v2 gates on 2026-11-06, after the new interpreter:** Part 1 89/89 on v2 and on the
  interpreter; `engines_agree.feature` 62/62; Part 2 83/83; the language suite 242/242 on the
  interpreter and compiled by v2; the match suite 26/26 and the block-model suite 211/211 on the
  interpreter; the three compiler generations byte identical.
- **v2 gates on 2026-11-06, after those two:** Part 1 89/89 on v2 and on the interpreter;
  `engines_agree.feature` 62/62; Part 2 83/83; the language suite 242/242 on the interpreter and
  compiled by v2; the match suite 26/26 and the block-model suite 211/211 on the interpreter; the
  three compiler generations byte identical.
- **The assembler's byte encoding (GitHub #239).** `xa_int_to_bytes_le` found each byte of a
  value by repeated subtraction from a list of powers, so a large displacement cost thousands of
  operations. It now takes the bytes from the top down, each bit by bit against the byte's
  weight, and a byte above the value costs one comparison. The compiler's link of itself went
  from 73-75 s to 48-53 s and its jobs from 279 s to 235-239 s; `rt_facts` links in 25 s, where
  it took 38 s. These were measured while other builds ran. The gates passed as listed above,
  rerun after the change, and the three generations stayed byte identical.
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

- An unfinished fiber keeps its stack, and its id can still resume it. Settled on
  2026-11-09: that is what a fiber is for (spec 1.8).
- A fiber that yields inside an event handler shares its thread's list of running events.
  Settled on 2026-11-09: each fiber has its own list, swapped in and out by `fiber_resume`
  (spec 1.4; `concurrency.feature`). The gates pass (2026-11-09), part 1 120/120 on both
  engines.
- `thread_spawn` of a closure with parameters is not caught: a thread passes it none. Settled
  on 2026-11-08: `thread_spawn(closure, args...)` passes the arguments after the closure, and
  their number is checked before the thread starts (spec 1.8, 1.13).
- A `syntax` definition must start a line. Settled on 2026-11-09: it need not, since line
  breaks are not syntax. Only v2's check for whether a file needs expanding
  (`v2_defines_syntax`) looked at line starts; the extractor already finds a definition
  anywhere outside strings and comments. That check now looks for the word anywhere
  (`syntax_definitions.feature`); compiling the compiler takes as long as before. The
  gates pass (2026-11-09), part 1 121/121 on both engines.

## 8. Baseline

The interpreter, 2026-11-02, against Part 1: 32 passed, 10 failed. The
failures are what Part 1 adds or changes: bool arrays; `new` returning an
object; operator methods and `raises`; int's operator events and the
re-entrancy rule; identity equality for unnamed objects; and the bool
array memory loop. `exec` grew from 10 to 11 MB between 20 and 200 runs,
to be rechecked at larger counts.
