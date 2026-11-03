# The new compiler and runtime (v2): implementation plan

Status: started 2026-11-02; milestones 1-6 built (section 7). Implements `docs/spec/values-and-memory.md` as
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
- Intervals are not built yet; no Part 1 scenario uses them.

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

Not done: artefacts are never evicted, and two builds writing the same
key at once can see a partly written artefact (a write to a temporary
name and a rename would close it; there is no rename primitive yet).

Questions found on the way, for the project owner:

- A function that ends without `return` gives unit in v2 and the int 0
  in the interpreter. Spec 1.7 needs one answer.
- `exec_capture` in v2 merges the error stream into the output always; the
  interpreter adds it only when the program fails.
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
- The reused assembler keeps its state in named objects (`new`/`send`),
  shared mutable state that `compiler_structure.feature` rules out for a
  stage.
- Each language construct compiles to a call of a runtime function that
  implements it (`op_add`, `send`, `rt_member`, `rt_on`, `class_define`,
  `rt_list_alloc`, `rt_retain`/`rt_release`, ...). These are the
  construct's protocol, not ownership facts: the compiler holds no fact
  about any function's ownership, which the ownership stage derives the
  same way for all.

## 8. Baseline

The interpreter, 2026-11-02, against Part 1: 32 passed, 10 failed. The
failures are what Part 1 adds or changes: bool arrays; `new` returning an
object; operator methods and `raises`; int's operator events and the
re-entrancy rule; identity equality for unnamed objects; and the bool
array memory loop. `exec` grew from 10 to 11 MB between 20 and 200 runs,
to be rechecked at larger counts.
