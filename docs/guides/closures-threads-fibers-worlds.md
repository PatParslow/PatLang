# Closures, threads, fibres and worlds in PatLang

This guide covers closures, the two kinds of concurrency, and worlds, which run
code, or another program's text, apart from the caller's state. The rules are
in `docs/spec/values-and-memory.md`: 1.8 for fibres and threads, 1.13 for
functions and closures, 1.15 for worlds. Each
example is a file under `self_hosting/tools/spec_fixtures/doc_examples/`, and the
output shown is what it prints, compiled by v2 and on the v2 interpreter alike.
To try one, from the repository root:

```
self_hosting/build/v2_interp.exe self_hosting/tools/spec_fixtures/doc_examples/closure_capture.patlang
self_hosting/build/v2.exe self_hosting/tools/spec_fixtures/doc_examples/closure_capture.patlang out.exe
./out.exe
```

## 1. Closures

A closure is a value: it can be stored, passed to a function, and called later.
Its body can be written `|y| do ... end` or `|y| { ... }`.

### 1.1 Capture

A closure takes a copy of the variables it uses when it is made. A later change
to a variable is not seen.

```patlang
let base = 10
let add_base = |y| { return base + y }
print(add_base(1))            # 11
```

File: `closure_capture.patlang`.

### 1.2 Passing a closure to a function

```patlang
make a function called apply_twice takes f, x returns result
  let once = f(x)
  return f(once)
end

print(apply_twice(|n| { return n * 2 }, 3))   # 12
```

File: `closure_param.patlang`.

### 1.3 Keeping a closure

A closure can be kept anywhere a value can: in a variable, a list, an object's
field, a vec.

```patlang
class Holder {
  field f = 0
}
let base = 100
let h = new("Holder")
h.f = |y| do
  return base + y
end
let g = h.f
print(g(1))                   # 101

let v = vec_new()
vec_push(v, |y| do
  return y * 2
end)
let d = vec_get(v, 0)
print(d(21))                  # 42
print(type_of(d))             # closure
```

File: `closure_stored.patlang`.

### 1.4 Rules

- A closure is called with as many arguments as it takes, at most 8. A call
  with the wrong number stops the program as a failed precondition
  (`docs/guides/passing-parameters.md`).
- `apply(name, args...)` calls a declared function by its name.

## 2. Threads: `thread_spawn`

`thread_spawn(f, args...)` runs the closure `f` on an OS thread of its own,
calling it with the arguments that follow it.

### 2.1 Spawn, poll, read

```patlang
let base = 40
let t = thread_spawn(|| { return base + 2 })
while not thread_poll(t) do
  let spin = 0
end
print(thread_result(t))       # 42
```

File: `spawn_inline.patlang`. `thread_poll` says, without waiting, whether the
thread has finished. `thread_result` waits for it and gives what it returned. A
result is taken once: that gives back all the thread held, and a second
`thread_result` for the same thread stops the program.

### 2.2 Arguments

```patlang
let f = |x| { return x + 1 }
let t = thread_spawn(f, 41)
print(thread_result(t))       # 42
let u = thread_spawn(f)
print(thread_result(u))
```

The arguments are checked as any closure call's are. `u`'s thread calls `f` with
none, so the program stops, with exit code 3:

```
contract violation: precondition failed in a closure: it takes 1 argument, given 0
```

File: `spawn_variable_with_params.patlang`.

`parallel_map(list, name)` runs a declared function over a list on several
threads and gives the results in order.

## 3. Fibres

A fibre is a coroutine: a function that runs until it yields, and carries on
from there when it is resumed. Only one side runs at a time.

### 3.1 A generator

```patlang
make a function called counter takes arg returns result
  fiber_yield(1)
  fiber_yield(2)
  fiber_yield(3)
  return 99
end

let fid = fiber_new("counter")
print(fiber_resume(fid, 0))   # 1
print(fiber_resume(fid, 0))   # 2
print(fiber_resume(fid, 0))   # 3
print(fiber_resume(fid, 0))   # 99
print(fiber_alive(fid))       # false
```

File: `fiber_generator.patlang`.

### 3.2 Rules

- `fiber_new(name)` takes a function's name, as a string.
- The function receives the value of the first `fiber_resume` as its argument.
- `fiber_resume(id, v)` gives the value the fibre yielded, or the value it
  returned when it finished. `fiber_yield` gives the `v` of the next resume.
- Resuming a fibre that has finished, or yielding when no fibre is running,
  stops the program.
- A paused fibre is alive; `fiber_alive` is false once it has returned.
- A fibre runs in the world it was made in, whoever resumes it (section 4).

## 4. Worlds

A world holds a program's state: its named objects, classes, event handlers,
functions reached by name, logic stores, contract facts and virtual files. A
program starts in a world of its own, and can make more.

A world isolates state, not authority. Code in a world can do whatever the
program running it can: read and write real files, start processes, open
sockets, and use as much time as the call takes (a step budget, 4.2, bounds
only interpreted loops and calls; compiled code and one long call to `plan`,
`solve` or `pow` spend none). What no program can do, in a world or not, is
use the runtime's own primitives and `rt_` functions: only a file declaring
`quiet_operators()` may, and the interpreter refuses them in the text it runs
as the compiler does. Running another program's text in a world keeps its
state apart from yours; it does not make that text safe to run.

### 4.1 Running code in a world

```patlang
let w = world_new()
let r = world_call(w, || do
  print("inside the world")
  vfs_write("note.txt", "kept in the world")
  return 6 * 7
end)
print(r)                      # [done, 42]
print(world_output(w))        # inside the world
print(vfs_exists("note.txt")) # false: the caller's files are its own
let again = world_call(w, || do
  return vfs_read("note.txt")
end)
print(again)                  # [done, kept in the world]
let stopped = world_call(w, || do
  assert 1 == 2
  return 0
end)
print(stopped)                # [stopped, 3]
```

File: `world_direct.patlang`.

- `world_call(w, f)` calls the closure `f` in world `w`, on a fibre of its own,
  and gives `["done", value]`. What `f` declares, registers or writes stays in
  `w`.
- What code in the world prints goes to the world, and `world_output(w)` gives
  it.
- A stop in the world (a failed contract, `exit_with`, any other stop) ends the
  call and not the program: `world_call` gives `["stopped", code]`, with the
  exit code the program would have stopped with.
- `world_free(w)` gives back everything the world holds.

### 4.2 A step budget

```patlang
world_steps(w, 100)
let spent = world_call(w, || do
  let i = 0
  while i < 1000 do
    world_step()
    let i = i + 1
  end
  return i
end)
print(spent)                  # [stopped, 78]
print(world_free(w))          # true
```

`world_steps(w, n)` gives the world a budget of n steps, and `world_step()` spends
one. With none left, the world stops with code 78. The interpreter spends a step
at each call and each jump back, so a budget bounds what an interpreted program
can do in the world.

### 4.3 Running a program's text: `interp_run`

`self_hosting/lib/interp_run.patlang` runs PatLang source and gives back what it
printed. Its world backend compiles the source with the compiler's front end and
runs it on the v2 interpreter, in a new world:

```patlang
include "../../../lib/context.patlang"
include "../../../lib/interp_run.patlang"

let ctx = context_new()
let r = interp_run(ctx, "print(3 + 4)\n", [["backend", "world"]])
print(r[2])                   # true
print(r[0])                   # 7, and its line end
print(r[1])                   # empty
```

File: `world_basic.patlang`. `interp_run(ctx, src, opts)` gives
`[stdout, stderr, ok]`; `interp_run_full` adds the world's files and a trace. The
context (`lib/context.patlang`) keeps the runtime's declarations, read once.
Include paths are relative to the file with the `include` line.

### 4.4 Options

Options are a list of `[key, value]` pairs:

| Key | Meaning |
|---|---|
| `backend` | `"world"`, `"process"` (a fresh `v2_interp.exe`), or `"auto"` |
| `max_steps` | World: a step budget, spent at each call and each jump back |
| `vfs_in` | World: `[[path, content], ...]` written into the world's files first |
| `vfs_out_prefix` | World: the world's files under this prefix come back |
| `timeout_ms`, `stdin` | Process: a wall-clock limit, and text for its input |
| `base_dir` | Expand the source's `include` lines relative to this directory |
| `trace` | World: record up to this many steps of the run |

The world backend refuses `stdin`.

### 4.5 A budget on a program

```patlang
let r = interp_run(ctx, "let i = 0\nwhile i < 1000000 do\n  let i = i + 1\nend\nprint(i)\n", [["backend", "world"], ["max_steps", 1000]])
print(r[2])                   # false
print(r[0])                   # step budget of 1000 exhausted
```

File: `world_budget.patlang`.

### 4.6 Files in and out

```patlang
let src = "print(vfs_read(\"/w/a.txt\"))\nvfs_write(\"/w/new.txt\", \"n\")\n"
let r = interp_run_full(ctx, src, [["backend", "world"], ["vfs_in", [["/w/a.txt", "A"]]], ["vfs_out_prefix", "/w/"]])
print(r[0])                   # A
let i = 0
while i < list_len(r[3]) do
  print(r[3][i][0] + " = " + r[3][i][1])   # /w/a.txt = A, then /w/new.txt = n
  let i = i + 1
end
print(vfs_exists("/w/new.txt"))            # false
```

File: `world_vfs.patlang`. The caller's files are not visible in the world, and
the world's writes do not reach the caller.

### 4.7 Stops

A stop in the program ends its world, and the caller carries on:

```patlang
let h = interp_run(ctx, "print(\"before\")\nassert 1 == 2\nprint(\"after\")\n", [["backend", "world"]])
print(h[2])                   # false
print(h[0])                   # before, then the contract violation
let again = interp_run(ctx, "print(7)\n", [["backend", "world"]])
print(again[2])               # true
print(again[0])               # 7
```

File: `world_halt.patlang`. What the stop said is in the output:
`contract violation: assertion failed in __main(): 1 == 2`.

### 4.8 Fibres and worlds together

A paused fibre of the caller's does not stop a world from running:

```patlang
make a function called yielder takes arg returns result
  fiber_yield(7)
  return 9
end

let fid = fiber_new("yielder")
print(fiber_resume(fid, 0))           # 7
let ran = interp_run(ctx, "print(1)\n", [["backend", "world"]])
print(ran[2])                         # true
print(fiber_resume(fid, 0))           # 9
```

File: `world_busy.patlang`. Worlds nest: code in a world can make and call
another.

## 5. Names: built-in forms and your functions

Some names are built-in forms, such as `print`, `emit`, `new` and `apply`. A
function you declare with one of these names is the one called:

```patlang
make a function called emit takes x returns result
  return x
end
print(emit(5))                # 5
```

File: `shadow_emit.patlang`.

## 6. Quick reference

| You want | Use | Watch out for |
|---|---|---|
| A closure that captures values | `let f = \|y\| { return base + y }` | Capture is by value, when it is made |
| A background computation | `thread_spawn(f, args...)`, then `thread_poll` / `thread_result` | One `thread_result` per thread |
| The same function over a list | `parallel_map(list, "name")` | A declared function, by name |
| A coroutine | `fiber_new("name")`, `fiber_resume`, `fiber_yield` | Runs in the world it was made in |
| Code apart from your state | `world_new`, `world_call`, `world_output`, `world_free` | A stop gives `["stopped", code]` |
| A program's text, run apart | `interp_run(ctx, src, [["backend", "world"]])` | Needs a context; no stdin |
| Limit a run's work | `max_steps`, or `world_steps` | Interpreted code spends steps; compiled code spends none |

## 7. WebAssembly

```
self_hosting/build/v2.exe SRC.patlang OUT.wasm --wasm
node self_hosting/v2/wasm/run_node.mjs OUT.wasm
```

The host in `self_hosting/v2/wasm/` runs each thread and each fibre as a Worker
over one shared memory, so closures, threads, fibres and worlds all work there,
in Node and in a cross-origin isolated browser page. A browser has no files or
processes of its own: give a program files to read with `run_node.mjs --files DIR`
or the page's `?files=`.
