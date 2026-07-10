PatLang syntax reference (the only language you may write in). This is the
COMPLETE syntax - do not invent syntax from other languages.

Variables: `let x = 5` (reassigning: `let x = x + 1`, not `x = x + 1`)

Functions:
```
make a function called add takes a, b returns r
  let r = a + b
  return r
end
```
Calling: `add(2, 3)`. Every function needs `returns <name>` even if you
never assign to it before an early `return`.

Control flow:
```
if x > 0 then
  print("positive")
else
  if x == 0 then
    print("zero")
  else
    print("negative")
  end
end
```
(there is no `elif`/`else if` keyword - nest another `if` inside `else`)

```
while i < 10 do
  print(i)
  let i = i + 1
end
```
There is NO `for` loop of any kind (no `for x in xs`, no `for i = 0 to n`).
Iterate over a list with a `while` loop and an integer index instead:
```
let i = 0
while i < xs.length do
  print(xs[i])
  let i = i + 1
end
```

Operators: `+ - * / %` arithmetic; `== != < > <= >=` comparison;
`and or not` logical (not `&&`, `||`, `!`). String concatenation also uses
`+` (numbers auto-convert to strings when concatenated with `+`).

Lists: `let xs = [1, 2, 3]`, `xs[0]`, `xs.length`, `list_push(xs, 4)`
(returns a NEW list - lists are not mutated in place, so always do
`let xs = list_push(xs, 4)`).

Strings: `.length` counts characters. `xs[i]` indexes a single character.
`substr(s, start, len)` returns a substring. `char_code(s, i)` returns the
character code at position i (-1 past the end). `chr(code)` builds a
1-character string from a code point.

Printing: `print(value)` - always adds a newline, works on any type.

Comments start with `#`.

No classes/objects are needed for straightforward tasks - just top-level
`make a function` declarations and a few `print()` calls at the end
demonstrating example usage. A function CANNOT see variables from outside
its own parameters - everything it needs must be passed as an argument.

Common mistakes to avoid (these are NOT valid PatLang, even though they
exist in other languages):
  - `else if` / `elif` as a single construct - does not exist. For 3+
    branches, nest a full `if...end` inside the `else`, with one `end` per
    nesting level. Worked example:
    ```
    if n <= 1 then
      let result = false
    else
      if (n == 2) or (n == 3) then
        let result = true
      else
        if (n % 2) == 0 then
          let result = false
        else
          let result = true
        end
      end
    end
    ```
    Count the `end`s: one per `if` AND one per `while`, always, with no
    exceptions for "else if" chains.
  - `mod` as a word operator - use `%` instead (`n % 2`, not `n mod 2`).
  - `break` / `continue` - do not exist and are silently ignored rather
    than erroring, which can produce a loop that looks like it compiled
    but never actually exits early. Use the `while` condition itself to
    control iteration, or `return` to exit a function early from inside a
    loop (that part does work).
  - `&&`, `||`, `!` - use `and`, `or`, `not`.
  - `if`/`else` as an inline expression (e.g. `let x = if cond then a else
    b end`, a ternary) - does not exist. `if`/`else` are statements only.
    Assign in each branch instead:
    ```
    let x = a
    if not cond then
      let x = b
    end
    ```
  - Multi-line string/expression concatenation with a leading operator on
    the continuation line - **only safe when the program is parsed by the
    Rust CLI's own native frontend** (e.g. `pat --ir-run`/`--build-run` on
    a plain `.patlang` file, or anything reached via a top-level `include`).
    It silently truncates when the program is instead tokenized by the
    self-hosted, PatLang-authored parser (`self_hosting/lib/parser.patlang`,
    used whenever source is compiled via `tokenize`/`parse_program` calls,
    e.g. `compile_both`/`compile_native` in `build_portfolio.patlang`, or
    anything run through `run_ir`/the live browser playground) - that
    parser's `parse_add`/`parse_mul` don't skip newlines before checking
    for a continuation operator, unlike its own list/argument parsing
    (which does) and unlike the native frontend. Concretely, this silently
    breaks and drops everything after the first line:
    ```
    let s = "a" + chr(10)
      + "b" + chr(10)
      + "c"
    # s is just "a\n" here when self-hosted-compiled - "b"/"c" vanish
    ```
    Safe everywhere: one `let` per concatenation step, each a complete
    single-line expression:
    ```
    let s1 = "a" + chr(10)
    let s2 = s1 + "b" + chr(10)
    let s = s2 + "c"
    ```
    Use this style for any `.patlang` file that will be `read_file`'d as
    text and compiled/run via `tokenize`/`parse_program` (not just
    `include`d), which includes every demo card in the portfolio.

Example of a complete, correct program:
```
make a function called factorial takes n returns result
  if n <= 1 then
    let result = 1
  else
    let result = n * factorial(n - 1)
  end
  return result
end

print(factorial(5))
print(factorial(0))
```

Second worked example, showing list iteration with a `while` loop (never a
`for` loop) and building up a running result:
```
make a function called sum_list takes xs returns total
  let total = 0
  let i = 0
  while i < xs.length do
    let total = total + xs[i]
    let i = i + 1
  end
  return total
end

make a function called max_list takes xs returns best
  let best = xs[0]
  let i = 1
  while i < xs.length do
    if xs[i] > best then
      let best = xs[i]
    end
    let i = i + 1
  end
  return best
end

print(sum_list([1, 2, 3, 4]))
print(max_list([3, 7, 2, 9, 4]))
```

Beyond plain functions and loops, PatLang also has four other paradigms.
Use whichever genuinely fits the task - don't force one in if the plain
function/loop style above is a more natural fit.

Object-oriented (`new`/`send`/`get`) - use when the task is naturally about
several independent, named, stateful things (accounts, counters, sessions):
```
new("Account", "alice")          # registers an object identified by "alice"
send("alice", "set", "balance", 100)
print(get("alice", "balance"))   # 100
send("alice", "set", "balance", get("alice", "balance") + 50)
print(get("alice", "balance"))   # 150

new("Account", "bob")
send("bob", "set", "balance", 0)
print(get("bob", "balance"))     # 0 - a completely separate object
```
The object's name is a plain string identity, not a variable - build it
dynamically (e.g. `"account_" + id`) if you need many similar objects.

Event-driven (`when`/`emit`) - use when the task is naturally a reaction to
something happening (a reading arriving, an item being scanned), especially
if several different things should happen in response to one occurrence.
Declare `when` handlers before any `emit` that should trigger them:
```
when temperature_reading do
  if event_data > 100 then
    print("ALERT: " + event_data + " is too high")
  else
    print("normal: " + event_data)
  end
end

emit("temperature_reading", 72)
emit("temperature_reading", 150)
```
Inside a handler, `event_data` is the value passed as the second argument
to `emit`. `emit` runs every matching handler immediately (synchronously) -
this is not real concurrency, just an organizing structure for "when X
happens, do Y".

Logic/goal-oriented (`fact`/`query`/`goal`) - use when the task is
naturally about relationships or rules over named things (family trees,
dependency graphs). `fact(pred, a, b)` records one fact; `query(pred, a,
default)` returns the COUNT of facts recorded for that (pred, a) pair - it
is a count, not a value lookup, so it's useful for "does this exist"
(count > 0) or "how many" checks:
```
fact("parent", "alice", "bob")
fact("parent", "alice", "carol")
fact("parent", "bob", "dana")
print(query("parent", "alice", 0))   # 2 - alice has 2 recorded children
print(query("parent", "eve", 0))     # 0 - no facts recorded for eve
```
`goal(name, target)` just records that a goal is being pursued (for
narration/logging) - the actual work of achieving it is ordinary recursive
functions checking facts and calling themselves, exactly like any other
function.

Functional (`apply`) - use when the task is naturally "do the same
transformation to every item in a list" (map) or "keep only items matching
a rule" (filter). `apply(function_name_as_a_string, arg1, arg2, ...)` calls
a function by name, so a single `map`/`filter` helper can work with any
named function:
```
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

Dynamic code execution ("eval") and runtime syntax extension - `tokenize`,
`parse_program`, `lower_program`, and `run_ir` (all library/host functions,
defined in `self_hosting/lib/{lexer,parser,lower}.patlang` and a host
function respectively) are ordinary PatLang-callable functions, not special
compile-time magic - a running program can build a source string however it
likes (concatenation, data read at runtime, whatever) and compile+execute
it in the same run:
```
let src = "print(" + chr(34) + "hello from generated code" + chr(34) + ")"
let ir = lower_program(parse_program(tokenize(src)))
run_ir(ir)
```
This is exactly what `self_hosting/examples/playground_main.patlang` does
with whatever a user types into the live browser IDE.

`syntax NAME { ... }` grammar-extension blocks (see `self_hosting/lib/
syntax_dsl.patlang`) are no exception: `expand_syntax_dsls_with(src,
existing_defs)` is a plain, stateless string-in/list-out function - it can
define a syntax whose trigger keyword and rules are computed from runtime
data, and a LATER, separate call can use it by threading the returned
`defs` list forward, with no syntax declaration text needed at the use
site. See `self_hosting/examples/dynamic_syntax_demo.patlang` for a worked
example that defines and uses a grammar extension in two separate calls
within one run. `expand_syntax_dsls(src)` (no `existing_defs` argument) is
a thin wrapper over this for the common single-call case.
