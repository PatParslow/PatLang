# The native PatLang interpreter

PatLang has one language and two ways to run it: interpret it, or compile it
to x64. Today those two ways share nothing before the AST and nothing at run
time. `pat --ir-run` is a Rust lexer, parser, lowerer, stack VM and host
library; `patc1 --x64` is the self-hosted front end, the block lowerer and
`x64_runtime.patlang`. Every difference between them is a bug against one
spec, and the two-toolchain arrangement keeps producing them.

This plan replaces `pat --ir-run` with `pati`: the compiler's own front end
(`lexer.patlang`, `parser.patlang`, `block_model/lower.patlang`) feeding the
block interpreter (`block_model/interp.patlang`), compiled with
`patc1 --x64`, running on `x64_runtime.patlang`. Interpreted and compiled
programs then share the parser, the lowering, the numeric tower, the
strings, the lists and every host function. The Rust interpreter is kept
only for the Gen A bootstrap.

## Starting point (measured 2026-10-31)

A probe driver (lex, parse, `bm_lower_program`, `bi_run`) compiled with
`patc1 --x64` in 5 min 51 s to a 3.4 MB executable, and runs a small program
(functions, loop, lists, rationals, floats) with output identical to
`pat --ir-run`, starting in 0.1 s.

Run over every fixture in `block_model/spec_fixtures/` and
`self_hosting/examples/` that does not need native-only memory primitives,
argv, sockets or stdin (267 files), compared with `pat --ir-run --quiet`:

| Result | Files | Cause |
|---|---|---|
| identical | 52 | |
| include not expanded | 119 | the probe driver does not run `expand_includes_native` / `expand_syntax_dsls` |
| unknown Bin op | 5 | `band`, `shl` (and `bor`, `bxor`, `shr`) missing from the block interpreter |
| host function missing | about 20 | `interp_call_host` is a hand-written chain of about 106 names; the lowerer emits runtime names (`rt_bigint_from_i64`, `rt_print_i64`, `fiber_new`, `os_exit`, ...) it does not list |
| segfault | 23 | not yet examined |
| timeout (60 s) | 2 | not yet examined |
| parse `Err` statement | 3 | self-hosted parser rejects what the Rust parser accepts |
| output differs | about 12 | truthiness, `substr` on non-ASCII text, `type_of` of a named object, GOAP plans, and several `native_*` fixtures the Rust interpreter cannot run at all |

## Rules

- One spec. Where `pati`, `--x64` and the Rust interpreter disagree, the
  language spec decides; where the spec is silent, a scenario is added first
  (RED), then whichever pathway is wrong is fixed.
- The Rust interpreter is not the reference. Matching it is evidence, not
  the goal.
- Shared tables, never parallel copies: an operator, opcode, or host
  function is defined once and used by both pathways.

## Phases

### 0. The driver in the repo

`self_hosting/block_model/pati_main.patlang`: read the file, run the same
include and syntax-DSL expansion `patc1` runs, tokenize, parse, report parse
errors with `format_parse_error`, lower, run. The program sees its own
arguments through `argv()`, its exit code is its own, and interpreter errors
go to stderr. A build script, `self_hosting/block_model/tools/build_pati.sh`,
and a corpus tool that writes one line per file to a log as it goes
(CLAUDE.md section 8). Fixture and scenario in `native_codegen.feature`.

### 1. One operator table

The block interpreter (`bi_run_block`) and `native_codegen.patlang`
(`bm_nc_bin_op_string`, `bm_nc_un_op_string`) each decode operator hashes.
Move the table to `block_ir.patlang` and use it from both. The interpreter
lacks the bitwise operators (`band`, `bor`, `bxor`, `shl`, `shr`, `bnot`) and
native codegen lacks `bnot`; an unknown hash already stops the native
translation through `bm_nc_unsupported`.

### 2. Function tables

One entry format for every callable: `[name, arity, kind, target]`, where
kind is native (target is a code address) or interpreted (target is the
function's entry block).

- **Runtime table.** Built with `x64_runtime`: every runtime function's
  name, arity and address, hashed by name. A generic call-by-address
  primitive with N arguments (generalising `os_call_bridge`) calls an entry.
  `CallHost` in the interpreter goes through this table, so `pati` has
  exactly the host functions compiled programs have, by construction, and
  `interp_call_host`'s name chain goes.
- **User table.** Filled when `pati` loads a program, one entry per user
  function. A call site resolves its callee to a slot once and calls
  through the slot. A later JIT compiles a hot function and changes its
  slot from interpreted to native; call sites pick that up on their next
  call without being rewritten.
- **Compiled programs** already keep a user table, the apply table used by
  `apply`, `fiber_new`, `parallel_map` and `budgeted_run`. It moves to the
  same format, and `resolve_func_addr`'s linear name scan becomes a hashed
  lookup. Native code, interpreted code and a future JIT then call each
  other through one mechanism, and dispatch by name stops being a separate
  path (CLAUDE.md section 9's registry becomes the table itself).
- **One hash table primitive** serves these tables, `__vars`/namespace
  lookup (`rt_ns_get`/`rt_ns_set`, linear today), and the switch that
  `if`/`elif` chains testing one value against literals lower to, in both
  pathways, with the parser building flat chains (GitHub #231).

### 3. Coverage

Work through the corpus by category, then run the language spec suite
(180 scenarios), the block-model spec suite (222) and the 38 raytrace
chapters under `pati`. Each fix lands with a scenario. The segfaults and
timeouts are examined individually.

### 4. Speed

The block interpreter keeps locals as lists of `[name, value]` pairs and
finds blocks by scanning. Resolve locals to slot indices and blocks to
indices once per block, as the Rust interpreter's precompute does, then
benchmark against `pat --ir-run` at several input sizes (CLAUDE.md
performance rule) on the shape, rational and raytrace benches.

### 5. Switch over

The spec runners and tools run under `pati`; CLAUDE.md and the
patlang-development skill name `pati` as the everyday interpreter and
`pat --ir-run` as bootstrap-only.

### 6. On the one runtime

With both pathways on `x64_runtime`, the remaining consistency work is done
once:

- **Integers.** One user-visible `int` kind: `numeric_kind` and `type_of`
  report `int` for every integer; fixnum and bignum are runtime
  representations (decided 2026-10-31). `bitwise_operators.feature`'s
  "promotes to bigint" scenario changes accordingly.
- **The numeric tower.** Review each operation's result kind against the
  spec, with a scenario per interface (`native-x64-numeric-system.md`
  section 6).
- **Freeing objects.** Objects, closures, BigInt, Complex and Interval
  blocks are allocated with `rt_heap_alloc` and never freed. Named objects
  live in a name table that only grows. How cycles are handled is still to
  be decided.

### 7. Later

- `patc1` compiling itself to x64, which removes rustc from Gen B.
- A JIT using the user function table.
