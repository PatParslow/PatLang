# Closures, threads, fibers and worlds in native PatLang

This guide covers the constructs that behave differently on the native x64
backend (`./patc1.exe <src> <out> --x64`) than they do in the interpreter. Each
rule below was checked by compiling and running a small program natively. The
examples are the probe programs under `self_hosting/tools/spec_fixtures/`.

## 1. Closures

A closure is a value you can store, pass to a function, and call later.

```patlang
let base = 10
let add_base = |y| { return base + y }
print(add_base(1))            # 11
```

A closure captures the values of the variables it uses at the moment it is
created. Later changes to those variables are not seen.

**Closures can be passed to named functions and called there:**

```patlang
make a function called apply_twice takes f, x returns result
  let once = f(x)
  return f(once)
end

print(apply_twice(|n| { return n * 2 }, 3))   # 12
```

**Closures can be stored in the global table with `set_var` and retrieved
with `get`:**

```patlang
let base = 100
set_var("adder", |y| { return base + y })
let f = get("__vars", "adder")
print(f(1))                   # 101
```

Calling a closure from a named function works in every shape above.

**Rules:**

- Naming a declared function after a built-in form shadows the built-in and
  prints a warning (see section 6). Closures themselves are not affected.
- A closure value is data: it is `["__closure", name, captured, arity]`. Do not
  build or edit these by hand. `type_of` reports `list`.

### Calling a closure from runtime code

Runtime (`x64_runtime.patlang`) code cannot call a closure value directly. If
it does, the program crashes. Use `rt_call_closure1`, which the compiler
supports for any program that contains a closure literal:

```patlang
let c = |y| { return y + 100 }
print(rt_call_closure1(c, 5))  # 105
```

A program with no closure literal has no bridge. `rt_call_closure1` then stops
with exit code 94 and a message. Add a closure literal, or do not call the
runtime helper.

## 2. Threads: `thread_spawn`

`thread_spawn` starts a real OS thread that runs a closure.

**The closure takes no parameters.** `thread_spawn` passes it no arguments, so
any value it needs has to be captured.

```patlang
let base = 40
let t = thread_spawn(|| { return base + 2 })
while not thread_poll(t) do
  let spin = 0
end
print(thread_result(t))       # 42
```

**Rules:**

- Poll with `thread_poll(t)` until it returns true, then read the value with
  `thread_result(t)`. Reading earlier gives a stale value.
- A closure literal with parameters is a compile error:
  `thread_spawn(|x| { return x + 1 })` is rejected.
- A closure held in a variable is checked when the thread starts. If it takes
  parameters, the program stops with exit code 93 and a message:
  ```patlang
  let f = |x| { return x + 1 }
  let t = thread_spawn(f)     # stops at run time, exit 93
  ```
- Threads share the program's global tables with the rest of the program. See
  section 4 before combining threads with worlds.

## 3. Fibers

A fiber is a coroutine: a named function that can pause (`fiber_yield`) and be
resumed. Each native fiber runs on its own OS thread, and only one side runs at
a time.

```patlang
make a function called yielder takes arg returns result
  fiber_yield(7)
  return 9
end

let fid = fiber_new("yielder")
let first = fiber_resume(fid, 0)      # 7, the yielded value
let second = fiber_resume(fid, 0)     # 9, the returned value
print(first)
print(second)
```

**Rules:**

- `fiber_new(name)` takes the name of a function. It returns -1 if no such
  function is in the build. The compiler keeps every function that a
  name-based call (`fiber_new`, `apply`, `budgeted_run`) could reach, so a
  function named only in a string is still available.
- The body receives the value of the first `fiber_resume` as its argument.
- `fiber_resume` returns the yielded value while the fiber is suspended, and
  the returned value once it finishes. You do not need to unwrap a pair.
- A suspended fiber is still alive. `fiber_alive(fid)` tells you whether it
  has finished.

## 4. Worlds: `interp_run` and `world_run`

A world runs PatLang source in a clean interpreter, inside the same process.
Its variables, classes, and VFS are separate from yours, and its output is
captured. Use `interp_run` for the simple case:

```patlang
include "../../lib/interp_run.patlang"
include "../../lib/world_native.patlang"

let r = interp_run("print(3 + 4)\n", [["backend", "world"]])
print(r[2])   # true
print(r[0])   # 7 (with a newline)
print(r[1])   # empty stderr
```

`include "world_native.patlang"` is required in a native program that uses the
world backend. Without it `interp_run` reports no backend.

**Options** (a list of `[key, value]` pairs):

| Key | Meaning |
|---|---|
| `backend` | `"world"` for the in-process backend |
| `max_steps` | Step budget. Calls and backward jumps spend one step. Exhaustion gives `ok=false` with `step budget exhausted` |
| `vfs_in` | `[[path, content], ...]` preloaded into the world's VFS (the world starts empty) |
| `vfs_out_prefix` | Only VFS paths with this prefix are returned |
| `classes_in` | `[[name, field_defaults, methods], ...]` classes to make visible to the world |

`stdin` is not supported on the world backend. Pass it and you get
`ok=false`.

**Lower-level: `world_run(ir, opts)`** returns
`[stdout, stderr, ok, vfs_out, classes_out]`. `classes_out` lists the classes
the world defined, not counting the interpreter's own.

```patlang
let c = interp_compile("print(1)\n")
let w = world_run(c[1], [["classes_in", [["Passed", [], []]]]])
print(w[4][0][0])             # Passed
```

**What a world isolates:** the caller's variables, classes, and VFS are not
visible to the world, and the world's writes do not reach the caller. The
interpreter's own classes are not swapped out.

**Halts:** a runtime halt inside a world (for example a missing VFS file read
with `vfs_read`) ends that world with `ok=false` and the stderr line
`native halt: exit code N`. The caller carries on, and a later world runs
normally.

**Refusals:** `world_run` refuses to start (returns `ok=false`) while another
thread or fiber is still running. A suspended fiber you started yourself counts.
Worlds nested inside a world are allowed.

## 5. Printing and capture

All program output goes through one function. With no world running, it goes to
the console. Inside a world, it is captured into that world's `stdout`. You do
not need to do anything special to get this.

## 6. Names: built-in forms and user functions

Some names are built-in forms (`print`, `emit`, `fact`, `query`, `new`, `apply`,
`thread_spawn`, `fiber_yield`, and a few others). If you declare a function with
one of these names, your function is called, and the compiler prints a warning:

```
warning: function 'emit' shadows the built-in form 'emit'; calls to 'emit' now call your function
```

Runtime primitives are different. A user function with the same name as a
runtime primitive is a compile error, and the compiler lists the clash.

Rename your function if you do not want the warning or the error.

## 7. Quick reference

| You want | Use | Watch out for |
|---|---|---|
| A closure that captures values | `let f = \|y\| { return base + y }` | Capture is by value at creation time |
| To call a closure from runtime code | `rt_call_closure1(c, arg)` | Needs a closure literal in the program |
| A background computation | `thread_spawn(\|\| { ... })` then `thread_poll` / `thread_result` | No parameters |
| A coroutine | `fiber_new`, `fiber_resume`, `fiber_yield` | Resume value is the body's argument |
| A sandboxed run of source | `interp_run(src, [["backend","world"]])` | Include `world_native.patlang`; no stdin |
| Limit a run's work | `max_steps` | Counts calls and backward jumps |
| Seed a world's files | `vfs_in` | World starts with an empty VFS |
| Check whether a run halted | `ok` is false and stderr says `native halt` | The caller keeps running |
