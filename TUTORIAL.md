# Getting Started with PatLang

This tutorial covers the **working** PatLang system: the Rust Stage 0 runtime
(`rust-runtime/`) and the self-hosted compiler front-end (`self_hosting/`).
Everything shown here runs today — each section's examples are exercised by
the test suite.

## 1. Build the runtime

You need a Rust toolchain (`rustc`/`cargo`).

```bash
cd rust-runtime
cargo build
```

This produces `rust-runtime/target/debug/pat` (`pat.exe` on Windows) — the
PatLang runner and compiler driver. The examples below assume you run from the
repository root; alias it if you like:

```bash
alias pat=./rust-runtime/target/debug/pat
```

## 2. Your first program

Create `hello.patlang`:

```patlang
let name = "world"
print("hello, " + name)
```

Run it with the IR interpreter (the recommended mode):

```bash
pat --ir-run hello.patlang
```

Compile it to a native executable:

```bash
pat --patc hello.patlang --out hello.exe
./hello.exe
```

Or use the PatLang-hosted compiler driver:

```bash
pat ./patc.patlang hello.patlang --out hello.exe
```

`--compare` runs both the interpreter and the compiled binary and checks the
outputs match:

```bash
pat --compare hello.patlang
```

## 3. Language tour

### Variables and expressions

```patlang
let x = 10
let y = x * 3 + 2          # numbers are 64-bit floats
let s = "value: " + y      # + concatenates when either side is a string
let ok = (x < 20) and (y != 0)
print(s)
```

Operators: `+ - * / %`, comparisons `== != < <= > >=` (strings compare
lexicographically), boolean `and` / `or` / `not`, unary `-`. Statements are
separated by newlines or `;`. Comments start with `#`.

### Control flow

```patlang
if x >= 10 then
  print("big")
else
  print("small")
end

let i = 0
while i < 3 do
  print(i)
  let i = i + 1        # rebinding uses let again
end
```

### Functions

```patlang
make a function called fib takes n returns r
  if n < 2 then
    return n
  else
    return fib(n - 1) + fib(n - 2)
  end
end

print(fib(10))          # 55 — recursion and forward references both work
```

### Lists and strings

```patlang
let xs = [1, 2, 3, 4]
print(xs.length)         # 4
print(xs[2])             # 3 (indexing is zero-based)
let xs = list_push(xs, 5)     # lists are values; push returns a new list
let xs = list_set(xs, 0, 99)  # replace an element

let s = "hello"
print(s[0])              # "h" — indexing a string yields a 1-char string
print(char_code(s, 0))   # 104 — numeric code, handy for character classes
print(substr(s, 1, 3))   # "ell"
print(chr(10))           # 1-char string from a code (here: newline)
```

### Splitting code across files

`include "relative/path.patlang"` splices another file in place (resolved
relative to the including file):

```patlang
include "lib/helpers.patlang"
print(helper_fn(41))
```

## 4. The paradigms

These all compile to native code. The complete program combining them is
`self_hosting/examples/feature_demo.patlang`.

### Event-driven

```patlang
when greeting do
  print("event received: " + event_data)
end

emit("greeting", "hello events")
```

Handlers registered with `when` run whenever `emit(event, payload)` fires;
inside a handler, `event_name` and `event_data` are bound.

### Logic / goal-oriented

```patlang
fact("parent", "alice", "bob")
fact("parent", "alice", "carol")
print(query("parent", "alice", 0))   # 2 — counts matching facts
goal("reunite", "alice")             # records a pending goal
```

### Object-oriented

```patlang
new("Person", "kim")            # create object "kim" of class Person
send("kim", "set", "age", 42)   # message send: set a property
print(get("kim", "age"))        # 42
```

### Functional

Functions are referenced by name and invoked with `apply`, which lets you
write higher-order code in PatLang itself:

```patlang
make a function called double takes x returns r
  return x * 2
end

make a function called map_list takes xs, fname returns out
  let out = []
  let i = 0
  while i < xs.length do
    let out = list_push(out, apply(fname, xs[i]))
    let i = i + 1
  end
  return out
end

print(map_list([1, 2, 3], "double"))   # [2, 4, 6]
```

### Networking

Blocking TCP built-ins: `tcp_listen(port)` (0 = OS-assigned; returns the
actual port), `tcp_accept(port)`, `tcp_read(conn)`, `tcp_write(conn, data)`,
`tcp_close(conn)`. A complete HTTP echo server is
`self_hosting/examples/echo_server.patlang` — compile it and hit it with curl:

```bash
pat --ir-run self_hosting/pipeline_stage2.patlang   # or compile echo_server directly
```

### Files

`read_file(path)` returns a file's contents as a string.

## 5. The self-hosting pipeline

PatLang's compiler is written in PatLang, end to end:

| Component | File | Written in |
|-----------|------|-----------|
| Lexer | `self_hosting/lib/lexer.patlang` | PatLang |
| Parser | `self_hosting/lib/parser.patlang` | PatLang |
| Lowerer (AST → IR) | `self_hosting/lib/lower.patlang` | PatLang |
| Codegen (IR → Rust source text) | `self_hosting/lib/codegen.patlang` | PatLang |
| Runtime prelude text + "write file, run rustc" | `rust-runtime/src/ir/` | Rust (Stage 0 host) |

Watch the whole thing run — PatLang code tokenizes, parses, lowers, and
generates ~78 KB of Rust source for a PatLang program; the host contributes
only the fixed runtime prelude string (`codegen_prelude()`) and the dumbest
possible back end (`rustc_build(source, out)`):

```bash
pat --ir-run self_hosting/pipeline_stage4.patlang
./selfhost_stage4_demo.exe
```

The interchange formats are plain lists, easy to inspect:

- Token: `["IDENT", "let", 1]` — type, text, line
- AST node: `["Bin", "+", ["Var", "x"], ["Num", "1"]]`
- IR instruction: `["CallHost", "print", 1]`
- Codegen output: a Rust source string, e.g. `body.push(Instr::CallHost("print".to_string(), 1));`

`pipeline_stage1.patlang` through `pipeline_stage3.patlang` show the earlier
stages, where the host still did lowering (`compile_shape`) or IR decoding
(`compile_ir`). Each stage produces byte-identical program output, verified by
`rust-runtime/tests/selfhost_pipeline.rs`.

### The fixpoint: the compiler compiles itself

PatLang is self-hosting in the strict sense — a natively compiled PatLang
compiler compiles its own source, and the child compiler is byte-for-byte
equivalent to its parent:

```bash
# Generation A: the interpreter runs the PatLang compiler on the compiler's
# own source, producing a native binary (~4 min — interpreted compilation)
pat --ir-run self_hosting/build_patc1.patlang        # -> ./patc1.exe

# Generation B: the native compiler compiles a program (~3.5 s)
./patc1.exe self_hosting/examples/feature_demo.patlang demo.exe
./demo.exe

# Generation C: the native compiler compiles ITSELF
./patc1.exe self_hosting/build/patc1_all.patlang patc2.exe
./patc2.exe self_hosting/examples/feature_demo.patlang demo2.exe
# demo.exe and demo2.exe produce identical output, and patc1/patc2 emit
# byte-identical Rust for the same input
```

`patc1` usage: `patc1 <input.patlang> <output-exe> [prelude.rs]`. It reads the
runtime prelude from `self_hosting/runtime/prelude.rs` (relative to the
working directory), so run it from the repo root or pass the path explicitly.

Two fixed artifacts remain outside PatLang, both deliberate:

- **The runtime prelude** (`self_hosting/runtime/prelude.rs`) — the runtime
  library text embedded in every emitted program, analogous to a libc.
  Regenerate it after changing the host template:
  `pat --ir-run self_hosting/tools/dump_prelude.patlang`.
- **rustc** — the machine-code back end, used the way other compilers use
  LLVM.

The full bootstrap is exercised by the (slow, `#[ignore]`d) test:
`cargo test --test selfhost_pipeline -- --ignored`.

## 6. Debugging tips

- `PATLANG_DEBUG=1` enables evaluator/parser debug logs.
- `pat --emit-rust file.patlang` prints the generated Rust for a program —
  useful when a compiled binary misbehaves.
- `pat --compare file.patlang` catches interpreter/compiled divergence.
- The test suite is the ground truth: `cd rust-runtime && cargo test`.

## 7. Current limitations

- The self-hosted (Stage 1) dialect has no string escape sequences yet — use
  `chr(code)` to build special characters (`chr(10)` = newline).
- `and` / `or` do not short-circuit in code compiled through the Stage 1
  pipeline (both operands evaluate).
- Objects, facts, and event handlers live in per-thread state.
- Functions are not yet first-class closures; use `apply(name, ...)`.
- Networking is blocking; the async/event-loop model is on the roadmap
  (`PATLANG_SELF_HOSTING_ROADMAP.md`).
