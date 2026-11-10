# v2's IR and the readers that build from it

`docs/spec/values-and-memory.md` 2.6 refers here. v2 writes a program as IR, and a **reader**
builds an executable from that IR. The reader is a small program written in another language, so
PatLang can be built on a machine that has nothing of PatLang's own yet (GitHub #247).

## Writing the IR

```
v2.exe SRC.patlang OUT.ir --ir
```

This writes every function the program can reach, the runtime's included, after the ownership
stage. It writes no executable. The program's IR is the same for every build of the same source.

## The text form

The IR is UTF-8 text with lines separated by LF.

- **Line 1** is `v2-ir 1`.
- **Line 2** is `plus_events 0` or `plus_events 1`. It is 1 when some `when` handles int's `added`
  or `added_to` events (spec 1.4).
- **Each further line** is one function, in the order the compiler builds them:

  ```
  ["Fn" NAME NPARAMS NSLOTS [INSTR ...] [VARS ...]]
  ```

Values are written in a small notation:

| Value | Written as |
|---|---|
| An int | Decimal, with `-` before a negative one. It may be wider than 64 bits. |
| A string | Between `"` characters. Any byte of its UTF-8 form outside 32 to 126, and any `"` or `\`, is written as `\` and two lowercase hex digits. |
| A list | `[`, its values separated by one space, then `]`. |

Nothing else appears.

## What a function means

A function has `NPARAMS` parameters and `NSLOTS` slots. The parameters are slots `0` to
`NPARAMS-1`. Every slot holds one value of two words (spec 2.1): a **type word** and a **data
word**. The ownership stage has already run, so a reader counts nothing on its own. It does exactly
what the instructions say.

### Type words

- The low 32 bits of the type word are the class:

  | Class | Number |
  |---|---:|
  | `unit` | 0 |
  | `bool` | 1 |
  | `int` | 2 |
  | `float` | 3 |
  | `string` | 8 |

  Classes 0 to 15 are the runtime's own (spec 1.1): `unit`, `bool`, `int`, `float`, `bigint`,
  `rational`, `complex`, `interval`, `string`, `list`, `closure`, `string_builder`, `vec`,
  `bool_array`, `rule_store` and `modint`, in that order. A class a program declares is 63 or more.
- Bit 32 is the heap bit. When it is set, the data word points to a heap block whose first word
  is its reference count.

### Instructions

Slots are named `d` (the slot written), `a`, `b` and `s` below.

| Instruction | Meaning |
|---|---|
| `["const" d KIND TEXT]` | `KIND` is `int`, `float`, `bool`, `unit` or `str`. `int`: class 2, the data word `TEXT`. `bool`: class 1, data 0 or 1. `unit`: class 0, data 0. `float`: class 3, data the IEEE bits of `TEXT`. `str`: type word 8, data the address of a block laid out as four words `0, 0, BYTES, CHARS` and then the UTF-8 bytes. With the heap bit clear, it is never counted. |
| `["copy" d s]` | `d` becomes `s`'s two words. |
| `["move" d s]` | As `copy`, and then `s`'s type word becomes 0. |
| `["clear" s]` | `s`'s type word becomes 0. |
| `["call" d NAME [s ...]]` | Calls the function `NAME`, and its result goes to `d`. |
| `["callv" d [c s ...]]` | Calls the closure in `c`, passing `c` and then each `s`. The code address is the word at `c`'s data word + 16. |
| `["op" d OP a b]` | See the table of operators below. |
| `["un" d OP a]` | `-` on an int is negation; on overflow, or on any other class, it calls `op_neg`. `bnot` on an int is the bitwise not; otherwise it calls `op_bnot`. `not` on a bool flips the data word; otherwise it calls `op_not`. |
| `["prim" d NAME [s ...]]` | See the table of primitives below. |
| `["extern" d LIB FUNC [s ...]]` | Calls `LIB!FUNC` by the Windows x64 convention. The arguments are the slots' data words, and the result is an int holding `rax`. |
| `["externf" d LIB FUNC [s ...]]` | As `extern`, but the arguments go in `xmm0` to `xmm3`, and the result is an int holding `xmm0`'s bits. |
| `["label" N]`, `["jump" N]` | A label numbered within the function, and a jump to it. |
| `["branch" s T F]` | Goes to `T` when `s` is true and to `F` otherwise. A value of class 2 or lower is true when its data word is non-zero. Any other value goes to `rt_truthy`, and the result's data word decides. |
| `["return" s]` | Returns `s`. |
| `["retain" s]` | When `s`'s heap bit is set, adds 1 to the count atomically. If the count before was below 1, calls `rt_fail_released_twice()`. |
| `["release" s]` | When `s`'s heap bit is set, subtracts 1 atomically. If the count before was 1 or less, calls `rt_release_last(type, block, count_before)`, each argument as an int. |
| `["list" d [s ...]]` | `d` = `rt_list_alloc(n)`. Then for each `k`: retain the `k`th slot, and store its two words at the block + 32 + 16k. |
| `["closure" d FN [s ...]]` | `d` = `rt_closure_alloc(n)`, with `FN`'s code address stored at the block + 16. The captured slots are stored as for `list`. |

#### Operators

For two ints, these are computed inline, and the runtime function is not called. The runtime is
compiled from this same IR, and its own operator functions use these operators on ints.

| Operator | Inline for two ints | Otherwise calls |
|---|---|---|
| `+` | The machine add. | `op_add` |
| `q+` | The machine add. | `op_add_quiet` |
| `a+` | The machine add. | `op_add_taken` |
| `-` | The machine subtract. | `op_sub` |
| `*` | The machine multiply. | `op_mul` |
| `<` `>` `<=` `>=` `==` `!=` | A comparison giving a bool. | `op_lt` `op_gt` `op_le` `op_ge` `op_eq` `op_ne` |
| `band` `bor` `bxor` | The machine and, or and xor. | `op_band` `op_bor` `op_bxor` |
| `shl`, `shr` | Left shift, and arithmetic right shift. | `op_shl` `op_shr` |
| `%` | The machine remainder. | `op_mod` |
| `/` | Never inline. | `op_div` |

The runtime function is called in these cases as well:

- `+`, `-` or `*` overflows 64 bits;
- `%` has a zero divisor;
- the operator is `+` or `a+`, `plus_events` is 1, and the word at the runtime state + 2064 is
  non-zero.

#### Primitives

A word result is an int.

| Primitive | Result |
|---|---|
| `value_class` | The type word's low 32 bits. |
| `value_data` | The data word. |
| `value_type_word` | The whole type word. |
| `value_make(t, d)` | The value whose type word is `t`'s data and whose data word is `d`'s data. |
| `value_live` | A bool, true when all of these hold: no type-word bit above 33 is set; the class is 15 or less, or 63 or more; and if the heap bit is set, the block's count is at least 1. |
| `runtime_state` | The address of the 65,536 zeroed bytes of the runtime's state. |
| `thread_entry_address` | The address of the thread entry (see below). |
| `atomic_add(p, n)` | A locked exchange-add at `p`, giving the value before. |
| `mem_load(p, o)`, `mem_load_byte(p, o)` | The word at `p+o`, and the byte at `p+o` zero-extended. |
| `mem_store(p, o, v)`, `mem_store_byte(p, o, v)` | Store a word or a byte at `p+o`, giving unit. |
| `mem_load_value(p, o)` | The two words at `p+o`, retained. |
| `mem_take_value(p, o)` | The two words at `p+o`, which then become 0. |
| `mem_init_value(p, o, v)` | Retains `v` and stores it at `p+o`, giving unit. |
| `mem_store_value(p, o, v)` | Retains `v`, releases the value it replaces, and stores `v` at `p+o`, giving unit. |
| `word_add` `word_sub` `word_mul` `word_and` `word_or` `word_xor` | The machine operations on the data words. |
| `word_shl`, `word_shr` | Shifts; `word_shr` is a logical shift. |
| `word_div`, `word_rem` | Signed. |
| `int_to_float`, `float_to_int` | The float conversions on the bits, truncating towards zero. |
| `float_add` `float_sub` `float_mul` `float_div` | IEEE double arithmetic on the bits. |
| `float_lt` | A 0 or 1 int, ordered. |
| `float_eq` | A 0 or 1 int, ordered. |

## The executable

- **Arguments and results.** Arguments are passed on the stack. Before the call, the caller pushes
  each argument's data word and then its type word, from the last argument to the first. After
  the call it removes them. Inside the function, parameter `i`'s type word is at `[rbp+16+16i]`
  and its data word at `[rbp+24+16i]`. A function returns its result's type word in `rax` and its
  data word in `rdx`. Only the instructions above call functions, so a reader may use any frame
  layout of its own.
- **The entry** calls `runtime_init()` and then `__main()`, and then exits the process with code 0.
- **The thread entry** is given by `thread_entry_address`. It receives a job in `rcx` by the
  Windows convention, calls `rt_thread_main(job)` with the job as an int, and returns 0.
- **The file.** A Windows reader writes a PE32+ console executable that imports each `LIB!FUNC` by
  name. It also imports `KERNEL32.DLL!ExitProcess`. The stack reserve is 256 MB, committed a page
  at a time, and a frame longer than a page touches each page on the way down.

## The first reader

`bootstrap/ir_reader.py` is written in Python 3, using only its standard library:

```
py -3 bootstrap/ir_reader.py IN.ir OUT.exe
```

It builds an x64 Windows executable. It builds the compiler from the compiler's own IR. That
compiler builds the compiler, and the result builds it again. The last two builds are byte
identical, and `self_hosting/v2/tools/gates.sh` checks this.

## The WASM form

```
v2.exe SRC.patlang OUT.wasm --wasm
py -3 bootstrap/ir_wasm.py IN.ir OUT.wasm
```

`self_hosting/v2/wasm.patlang` builds a WebAssembly module from the IR, and
`bootstrap/ir_wasm.py` builds the same module, byte for byte, from the IR's text form. The module
uses multiple results, bulk memory and threads (shared memory and atomics), which current browsers
and Node have.

### The memory

The module imports `env.memory`, a shared memory with a maximum of 65,536 pages, from the host.
Every executor (see below) instantiates the module over the same memory.

| Address | What is there |
|---|---|
| 4096 to 65,535 | What the host writes: the command line, as a C string at 4096. |
| 65,536 | The runtime's state, the 65,536 bytes `runtime_state` gives. |
| 131,072 | The string constants, laid out as for `const`, one after another at 8-byte boundaries. |
| From the first page after the module's initial pages | The heap: the runtime reserves it with `VirtualAlloc`, and the host grows the memory as the runtime commits it. |

The constants are a passive data segment. The export `init_memory` copies them into place, and
the main executor calls it once, before anything else runs.

### Functions

- **Slots.** Each slot is held in a pair of locals: in pair `p`, the type word is local `2p` and
  the data word is local `2p+1`. Parameter `k` is pair `k`, so a function of `n` parameters takes
  `2n` i64 parameters. Every function returns two i64 results, the type word first.
- **Sharing pairs.** Slots that are never live at the same time share a pair, so a function's
  locals grow with how many slots are live at once, not with its length. A slot's range runs
  from the first to the last instruction at which it is live or named. Liveness is over basic
  blocks, a new one at each label and after each jump, branch or return, and a slot live where
  the function begins ranges from its first instruction. Going through the instructions in
  order, the slots whose ranges begin at one each take the pair last given back, or a new pair,
  in slot order. Then the slots whose ranges end there give their pairs back, in slot order. Both
  writers do this the same way, so that their modules are the same bytes. A slot the ownership
  stage holds until a return (a named variable, or a temporary that a branch reads) is live
  from the start to the last return, so it keeps a pair of its own.
- **Scratch locals.** After the pairs come one i32 local, an address, and one i64.
- **Addresses.** A data word used as an address is wrapped to 32 bits.
- **Counts.** `retain`, `release` and `atomic_add` use `i64.atomic.rmw.add`.
- **Code addresses.** The table holds every function, in IR order, and then the thread entry. A
  function's code address is its table index. `closure` stores it, and `callv` calls through it
  with `call_indirect`.
- **The thread entry** is a function `(i64 job) -> i64` that calls `rt_thread_main(job)` and gives 0.
- **Externs.** Each `LIB!FUNC` is an import with module `LIB` and name `FUNC`. Its parameters and
  result are i64 for `extern`, and f64 for `externf`.
- **Exports.** The module exports `main`, `thread_entry`, `init_memory` and `table`. `main` calls
  `runtime_init()` and `__main()`, and then `KERNEL32.DLL!ExitProcess(0)`.
- **Names.** A name section gives each function its IR name.

The operators, primitives and counts mean what the tables above say. Three cases are written out:

- `float_to_int` gives the minimum int when its argument is NaN or out of range, as x64's
  conversion does.
- `float_eq` is ordered, so NaN is equal to nothing.
- `%` of the minimum int by -1 gives 0.

### Control flow

The code before a function's first label, and the code after each label, are its segments. They
are laid out as nested loops and blocks:

- **A jump back** is a `br` to a `loop`. The loop begins at the target segment and ends after the
  last segment that jumps back to it.
- **A jump forward** is a `br` to a `block`. The block ends just before the target segment and
  begins in the first segment that jumps there.
- **Falling through.** A jump or branch arm to the next segment falls through, when it is its
  segment's last instruction.
- **Making them nest.** Where two of these cross, a loop's end moves later or a block's start moves
  earlier, until all nest.

A block that begins before a loop and ends inside it cannot nest. Such a block would come from a
jump into a loop at a segment other than its first, which v2's lowering never makes. A writer
stops with an error naming the function.

## The WASM host

`self_hosting/v2/wasm/` runs a module, in a browser or in Node:

```
node self_hosting/v2/wasm/run_node.mjs PROGRAM.wasm [ARGS...]
py -3 self_hosting/v2/wasm/run_browser.py PROGRAM.wasm [ARGS...]
```

`run_browser.py` serves the page and the program from 127.0.0.1, with the headers that make the
page cross-origin isolated, which `SharedArrayBuffer` needs. It runs the page in a headless Chrome,
which posts back the output and the exit code. A page of your own can serve `index.html`,
`page.mjs`, `launcher.mjs`, `executor.mjs` and `layout.mjs` in the same way, with
`?wasm=URL&args=[...]`.

- **Executors.** The launcher (`launcher.mjs`) never runs the program, so it can stay on a
  browser's main thread, which may not block. The program runs on executors (`executor.mjs`),
  each a Worker:
  - the main executor runs `main`;
  - `CreateThread` makes an executor that calls the thread entry;
  - `CreateFiber` makes one that waits until it is switched to.
- **Starting an executor.** An executor gives the new executor's handle back at once, and asks the
  launcher to start its Worker. It never waits for that Worker to start, so it works where a
  Worker cannot make Workers of its own.
- **The control block.** The executors share a `SharedArrayBuffer` with the launcher. It holds
  each executor's gate and thread, each thread's finished flag and TLS slots, and the output
  buffer's lock.
- **Fibres.** `SwitchToFiber` clears the switching executor's gate, gives the target its own
  thread, opens the target's gate, and waits on its own. One executor of a thread runs at a time.
  `TlsGetValue` and `TlsSetValue` use the slots of the executor's thread at the moment. So a fibre
  uses the per-thread context of whichever thread resumed it, as on Windows.
- **The cost of a fibre.** A fibre costs a Worker. Starting one takes milliseconds, against
  microseconds natively, and so does each `budgeted` block, which runs on a fibre.
- **Output.** `WriteFile` to the standard output appends to the shared buffer under its lock.
  Output therefore keeps the order in which the threads wrote it, and the launcher writes it out.
- **The exit.** `ExitProcess` records the exit code. The launcher then writes the remaining output
  and stops every Worker. A trap in any executor gives exit code 101, after a line naming the trap.
- **What a browser has none of.** There are no files, processes or sockets, so each of those calls
  fails as Windows reports a file that is not there. `GetEnvironmentVariableA` finds only what the
  launcher is given, which by default is nothing, and the standard input is empty.
