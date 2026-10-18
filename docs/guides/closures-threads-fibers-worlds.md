# Closures, threads, fibers and worlds in PatLang

This guide covers the constructs that behave differently on the native x64
backend (`./patc1.exe <src> <out> --x64`) than in the interpreter, and which of
them also work when built for WASM (section 8). Each example is a file under
`self_hosting/tools/spec_fixtures/doc_examples/`, and the output shown was
produced by compiling and running it. To try one:

```
./patc1.exe self_hosting/tools/spec_fixtures/doc_examples/closure_capture.patlang out.exe --x64
./out.exe
```

## 1. Closures

A closure is a value you can store, pass to a function, and call later.

### 1.1 Capture

A closure captures the values of the variables it uses when it is created.
Later changes to those variables are not seen.

```patlang
let base = 10
let add_base = |y| { return base + y }
print(add_base(1))            # 11
```

File: `closure_capture.patlang`.

### 1.2 Passing a closure to a named function

```patlang
make a function called apply_twice takes f, x returns result
  let once = f(x)
  return f(once)
end

print(apply_twice(|n| { return n * 2 }, 3))   # 12
```

File: `closure_param.patlang`.

### 1.3 Storing a closure in the global table

`set_var` stores a value in the program's global table, and `get` reads it
back. Closures survive the round trip.

```patlang
let base = 100
set_var("adder", |y| { return base + y })
let f = get("__vars", "adder")
print(f(1))                   # 101
```

File: `closure_stored.patlang`.

### 1.4 Calling a closure from runtime code

Runtime code cannot call a closure value directly. Use `rt_call_closure1`,
which is available in any program that contains a closure literal:

```patlang
let c = |y| { return y + 100 }
print(rt_call_closure1(c, 5))  # 105
```

File: `closure_runtime_bridge.patlang`. A program with no closure literal has
no bridge, and `rt_call_closure1` stops with exit code 94 and a message.

### 1.5 Rules

- A closure value is data: `["__closure", name, captured, arity]`. Do not build
  or edit these by hand. `type_of` reports `list`.
- Naming a declared function after a built-in form shadows the built-in and
  prints a warning (section 6). Closures are not affected.

## 2. Threads: `thread_spawn`

`thread_spawn` starts an OS thread that runs a closure. The closure takes **no
parameters**, because `thread_spawn` passes it no arguments. Capture any values
it needs.

### 2.1 The usual pattern: spawn, poll, read

```patlang
let base = 40
let t = thread_spawn(|| { return base + 2 })
while not thread_poll(t) do
  let spin = 0
end
print(thread_result(t))       # 42
```

File: `spawn_inline.patlang`. `thread_poll` returns true when the thread has
finished. Reading the result earlier gives a stale value.

### 2.2 Refusal rules

- A closure literal with parameters is a compile error:
  `thread_spawn(|x| { return x + 1 })` is rejected at build time.
- A closure held in a variable is checked when the thread starts. If it takes
  parameters, the program stops with exit code 93:

  ```patlang
  let f = |x| { return x + 1 }
  let t = thread_spawn(f)
  ```

  File: `spawn_variable_with_params.patlang` prints
  `thread_spawn: the closure takes parameters, but thread_spawn passes it none; capture the values you need instead`
  and exits with 93.

## 3. Fibers

A fiber is a coroutine. A named function runs on its own OS thread, pauses with
`fiber_yield`, and is resumed with `fiber_resume`. Only one side runs at a time.

### 3.1 A generator

```patlang
make a function called counter takes arg returns result
  fiber_yield(1)
  fiber_yield(2)
  fiber_yield(3)
  return 99
end

let fid = fiber_new("counter")
print(fiber_resume(fid, 0))
print(fiber_resume(fid, 0))
print(fiber_resume(fid, 0))
print(fiber_resume(fid, 0))
print(fiber_alive(fid))
```

Output: `1`, `2`, `3`, `99`, `0`. File: `fiber_generator.patlang`.

### 3.2 Rules

- `fiber_new(name)` takes the name of a function, as a string. It returns -1 if
  the build has no such function. The compiler keeps every function that a
  name-based call could reach, so a function named only in a string is still
  available.
- The body receives the value of the first `fiber_resume` as its argument.
- `fiber_resume` returns the value the fiber yielded, or the value it returned
  when it finished. No unwrapping is needed.
- A suspended fiber counts as alive. `fiber_alive` is false once it returns.
- Fibers are native-only. See section 8.

## 4. Worlds: `interp_run` and `world_run`

A world runs PatLang source in a clean interpreter, inside the same process.
The world has its own variables, classes, and VFS, and its printed output is
captured.

To use the world backend in a native program, include the world support file:

```patlang
include "../../../lib/interp_run.patlang"
include "../../../lib/world_native.patlang"
```

Paths are relative to the file that contains the `include` line.

### 4.1 Running source

```patlang
let r = interp_run("print(3 + 4)\n", [["backend", "world"]])
print(r[2])                   # true
print(r[0])                   # 7 (with a newline)
print(r[1])                   # empty stderr
```

File: `world_basic.patlang`. `interp_run` returns `[stdout, stderr, ok]`.
`interp_run_full` also returns the VFS listing as a fourth element.

### 4.2 Options

Options are a list of `[key, value]` pairs:

| Key | Meaning |
|---|---|
| `backend` | `"world"` for the in-process backend |
| `max_steps` | Step budget. Each call and each backward jump spends one step |
| `vfs_in` | `[[path, content], ...]` preloaded into the world's VFS. The world starts empty |
| `vfs_out_prefix` | Only VFS paths with this prefix are returned |
| `classes_in` | `[[name, field_defaults, methods], ...]` classes made visible to the world |

`stdin` is not supported by the world backend. Passing it gives `ok=false`.

### 4.3 Step budget

```patlang
let r = interp_run("let i = 0\nwhile i < 1000000 do\n  let i = i + 1\nend\nprint(i)\n", [["backend", "world"], ["max_steps", 1000]])
print(r[2])                   # false
print(r[1])                   # IR runtime error: step budget exhausted
```

File: `world_budget.patlang`.

### 4.4 Preloaded files and listing the VFS

```patlang
let src = "print(vfs_exists(\"a.txt\"))\nvfs_write(\"new.txt\", \"n\")\n"
let r = interp_run_full(src, [["backend", "world"], ["vfs_in", [["a.txt", "A"]]], ["vfs_out_prefix", ""]])
print(r[0])                   # 1, then a blank line
let i = 0
while i < r[3].length do
  print(r[3][i][0])           # a.txt, then new.txt
  let i = i + 1
end
```

File: `world_vfs.patlang`. The caller's own files are not visible to the world,
and the world's writes do not reach the caller.

### 4.5 Classes

`classes_in` makes a caller-defined class visible to the world. `world_run`
returns the classes the world defined in its fifth element:

```patlang
let c = interp_compile("print(1)\n")
let w = world_run(c[1], [["classes_in", [["Passed", [], []]]]])
print(w[4][0][0])             # Passed
```

File: `world_classes.patlang`. The interpreter's own classes are not visible
to, or swapped by, the world.

### 4.6 Halts

A runtime halt inside a world (for example reading a missing VFS file with
`vfs_read`) ends that world, not the program:

```patlang
let h = interp_run_full("print(\"before\")\nprint(vfs_read(\"nope\"))\nprint(\"after\")\n", [["backend", "world"]])
print(h[2])                   # false
print(h[1])                   # native halt: exit code 95
let again = interp_run("print(7)\n", [["backend", "world"]])
print(again[2])               # true
print(again[0])               # 7
```

File: `world_halt.patlang`. The caller continues, and later worlds run normally.

### 4.7 Refusals

- `world_run` refuses to start while another thread or fiber is still running.
  A suspended fiber you started yourself counts. The result is `ok=false`:

  ```patlang
  make a function called yielder takes arg returns result
    fiber_yield(7)
    return 9
  end

  let fid = fiber_new("yielder")
  print(fiber_resume(fid, 0))           # 7
  let refused = interp_run("print(1)\n", [["backend", "world"]])
  print(refused[2])                     # false
  print(fiber_resume(fid, 0))           # 9
  let ran = interp_run("print(2)\n", [["backend", "world"]])
  print(ran[2])                         # true
  ```

  File: `world_busy.patlang`.
- Worlds nested inside a world are allowed.

## 5. Output

All program output goes through one function. With no world running, it goes
to the console. Inside a world it is captured into that world's `stdout`. You
do not need to do anything to get this.

## 6. Names: built-in forms and user functions

Some names are built-in forms: `print`, `emit`, `fact`, `query`, `new`, `apply`,
`thread_spawn`, `fiber_yield`, and a few others. If you declare a function with
one of these names, your function is called, and the compiler prints a warning:

```patlang
make a function called emit takes x returns result
  return x
end
print(emit(5))                # 5, with a warning at build time
```

```
warning: function 'emit' shadows the built-in form 'emit'; calls to 'emit' now call your function
```

File: `shadow_emit.patlang`.

A user function with the same name as a runtime primitive is a compile error,
and the compiler lists the clash. Rename your function to fix it.

## 7. Quick reference

| You want | Use | Watch out for |
|---|---|---|
| A closure that captures values | `let f = \|y\| { return base + y }` | Capture is by value at creation time |
| A closure called from runtime code | `rt_call_closure1(c, arg)` | Needs a closure literal in the program |
| A background computation | `thread_spawn(\|\| { ... })`, then `thread_poll` / `thread_result` | No parameters |
| A coroutine | `fiber_new`, `fiber_resume`, `fiber_yield` | Native only (section 8) |
| A sandboxed run of source | `interp_run(src, [["backend","world"]])` | Include `world_native.patlang`; no stdin |
| Limit a run's work | `max_steps` | Counts calls and backward jumps |
| Seed a world's files | `vfs_in` | World starts with an empty VFS |
| Check whether a run halted | `ok` is false and stderr says `native halt` | The caller keeps running |

## 8. WASM

Build for WASM with `./patc1.exe <src> <out.wasm> wasm32-wasip1` and run with
`wasmtime run <out.wasm>`.

**Portable:** closures (sections 1.1–1.3), float and integer output, the
block-model language itself, and the world backend through the host's
`world_run`. The host world backend does not need `world_native.patlang`, so
leave that include out for WASM builds. Verified: `world_basic`, `world_budget`
and the closure examples give the same output as native when the include is
removed. Example that builds for both:

```patlang
include "../../../lib/interp_run.patlang"

let r = interp_run("print(3 + 4)\n", [["backend", "world"]])
print(r[2])
print(r[0])
```

**Native only:** fibers (`fiber_new`, `fiber_resume`, `fiber_yield`,
`fiber_alive`), threads (`thread_spawn`, `thread_poll`, `thread_result`),
`rt_call_closure1`, `budgeted(...)` blocks, and everything in
`world_native.patlang`.

A program that uses a native-only construct is refused at build time:

```
patc1: this program uses constructs that exist only in the native x64 backend, so it cannot be built for wasm32-wasip1: [fiber_new, fiber_resume, fiber_alive]. Build with --x64 instead (see docs/guides/closures-threads-fibers-worlds.md, section 8).
```

The build exits with status 1. Build such programs with `--x64`.

**Known differences on WASM** (#210):
- A WASM (or `--patc`) program's own top-level script, if its last statement
  is a loop or any other non-`print` expression, has that expression's value
  printed as one extra trailing line -- e.g. a `while i < n do ... end` as the
  last statement prints the final value of `i`. This comes from the
  Rust-source-emission backend's generated `main()` (`emit_main_rs` in
  `self_hosting/lib/codegen.patlang`, mirrored in `codegen.rs`), which always
  prints the program's own return value; native x64 has no such convention.
  End a script with an explicit `print(...)` (whose own return value is
  `Unit`, printed as an empty line that most output can absorb unnoticed) to
  avoid a meaningful stray value. Not fixed -- `--ir-run` and `--patc` are
  deliberately tested for parity on this exact behavior
  (`interp_compiled_parity.feature`), so removing it would need to change
  that contract too.
- A missing VFS file in a world is reported as an `IR runtime error`, not as a
  native halt. Both give `ok=false`; this is a wording difference only.
