# Getting started with PatLang

PatLang's compiler and interpreter are both written in PatLang. The compiler,
v2, turns a program into a Windows x64 executable or a WebAssembly module. The
interpreter runs a program's source directly, on the same runtime the compiled
program uses, so the two give the same output. Every example below was run both
ways and printed what is shown.

## 1. Build the compiler

You need Windows on x64 and Python 3. Python is used once, to build the first
compiler from its intermediate representation (IR), which is checked in as
`bootstrap/v2_compiler.ir`. From the repository root:

```bash
py -3 bootstrap/ir_reader.py bootstrap/v2_compiler.ir self_hosting/build/v2.exe
self_hosting/build/v2.exe self_hosting/v2/interp.patlang self_hosting/build/v2_interp.exe --workers 4
```

The first command takes a few seconds and gives `v2.exe`, the compiler. The
second has the compiler build the interpreter, `v2_interp.exe`, in a few
minutes. Nothing else is needed: the compiler has its own assembler and linker,
written in PatLang.

Run `v2.exe` from the repository root, where it finds the runtime it compiles
into each program (`self_hosting/v2/runtime/`). The interpreter can be run from
anywhere.

## 2. Your first program

Create `hello.patlang`:

```patlang
let name = "world"
print("hello, " + name)
```

Run it with the interpreter:

```bash
self_hosting/build/v2_interp.exe hello.patlang
```

Or compile it and run the executable:

```bash
self_hosting/build/v2.exe hello.patlang hello.exe
./hello.exe
```

Both print `hello, world`. Beside `hello.exe` the compiler writes
`hello.exe.asm` (the assembly it generated), `hello.exe.timing` (how long each
stage took) and `hello.exe.ledger` (each function, and whether it was built or
taken from the cache). The first build compiles the runtime as well, which takes
about half a minute. Each function's build is cached in
`self_hosting/build/v2_artefacts/` by a hash of what went into it, so a later
build of a changed program rebuilds only what changed. `--workers N` builds on
N threads.

The same program as WebAssembly, run under Node:

```bash
self_hosting/build/v2.exe hello.patlang hello.wasm --wasm
node self_hosting/v2/wasm/run_node.mjs hello.wasm
```

## 3. Language tour

### Values and expressions

```patlang
let x = 10
let y = x * 3 + 2
let s = "value: " + y      # + joins when either side is a string
let ok = (x < 20) and (y != 0)
print(s)                   # value: 32
print(ok)                  # true
```

Statements are separated by newlines, and comments start with `#`. Operators
are `+ - * / %`, the comparisons `== != < <= > >=` (strings compare
alphabetically), and `and`, `or`, `not`.

Numbers keep their exact value. An int is 64 bits; a result that does not fit
becomes a bigint, and a division of ints that does not come out whole gives a
rational:

```patlang
print(9223372036854775807 + 1)   # 9223372036854775808
print(pow(2, 70))                # 1180591620717411303424
print(6 / 4)                     # 3/2
print(7 / 7)                     # 1
print(pow(2, 0 - 2))             # 1/4
print(1.5 + 1)                   # 2.5
print(sqrt(2.0))                 # 1.4142135623730951
print(type_of(6 / 4))            # rational
```

`type_of` names a value's class: `int`, `bigint`, `rational`, `float`,
`string`, `list`, `bool`, `closure`, or a class the program declares.

The bitwise operators are words, as `and`, `or` and `not` are: `band`, `bor`,
`bxor`, `bnot`, `shl`, `shr`.

```patlang
let flags = 0
let flags = flags bor (1 shl 5)   # set bit 5
let flags = flags band bnot 4     # clear bit 2
print(flags)                      # 32
print(bit_get(flags, 5))          # 1
```

### Control flow

```patlang
let x = 12
if x >= 20 then
  print("big")
elif x >= 10 then
  print("medium")
else
  print("small")
end

let i = 0
while i < 3 do
  print(i)
  let i = i + 1        # let again gives the name a new value
end
```

Write a chain of conditions with `elif`.

### Functions

```patlang
make a function called fib takes n returns r
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end

print(fib(20))          # 6765
```

A function can call one declared later in the file. A name declared with `let`
at the top of a file belongs to the file's own statements; a function sees its
parameters and its own locals, so pass it what it needs.

### Lists and strings

```patlang
let xs = [1, 2, 3, 4]
print(list_len(xs))       # 4
print(xs[2])              # 3 (indexes start at 0)

let ys = xs
let ys = list_push(ys, 5)
let ys = list_set(ys, 0, 99)
print(xs)                 # [1, 2, 3, 4]
print(ys)                 # [99, 2, 3, 4, 5]
```

Lists are values: changing `ys` leaves `xs` as it was. A list only one name
holds is changed in place, so building a list in a loop costs no copying.

```patlang
let s = "hello"
print(s[0])                            # h
print(char_code(s, 0))                 # 104
print(substr(s, 1, 3))                 # ell
print(str_len(s))                      # 5
print(str_join(["a", "b", "c"], "-"))  # a-b-c
```

Strings are values too, and `s = s + x` copies `s` each time. To build a string
in a loop, use a string builder, which is shared rather than copied:

```patlang
let b = sb_new()
let i = 0
while i < 5 do
  sb_push(b, to_s(i))
  let i = i + 1
end
print(sb_str(b))          # 01234
```

`vec_new`, `vec_push`, `vec_get` and `vec_set` give a shared, growable list in
the same way.

### Pattern matching

```patlang
make a function called describe takes x returns r
  match x do
    case 0 then
      return "zero"
    case "hi" then
      return "a greeting"
    case ["Ok", v] then
      return "ok with " + v
    case n when n > 100 then
      return "big: " + n
    case _ then
      return "something else"
  end
end

print(describe(0))         # zero
print(describe(["Ok", 5])) # ok with 5
print(describe(250))       # big: 250
print(describe(7))         # something else
```

A case can be a literal, a list shape that binds names, a name with a `when`
guard, or `_` for anything. A match no case takes stops the program.

### Splitting code across files

`include "path.patlang"` brings in another file, found relative to the file
that includes it:

```patlang
include "lib/helpers.patlang"
print(helper_fn(41))
```

## 4. The paradigms

### Classes and objects

```patlang
class Money {
  field cents = 0
  make a function called + takes self, other returns r
    let m = new("Money")
    m.cents = self.cents + other.cents
    return m
  end
  make a function called show takes self returns s
    return "£" + (self.cents / 100.0)
  end
}

let a = new("Money")
a.cents = 150
let b = new("Money")
b.cents = 275
let total = a + b
print(type_of(total))    # Money
print(total.cents)       # 425
print(total.show())      # £4.25
```

Every value is an object, and an operator is a method of its left operand's
class: `a + b` calls Money's `+`. Classes can inherit (`class Saver inherits
Account { ... }`) and compose traits.

An object can also be given a name, and reached by it:

```patlang
class Widget {
  field color = "grey"
}
new("Widget", "w1")
send("w1", "set", "color", "red")
print(get("w1", "color"))   # red
```

A named object lasts until `object_delete` removes it.

### Events

```patlang
when greeting do
  print("event received: " + event_data)
end

emit("greeting", "hello events")   # event received: hello events
```

A `when` handler runs each time its event is raised, with `event_name` and
`event_data` bound. A method can declare the events it raises:

```patlang
class Account {
  field balance = 0
  make a function called deposit takes self, n returns r raises deposited
    self.balance = self.balance + n
    return self.balance
  end
}

when deposited do
  print("new balance " + event_data[2])
end

let acc = new("Account")
acc.deposit(5)              # new balance 5
acc.deposit(3)              # new balance 8
```

The event's data is the method's arguments and then its result. The built-in
operators raise events in the same way when a handler is registered for them,
and a handler cannot change an operator's result.

### Closures and functions as values

```patlang
make a function called make_adder takes n returns r
  return |x| do
    return x + n
  end
end

let add_three = make_adder(3)
print(add_three(7))          # 10

let inc = |x| do
  return x + 1
end
make a function called twice takes f, x returns r
  return f(f(x))
end
print(twice(inc, 10))        # 12
```

A closure takes a copy of the variables it uses when it is made, so a later
change to the variable does not reach it:

```patlang
let n = 1
let show = || do
  return n
end
let n = 2
print(show())                # 1
```

`apply("double", 21)` calls a function by its name.

### Logic programming

Rules are solved by backward chaining, as in Prolog. A name starting with a
capital letter is a variable:

```patlang
rule parent(tom, bob).
rule parent(bob, ann).
rule grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
print(solve("grandparent", ["tom", "Who"]))   # [[tom, ann]]
```

`rule_add` is the same thing as a function call, and a rule with no body is a
fact:

```patlang
rule_add("dep", ["a", "b"], [])
rule_add("dep", ["b", "c"], [])
rule_add("unchanged", ["c"], [])
rule_add("buildable", ["X"], [["unchanged", ["X"]]])
rule_add("buildable", ["X"], [["dep", ["X", "Y"]], ["buildable", ["Y"]]])
print(solve("buildable", ["a"]))              # [[a]]
```

Rules live in stores. `rule` and `solve` use the default store, and a program
can make its own, or name one:

```patlang
let pets = logic_store_new()
rule_add_to(pets, "owns", ["kim", "cat"], [])
print(solve_in(pets, "owns", ["Who", "What"]))   # [[kim, cat]]
print(solve("owns", ["Who", "What"]))            # []

rule likes(sam, tea) in drinks.
print(solve_in(logic_store_named("drinks"), "likes", ["sam", "D"]))   # [[sam, tea]]
```

### Planning

`action_add(name, preconditions, effects, removed, cost)` declares an action,
and `plan` finds the cheapest sequence of actions that reaches a goal:

```patlang
action_add("compile_b", [], [["compiled", ["b"]]], [], 5)
action_add("compile_a", [["compiled", ["b"]]], [["compiled", ["a"]]], [], 3)
action_add("link", [["compiled", ["a"]], ["compiled", ["b"]]], [["shipped", []]], [], 2)
print(plan([["shipped", []]]))     # [compile_b, compile_a, link]
```

An action can have variables, which the facts fill in:

```patlang
rule_add("ready", ["target_a"], [])
rule_add("ready", ["target_b"], [])
action_add("build", [["ready", ["X"]]], [["built", ["X"]]], [], 1)
print(plan([["built", ["target_a"]], ["built", ["target_b"]]]))
# [build(X=target_a), build(X=target_b)]
```

A goal names a state to reach. `pursue` plans for it, and `activate` runs the
plan, calling the closure bound to each action and stopping at the first that
returns `false`. Continuing the program above:

```patlang
action_bind("build", |args| do
  print("building " + args[0])
  return true
end)
goal need_a { built(target_a) }
let p = pursue need_a
print(p)                  # [build(X=target_a)]
print(activate p)         # building target_a, then true
```

### Design by contract

```patlang
make a function called safe_divide takes a, b returns r
  require b != 0
  let r = a / b
  ensure (r * b) == a
  return r
end

print(safe_divide(10, 4))   # 5/2
assert (1 + 1) == 2
print(safe_divide(1, 0))
```

`require` checks a precondition, `ensure` a postcondition, and `assert` a
condition anywhere. A check that fails stops the program with exit code 3:

```
contract violation: precondition failed in safe_divide(): b != 0
```

A check that holds is recorded as a `contract_holds` fact, which rules and plans
can use.

### Threads and fibres

```patlang
make a function called square takes x returns r
  return x * x
end
print(parallel_map([1, 2, 3, 4], "square"))   # [1, 4, 9, 16]

let t = thread_spawn(|| do
  return square(9)
end)
print(thread_result(t))                       # 81
```

`parallel_map` runs a function over a list on several threads, and
`thread_spawn` runs a closure on a thread of its own. A fibre runs until it
yields, and carries on when it is resumed:

```patlang
make a function called counter takes start returns r
  fiber_yield(start + 1)
  fiber_yield(start + 2)
  return start + 3
end
let f = fiber_new("counter")
print(fiber_resume(f, 10))   # 11
print(fiber_resume(f, 0))    # 12
print(fiber_resume(f, 0))    # 13
print(fiber_alive(f))        # false
```

### Files and the virtual filesystem

```patlang
write_file("note.txt", "line one")
print(file_exists("note.txt"))   # true
print(read_file("note.txt"))     # line one
remove_file("note.txt")
print(argv())                    # the program's arguments, as a list
```

`vfs_write`, `vfs_read`, `vfs_exists`, `vfs_list` and `vfs_delete` give a
filesystem in memory, which works the same in a browser:

```patlang
vfs_write("notes/todo.txt", "write the vfs demo")
print(vfs_read("notes/todo.txt"))   # write the vfs demo
print(vfs_list("notes/"))           # [notes/todo.txt]
```

### Networking and signals

`tcp_listen(0)` listens on a port the system picks and returns it, and
`tcp_connect`, `tcp_accept`, `tcp_read`, `tcp_write` and `tcp_close` do the
rest. They bind to `127.0.0.1` only.

A running program can answer other programs through signals, from
`self_hosting/lib/signals.patlang`. A long-running program claims a port,
polls it in its main loop, and answers `status` with what it is doing. The
include below is written for a file at the repository root:

```patlang
include "self_hosting/lib/signals.patlang"

when status do
  signal_reply("working")
end

let port_id = signal_claim(0)
let asker = thread_spawn(|| do
  return signal_query(port_id, "status", "")
end)
let i = 0
while i < 50 do
  signal_poll(port_id, 20)    # handle any signal that has come in
  let i = i + 1
end
print(thread_result(asker))   # working
```

Here a thread of the same program asks. In practice it is another process,
given the port.

## 5. How the compiler works

`self_hosting/v2/compile.patlang` is the compiler. A build runs these stages:

| Stage | File |
|---|---|
| Lexing and parsing | `self_hosting/lib/lexer.patlang`, `parser.patlang` |
| Lowering each declaration to IR | `self_hosting/v2/lower.patlang` |
| Inserting the reference counting | `self_hosting/v2/own.patlang` |
| Generating x64 assembly | `self_hosting/v2/x64.patlang` |
| Assembling | `self_hosting/lib/x64_asm.patlang` |
| Linking a Windows executable | `self_hosting/lib/x64_pe_link.patlang` |

The runtime, `self_hosting/v2/runtime/`, is PatLang too, and is compiled with
each program by the same stages. Each function's code generation and assembly
is one job, and the jobs run on the workers `--workers` gives.

Other outputs:

- `v2.exe SRC OUT.ir --ir` writes the program's IR (`docs/spec/ir.md`).
- `v2.exe SRC OUT.wasm --wasm` writes a WebAssembly module, from the same IR.
- `v2.exe SRC --constant-time` reports every place where a program's timing
  could depend on a secret value (`self_hosting/v2/examples/README.md`).

The compiler compiles itself:

```bash
self_hosting/build/v2.exe self_hosting/v2/compile.patlang next_v2.exe --workers 8
```

Built from the same sources, `next_v2.exe` builds a compiler that is the same
as itself, byte for byte, and the tests check this. The IR in `bootstrap/` is the compiler's own, written with
`--ir`, and `bootstrap/ir_reader.py` builds a compiler from it that builds the
same compiler again. A reader in another language needs only what
`docs/spec/ir.md` gives.

## 6. In the browser

`self_hosting/v2/wasm/` is the host for a module `--wasm` writes, in a browser
or in Node. Each thread and each fibre runs in a Worker over one shared memory,
so a page needs to be cross-origin isolated.

The portfolio (`portfolio/`) runs each example program in the page. It has a
playground, a REPL, and an IDE with a debugger that steps through a recorded
trace. To build it:

```bash
self_hosting/build/v2.exe self_hosting/tools/build_portfolio.patlang build_portfolio.exe
./build_portfolio.exe
```

Then serve `portfolio/` over HTTP and open `index.html`.

## 7. Tests

The language is specified in Gherkin, in `spec_library/`, and the scenarios
are executable. `self_hosting/v2/tools/gates.sh` runs them all, on both the
compiled and interpreted engines, and checks the compiler's self-build and the
bootstrap:

```bash
bash self_hosting/v2/tools/gates.sh           # what has changed since it last passed
bash self_hosting/v2/tools/gates.sh --plan    # say what would run
bash self_hosting/v2/tools/gates.sh --all     # everything
```

The gates remember what passed, and run again only what a change could affect,
in parallel, leaving two cores and 4 GB of memory free for other work. From
nothing, a full run takes between two and three hours on a 20-core machine.
`docs/plans/gates.md` describes how.

## 8. Further reading

- `docs/spec/values-and-memory.md`: values, objects and memory, the
  specification v2 implements.
- `docs/spec/ir.md`: the IR, for writing a reader.
- `docs/guides/`: closures, threads, fibres and worlds; passing parameters.
- `self_hosting/v2/examples/`: integers modulo n, hashing, key exchange and
  signatures, written in PatLang.
