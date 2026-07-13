# Getting Started with PatLang

This tutorial covers the **working** PatLang system: the Rust Stage 0 runtime
(`rust-runtime/`) and the self-hosted compiler front-end (`self_hosting/`).
Everything shown here runs today — each section's examples are exercised by
the test suite.

## 1. Build the runtime

You need a Rust toolchain (`rustc`/`cargo`) for this one step only. This is
the bootstrap: it builds the `pat` binary once, from `rust-runtime/` source.

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

After this one-time build, `rustc` is no longer required for normal PatLang
development. `pat --ir-run <file>` — the form used throughout this tutorial —
lexes, parses, lowers, and executes a program directly on the VM (the same
`run_ir` mechanism the in-browser playground uses), with zero further calls to
`rustc`. The Rust toolchain only comes back into play if you deliberately ask
for a standalone native/WASM binary (`pat --patc`, or a tool that calls
`rustc_build`, like the portfolio builder or `patbuild --native`) — that's an
opt-in, occasional step, not part of the everyday edit-run loop.

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

Bitwise operators are word-form keywords, not C-style symbols: `|` and `&`
are already taken (the `|>` pipeline operator, `|params|` closure syntax),
and PatLang already spells `and`/`or`/`not` as words rather than
`&&`/`||`/`!`, so this follows that convention instead of importing symbols
that don't fit.

```patlang
let flags = 0
let flags = flags band bnot 4     # clear bit 2
let flags = flags bor (1 shl 5)   # set bit 5
print(bit_get(flags, 5))          # 1
```

`band`/`bor`/`bxor`/`bnot`/`shl`/`shr` operate on integers only. `shl`/`shr`
bind tighter than `+`/`-` but looser than `*`/`/`/`%`; `band`/`bxor`/`bor`
share a single combined precedence tier (parenthesize mixed expressions if
a specific grouping matters). Four bitfield helpers give packed-integer
field access without a struct/type system: `bit_get(n, pos)`,
`bit_set(n, pos, val)`, `bit_slice(n, start, width)`,
`bit_set_slice(n, start, width, val)`. See
`self_hosting/examples/bitwise_bitfield_demo.patlang`.

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

The original `fact`/`query`/`goal` trio is a flat, count-only lookup table
kept for backward compatibility. The real paradigm is two genuine engines
underneath, plus design-by-contract feeding into both:

**Backward chaining** (`rule_add`/`solve`) — real SLD-style resolution
with backtracking, not a lookup. A ground fact is just a rule with an
empty body (the standard Prolog trick), so any arity is supported:

```patlang
fact("parent", "alice", "bob")
fact("parent", "alice", "carol")
print(query("parent", "alice", 0))   # 2 — counts matching facts (legacy trio)
goal("reunite", "alice")             # records a pending goal (legacy trio, unread)

# rule_add/solve: the real thing. A rule with an empty body is a fact.
rule_add("dep", ["a", "b"], [])
rule_add("dep", ["b", "c"], [])
rule_add("unchanged", ["c"], [])
rule_add("buildable", ["X"], [["unchanged", ["X"]]])
rule_add("buildable", ["X"], [["dep", ["X", "Y"]], ["buildable", ["Y"]]])
let sols = solve("buildable", ["a"])   # [["a"]] -- resolves through a->b->c
```

Real declarative syntax exists too, as pure sugar over the same
`rule_add`/`solve` calls above:

```patlang
rule dep(a, b).
rule dep(b, c).
rule unchanged(c).
rule buildable(X) :- unchanged(X).
rule buildable(X) :- dep(X, Y), buildable(Y).
let sols = solve("buildable", ["a"])
```

**GOAP planning** (`action_add`/`plan`) — forward search over actions with
preconditions/effects/cost, producing a real cost-optimal ordered plan
(not just the first path that works):

```patlang
action_add("compile_b", [], [["compiled", ["b"]]], [], 5)
action_add("compile_a", [["compiled", ["b"]]], [["compiled", ["a"]]], [], 3)
action_add("link", [["compiled", ["a"]], ["compiled", ["b"]]], [["shipped", []]], [], 2)
let build_plan = plan([["shipped", []]])   # ["compile_b", "compile_a", "link"]
```

Actions can be parameterized too, using the same `^[A-Z]` variable
convention as `rule_add`/`solve` — one action template grounds into a
separate instantiation per matching fact, instead of needing a
hand-written action per target:

```patlang
rule_add("ready", ["target_a"], [])
rule_add("ready", ["target_b"], [])
action_add("build", [["ready", ["X"]]], [["built", ["X"]]], [], 1)
let build_plan = plan([["built", ["target_a"]], ["built", ["target_b"]]])
# ["build(X=target_a)", "build(X=target_b)"] -- one instantiation per target
```

A successful `require`/`ensure`/`assert` check also asserts a
`contract_holds` fact automatically, so verified contracts become
ordinary derivable data usable as a rule-body conjunct or GOAP
precondition. See `self_hosting/examples/goal_oriented_build_demo.patlang`
and `self_hosting/examples/rule_syntax_demo.patlang`.

Deliberately not (yet) real: `goal name { ... }` block syntax still
silently no-ops — unlike `rule`, there's no unambiguous mapping onto
`solve`/`plan` (named query? GOAP action? imperative body?).

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

`apply` calls a function *by name*; real closures — anonymous functions that
capture surrounding variables — also exist:

```patlang
make a function called make_adder takes n returns r
  return |x| { return x + n }     # captures n from the enclosing call
end

let add_three = make_adder(3)
print(add_three(7))               # 10

let inc = |x| { return x + 1 }
make a function called twice takes f, x returns r
  return f(f(x))                  # calling a closure held in a variable
end
print(twice(inc, 10))             # 12
```

Captured variables are snapshotted **by value** at the moment the closure is
created — reassigning the outer variable afterwards does not change what an
already-created closure sees, consistent with this language's value
semantics everywhere else (`list_push` returning a new list rather than
mutating in place, etc). Closures can be returned from functions, stored in
variables, passed as arguments, and nested (a closure can itself return a
closure that captures the outer one's variables).

The self-hosted (Stage 1) dialect uses `|params| do ... end` instead of
Stage 0's `|params| { ... }`, matching the rest of Stage 1's keyword-based
block syntax (which has no brace-delimited blocks anywhere); it also only
supports calling a closure through a named variable, not invoking a closure
literal immediately in place (`(|x| { ... })(5)` — that works in Stage 0,
not yet in the self-hosted compiler).

### Networking

Blocking TCP built-ins: `tcp_listen(port)` (0 = OS-assigned; returns the
actual port; binds `127.0.0.1` only, not configurable), `tcp_accept(port)`,
`tcp_read(conn)`, `tcp_write(conn, data)`, `tcp_close(conn)`. A complete HTTP
echo server is `self_hosting/examples/echo_server.patlang` — compile it and
hit it with curl:

```bash
pat --ir-run self_hosting/pipeline_stage2.patlang   # or compile echo_server directly
```

`tcp_try_listen(port)` is a non-panicking sibling of `tcp_listen`: returns
`-1` specifically if the port is already bound elsewhere, instead of
`tcp_listen`'s fatal-on-any-bind-failure behavior. PatLang has no
try/catch, so there was no other way for a program to gracefully ask "is
something already listening here" — any other bind failure (invalid port,
permission denied) still fails fatally, same as plain `tcp_listen`. This is
what the runtime signals library below uses to detect whether it's the
first instance or not.

### Runtime signals

A running program can receive a named signal + optional payload from
*outside itself* — a second CLI invocation (`server.exe --quit` sent to an
already-running `server.exe`, not a new one) or a local network call —
without any new dispatch mechanism: `self_hosting/lib/signals.patlang`
builds entirely on the `when`/`emit` event system covered below, so a
signal is just another event as far as your handlers are concerned.

```patlang
include "lib/signals.patlang"

when quit do
  set_var("should_stop", "1")
end
when status do
  signal_reply("uptime: " + get("__vars", "uptime"))
end

let port_id = signal_claim(9401)
if port_id >= 0 then
  # this process is the primary -- hold the port, poll it in your loop
  while get("__vars", "should_stop") == "0" do
    # ... your own work ...
    signal_poll(port_id, 20)
  end
else
  # someone else already owns this port
  signal_send(9401, "quit", "")               # fire-and-forget
  print(signal_query(9401, "status", ""))     # request/response
end
```

Two flavors: `signal_send` (fire-and-forget, e.g. `quit`) delivers and
returns immediately without waiting for a reply; `signal_query`
(request/response, e.g. `status`) blocks until the primary's handler calls
`signal_reply(text)`, so a program can report genuine live state back to
whoever asked, not just a canned string. `signal_claim(port)` relies on
`tcp_listen` already being `127.0.0.1`-only and a second bind to the same
port simply failing — that failure IS the "a primary is already running"
detector, no separate lockfile or PID file needed (PatLang has neither).
Localhost-only by construction, so there's no auth story yet — a real
network-facing signal listener would need one before ever binding beyond
`127.0.0.1`. See `self_hosting/examples/signals_demo.patlang` for a full
worked example (run it twice, concurrently) and the [Paradigms
Guide](https://parslow.net/topics/patlang/patlang-paradigms.html#heading-signals)
for the fuller design writeup.

### Async: the event loop

Concurrency is event-driven and single-threaded, like JavaScript: a loop
turns external happenings into events, and `when` handlers consume them.
`tcp_accept_timeout(port, ms)` is the non-blocking primitive (returns -1 on
timeout), `sleep_ms(ms)` yields time, and shared state lives in the object
store via `set_var`/`get`:

```patlang
when request do
  # event_data is the connection id
  let text = tcp_read(event_data)
  tcp_write(event_data, "...")
  tcp_close(event_data)
end

when tick do
  set_var("ticks", get("__vars", "ticks") + 1)
end

set_var("ticks", 0)
let port = tcp_listen(0)
while running do
  let conn = tcp_accept_timeout(port, 50)
  if conn >= 0 then
    emit("request", conn)
  else
    emit("tick", 0)
  end
end
```

The complete program is `self_hosting/examples/event_loop_server.patlang` —
it compiles natively and serves real HTTP requests while counting idle ticks.

**`lib/event_loop.patlang`** wraps the same primitives in a reusable library
with closure callbacks instead of named events and a shared `__vars`
namespace:

```patlang
let loop = event_loop_new()
new("Stats", "stats")
send("stats", "set", "served", 0)

event_loop_on_tick(loop, || do
  print("idle")
end)

event_loop_listen(loop, tcp_listen(0), |conn| do
  let served = get("stats", "served") + 1
  send("stats", "set", "served", served)
  tcp_write(conn, "...")
  tcp_close(conn)
  if served >= 2 then
    event_loop_stop(loop)     # called from inside the callback itself
  end
end)

print("PORT: " + get(loop, "port"))
event_loop_run(loop, 50)       # blocks until event_loop_stop
```

Closures snapshot captured variables by value, so a counter that must
persist across many calls (like `served` above) lives in the object store
(a mutable cell) rather than a captured plain variable — the closure
captures the object's *name*, and mutates through it via `get`/`send`,
which is visible on every call. `self_hosting/examples/event_loop_demo.patlang`
is the full version, compiled through the self-hosted pipeline; it serves
two real requests then stops itself.

### Files

`read_file(path)` returns a file's contents as a string; `write_file`,
`file_exists`, `list_dir`, `rename_file` round out real disk I/O. These are
native-only (real `std::fs`) — not excluded from WASM builds outright, but
not reliably usable there either.

### Virtual filesystem

`vfs_read(path)` / `vfs_write(path, contents)` / `vfs_exists(path)` /
`vfs_list(prefix)` / `vfs_delete(path)` are an in-memory filesystem
available on **every** target, including WASM — deliberately different
function names from `read_file`/`write_file` rather than the same names
silently switching behavior by target.

```patlang
vfs_write("notes/todo.txt", "write the vfs demo")
print(vfs_exists("notes/todo.txt"))   # 1
print(vfs_read("notes/todo.txt"))     # write the vfs demo
```

`vfs_flush_to_disk(vfs_path_prefix, real_dir)` is the one explicit,
native-only write-through to real files — a hard error under WASM, and
gated by an allowed-root check (`PATLANG_VFS_ALLOWED_ROOT` env var,
defaulting to the current working directory) so it can't write outside a
permitted tree. See `self_hosting/examples/vfs_demo.patlang`.

## 5. Design by contract

`require EXPR` checks a precondition, `ensure EXPR` a postcondition, and
`assert EXPR` is the same primitive usable standalone anywhere (including
outside any function). All three lower to one `contract_check(func, kind,
text, ok)` call: if the condition is false, execution aborts with a message
naming the function, the kind of check, and the condition itself.

```patlang
make a function called safe_divide takes a, b returns r
  require b != 0
  let r = a / b
  ensure (r * b) == a
  return r
end

print(safe_divide(10, 2))   # 5
assert (1 + 1) == 2         # standalone check, passes silently
print(safe_divide(1, 0))    # aborts: contract violation: precondition
                             # failed in safe_divide(): b != 0
```

`ensure` is checked wherever it's written — typically right before the
value it names is returned — so functions with multiple exit paths just
repeat `ensure` before each `return` they want checked; there's no implicit
"check at every exit" magic.

This is a VM-level semantic, not a codegen concern: it works identically
whether the program is interpreted, executed via `run_ir` (no rustc — the
same path the browser playground uses), or compiled natively, because the
same `contract_check` logic is duplicated verbatim into the codegen
template. Enforcing contracts costs nothing extra at the rustc step — it's
one ordinary host call, like any other. See
`self_hosting/examples/contracts_demo.patlang` (also on the portfolio,
runnable in-browser) for a fuller example, including a recursive function
(`factorial`) with both a precondition and a postcondition.

## 6. The self-hosting pipeline

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

The runtime library embedded in every emitted program is itself PatLang
source: `self_hosting/lib/runtime_rs.patlang` emits the runtime text
(parity-checked byte-for-byte against the host template by the test suite),
so **every byte of an emitted program originates from `.patlang` files
processed by the PatLang toolchain**. After changing the host template,
regenerate with:

```bash
pat --ir-run self_hosting/tools/dump_prelude.patlang
python self_hosting/tools/transcribe_prelude.py
```

What remains outside PatLang is the irreducible bootstrap seed:

- **rustc** — the machine-code back end, used the way other compilers use
  LLVM.
- **The Stage 0 interpreter** (`pat`) — used once per fresh system for
  Generation A; after that, patc compiles patc.

The full bootstrap is exercised by the (slow, `#[ignore]`d) test:
`cargo test --test selfhost_pipeline -- --ignored`.

## 7. WebAssembly

Because the compiler emits portable Rust, targeting WASM is one argument:

```patlang
let wasm = rustc_build(rs, "./program.wasm", "wasm32-wasip1")
```

Setup (one-time): `rustup target add wasm32-wasip1`. Run the module with any
WASI runtime — with Node.js:

```js
// run_wasi.mjs
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';
import { argv, env } from 'node:process';
const wasi = new WASI({ version: 'preview1', args: argv.slice(2), env });
const wasm = await WebAssembly.compile(await readFile(argv[2]));
const instance = await WebAssembly.instantiate(wasm, wasi.getImportObject());
wasi.start(instance);
```

```bash
node --no-warnings run_wasi.mjs program.wasm
```

The feature demo (events, logic, OO, functional) runs on WASM with output
identical to native. Caveat: WASI preview1 has no sockets or subprocesses,
so the `tcp_*` hosts and `rustc_build` fail at runtime there — compute-,
event-, and file-oriented programs are the WASM sweet spot.

`rustc_build` auto-detects a `wasm` target and compiles with `-C
opt-level=z -C strip=symbols` rather than `-O` — around 7x smaller and
faster to compile, at the cost of somewhat slower *execution* inside the
WASM VM (size-optimized code, not speed-optimized). For a demo whose whole
point is running in a browser, smaller and faster-to-build wins; if you're
compiling to WASM for raw speed rather than portability/size, pass your own
target and skip `rustc_build`'s auto-detection by invoking `rustc`
directly with `-O`.

## 8. Browser GUI (HTML + JavaScript output)

`self_hosting/lib/html.patlang` builds well-formed HTML5 pages with embedded
JavaScript, making the browser PatLang's cross-platform GUI. Two patterns:

**Static page** — PatLang computes data and generates an interactive page
(`self_hosting/examples/gui_demo.patlang`):

```patlang
let page = html_page("My App", build_body(), build_script(data))
write_file("app.html", page)
```

**Live backend** — a native PatLang server serves the page, and the page's
JS `fetch`es JSON computed live by the same process
(`self_hosting/examples/gui_server_demo.patlang`):

```patlang
let port = tcp_listen(0)
# GET /      -> html_page(...) via http_ok("text/html", ...)
# GET /data  -> live JSON via http_ok("application/json", ...)
```

Tip: single quotes inside embedded JS/CSS/HTML attributes keep pages
readable (escape-free); `\"` or `q()` both give a double quote where one is
needed (e.g. JSON keys).

## 9. The portfolio

`portfolio/index.html` is a self-contained showcase: every "run in browser"
button (including the bigger examples) compiles and executes that card's
own displayed source through one shared engine — `playground.wasm`, the
self-hosted lexer+parser+lowerer compiled to WASM, executing via `run_ir` —
so there's a single compiler binary embedded in the page, not one per demo.
Each card shows its PatLang source, self-reports timings via `now_ms()`,
and shows the native transcript captured at build time, alongside the
compiler's own metrics measured on its own source. Bigger examples: a
point-of-sale (events + OO + logic facts), a test framework (unit,
event-driven integration, and Gherkin features — `lib/test.patlang`)
running its whole suite in-browser, a **design-by-contract demo**
(passing checks then one deliberate violation, to show enforcement fire),
`patbuild` (a goal-oriented, manifest-driven build system), and
`flowgraph` (control-flow graphs rendered as SVG from the compiler's own
IR, one section per program — `portfolio/flowgraph.html`). The live
**playground** editor has an example-loader dropdown covering all of the
above. The page is generated by PatLang
(`self_hosting/tools/build_portfolio.patlang`); regenerate with:

```bash
rust-runtime/target/release/pat --ir-run self_hosting/tools/build_portfolio.patlang
```

WASM builds are automatically size-optimized and stripped (`rustc_build`
detects a `wasm` target and uses `-C opt-level=z -C strip=symbols` instead
of `-O`) — measured ~7x smaller and faster to compile, with byte-identical
output, since these modules run through `run_ir` rather than needing raw
native speed. The builder also **caches** each demo's compiled artifacts,
keyed on a hash of the demo's own source *and* a fingerprint of the
compiler pipeline itself (`self_hosting/lib/{lexer,parser,lower,codegen,
runtime_rs}.patlang`) — so editing one demo only rebuilds that demo, while
any change to the compiler invalidates every cached artifact and forces a
full rebuild. Delete `portfolio/build/` to force a clean rebuild regardless.

## 10. Debugging tips

- `PATLANG_DEBUG=1` enables evaluator/parser debug logs.
- `pat --emit-rust file.patlang` prints the generated Rust for a program —
  useful when a compiled binary misbehaves.
- `pat --compare file.patlang` catches interpreter/compiled divergence.
- The test suite is the ground truth: `cd rust-runtime && cargo test`.

## 11. Current limitations

- Functions are not yet first-class closures; pass function names and invoke
  with `apply(name, ...)`. Lexical closures are the next major IR feature
  (see `PATLANG_SELF_HOSTING_ROADMAP.md`).
- `goal name { ... }` declarative block syntax still silently no-ops (unlike
  `rule`, discussed in section 4, which is now real) — no unambiguous
  mapping onto the `solve`/`plan` backend has been designed yet.
- `vfs_flush_to_disk`'s write-through has not been exercised under a live
  `wasmtime`/browser WASM run — only compile-time verified that the correct
  target-specific code path is selected.
- Compiling is fast; *self*-compiling takes minutes because rustc digests the
  ~1 MB emitted compiler. `patc` output is unoptimized for size (WASM modules
  ~2 MB); `strip`/`opt-level=s` support is on the roadmap.
- A function invoked via `parallel_map` (or a fiber) runs on a worker
  thread with its own fresh interpreter state that jumps straight into
  that function — it never runs the program's top-level `let` statements
  first, so a top-level constant referenced from inside such a function
  silently doesn't resolve. Work around it by inlining literals or passing
  values as explicit parameters instead of closing over a top-level `let`.
  Also true, separately, of `patc1.exe`-compiled programs generally (not
  just `parallel_map`-invoked functions there) — not yet root-caused.
- `RULES`/`ACTIONS` (the backing stores for `rule_add`/`solve` and
  `action_add`/`plan`) are still `thread_local!`, unlike `EVENT_HANDLERS`/
  `OBJECTS`/the virtual filesystem, which were fixed to be cross-thread
  safe this session — a rule or action registered on one thread isn't
  visible to `solve`/`plan` called from another. Not yet fixed.

Fixed since earlier versions: string escapes (`\n \t \r \" \\`) now work in
the Stage 1 dialect, and `and`/`or` short-circuit in Stage-1-compiled code
exactly as in Stage 0. Real OS threads now exist (fibers, `parallel_map`,
and threaded WASM via `wasm32-wasip1-threads`) — `EVENT_HANDLERS`, the
object store (`new`/`get`/`set_var`, backing `send`), and the virtual
filesystem are all shared across threads now, not silently per-thread
(see the limitation above for the two stores that still are). `fact`/
`query`/`goal` are now backed by real backward-chaining (`rule_add`/
`solve`) and GOAP planning (`action_add`/`plan`), not just a flat lookup
table (section 4) — and GOAP actions can now be parameterized with the
same `^[A-Z]` logic-variable convention as `rule_add`/`solve` (e.g.
`build(X)`), not ground-only. A running program can also now receive
named signals from outside itself (a second CLI invocation, or a local
network call) — see the Networking section above.
