# Values and memory: specification

Status: approved 2026-11-02. Normative for the new compiler and runtime
(`docs/plans/memory-design-review.md`, decision 5) and for the
interpreter. The executable form is `spec_library/values_and_memory/`.
Each scenario names its section here.

"Must" marks a requirement. Part 1 is what a program can observe; it
binds both engines alike. Part 2 is how the new version's runtime and
compiler meet Part 1; no program can observe it except through speed and
memory use.

## Part 1: the language

### 1.1 Every value is an object

Every value is an object of a class, and carries that class with it.
`type_of(v)` names the class: `int`, `bigint`, `float`, `rational`,
`complex`, `interval`, `bool`, `unit`, `string`, `list`, `closure`,
`string_builder`, `vec`, `bool_array`, `rule_store`, `modint`, or the class a `class` declaration
or `new` gave it. No value is ever classless, and no operation changes a
value's class without producing a new value.

`new("Widget", "w1")` returns the object, whose class is `Widget`. This
changes today's behaviour: `new` returns the object's name, the string
`"w1"`, and `get`, `send` and `object_delete` look the object up by that
name. The name stays a way to find a named object (1.6): `s.field` and
`s.field = x`, where `s` is a string holding the name, reach the object's field.
`new` takes a class and a name and nothing more: further arguments stop the program,
since inheritance and traits belong to a `class` declaration.

### 1.2 Methods on every value

Every value answers methods through its class. `3.to_s`, `3.14.to_s`,
`[1, 2].length` and a user class's own methods are the same mechanism. A
built-in class's methods are declared in PatLang, in the runtime's source,
like a user class's.

### 1.3 Integers

An integer value is an `int` exactly when it fits in a signed 64-bit word,
-2^63 to 2^63 - 1; any other integer is a `bigint`. Every operation
applies this rule to its result. A sum that leaves the range is a
`bigint`, and a `bigint` result back inside it is an `int`. Division of
two integers that divides evenly is an `int`; otherwise it is a
`rational`. The rule does not depend on how a value is stored (Part 2).

### 1.4 Operators are methods, and raise ordinary events

An operator is a method of its left operand's class: `3 + 5` sends `+` to
3 with argument 5. A method's declaration may name events it raises. They
are ordinary PatLang events: named where declared, raised and handled as
any event is (`emit`, `when`), with nothing specific to operators.

- A declaration names its events with `raises NAME`, after its `returns`
  clause. A raised event's `event_data` is a list: the receiver, the
  arguments and the result, in that order.
- `int`'s `+` raises `added`. To give "3 was added to 5" and "5 was added
  to 3" as well as "3 and 5 were added", `+` also raises `added_to` once
  for each operand, with `event_data` `[operand, other operand]`.
- The order is: the receiver's `added_to`, the argument's `added_to`, then
  `added`, all after the result is computed. A handler cannot change the
  result.
- While a handler for an event runs, nothing it does on the same thread
  raises that event again: an `added` handler that adds two ints does not
  call itself. Other events are raised as usual. A handler running on a fiber
  holds back its event on that fiber only: if it yields, whoever resumed the
  fiber raises the event as usual. (Added 2026-11-02, while
  writing the scenarios: without it, any handler for an arithmetic event
  that does arithmetic never returns.)

### 1.5 Value semantics and identity semantics

- **Values:** numbers, booleans, unit, strings, lists and closures. An
  operation that "changes" one produces a new value. Every other holder
  of the old value keeps seeing the old value: `list_set` and `list_push`
  leave the list they were given unchanged. When nothing else holds the old list,
  `let xs = list_push(xs, e)` takes the same time however long `xs` is, also when `e`
  reads `xs`. Two numbers, strings or
  lists are equal when their contents are. Closure equality is not
  specified here.
- **Objects with identity:** class instances, objects made by `new`,
  string builders, vecs, bool arrays and rule stores. A change made through one holder
  is seen through every holder, and `bool_array_push` keeps the same
  array when it grows. Two of them are equal only if they are the same
  object.
- **Reading a field:** `get(v, key)` gives the field's value, or `unit` when `v`
  has no field `key`, including when `v` is not an object. A field holding `false`
  reads as `false`, so `get(v, key) == unit` tells a missing field from one set to
  `false`. `unit` is false as a condition.

### 1.6 Memory

- No program frees memory, and none can observe when memory is freed.
- A value lives as long as something holds it. A program whose live data
  is bounded runs in bounded memory however long it runs: a loop that
  replaces a value each iteration does not grow memory with the number of
  iterations.
- **Named objects** (`new` with a name) are the one exception: they live
  until `object_delete`, which frees them and releases what they hold. Finding
  one by its name takes about the same time however many there are. A repeated
  name finds the earliest of its objects still alive.
- The bound is checked from outside the program, by the process's memory
  use. A program has no primitive for reading it.

### 1.7 The two engines agree

The interpreter and native code are two routes to one language. Every
scenario in Part 1 must give the same observable result on both, whichever
directory the program is started in. A program file or an included file that
cannot be read is an error on both, naming the file, and nothing of the program runs. What a
program can read, its logic state and contract facts among them, holds nothing of the engine
running it.

### 1.8 Fibers, budgeted blocks and threads

- `fiber_new(name)` makes a fiber of a named function. `fiber_resume(id, v)`
  runs it until it yields or returns, handing it `v`, and gives what it yielded
  or returned. `fiber_yield(v)` goes back to whoever resumed it, and gives what
  the next resume hands it. `fiber_alive(id)` is true until it has returned.
  Resuming a finished fiber, and yielding on no fiber, stop the program.
- `budgeted(ms, handle) { body }` runs the body on a fiber until `ms` have passed,
  checking at each back-edge of a loop lexically in the body, and yielding early
  if the next iteration, judged by the recent ones, would pass the deadline. It
  gives `["done", value]` or `["paused", handle]`; passing the handle back continues
  the body. The body captures what it reads as a closure does.
- `thread_spawn(closure, args...)` calls the closure with the arguments that follow it, none or
  more, on a thread of its own; their number is checked as any closure call's is (1.13).
  `thread_poll(id)` says, without waiting, whether it has finished. `thread_result(id)`
  waits for it and gives what it returned, once: taking the result gives back all the
  thread held, and a further call stops the program.
- Any number of threads may run the same function at once, including the first time
  it is called: each gives what one thread alone would.
- A fiber's and a thread's memory is given back when it has ended and, for a thread,
  its result has been taken. A fiber that never finishes keeps its stack and what its
  frames hold, since its id can still resume it.

### 1.9 Syntax definitions

- `syntax NAME { ... }` defines a trigger keyword, tokens and rules. Each block
  `trigger { ... }` is replaced by what its rules give, before the program is parsed.
- `AST.Name(args)` gives a node, the list `["Name", args...]`, in a rule or in any other
  code, and nodes nest. A rule can pass one to a function:
  `return handle(AST.Route(verb, path));`. A variable named `AST` keeps its meaning.
- A definition may stand anywhere a statement may, on a line of its own or not, and holds
  in its own file and the files collected after it, each file coming after the files it
  includes.

### 1.10 Text

A string holds characters, whatever bytes they take. `.length`, indexes, `substr`,
`char_code`, `chr` and the string cursor (`str_intern`, `sc_len`, `sc_code`, `sc_char`,
`sc_substr`) all count characters; `byte_length` and `hash_string` see the UTF-8 bytes.
An ASCII string indexes in O(1). Any other walks from its start, so a scan of one uses
the cursor. `chr(n)` gives the character whose code is the int `n`; anything else stops the
program.

`sed(command, input)` takes a command `s/pattern/replacement/flags` and replaces the first
literal match of the pattern in the input, or every match, left to right and not overlapping,
when the flags hold `g`. With `i` in the flags, letters match whatever their ASCII case.
Everything after the third slash is flags. A command that does not start with `s`, an empty
pattern or a missing replacement gives the input unchanged; an empty replacement deletes the
match. The command and the input are read as text.

`let s = s + x` gives a new value, as `+` always does; whatever else holds the old string keeps
it. When nothing else holds it, the time an append takes does not depend on the string's length.

### 1.11 Numbers and bits as functions

`pow` of an exact base to a whole power is exact, and otherwise a float. `sin`, `cos`,
`tan`, `asin`, `acos`, `atan`, `atan2`, `log` and `exp` give floats. `ceil`, `trunc` and
`round` are exact for exact numbers; `round` takes a half away from zero. `abs` of a
complex number is its modulus. `to_fixed` rounds the float's exact value, a tie to even.
`max(a, b)` and `min(a, b)` give the larger and the smaller of two real numbers, keeping its kind.
`bnot` of an int is its bitwise complement, so `bnot n` is `-1 - n`; of anything else it stops the
program, as the other bit operators do.

### 1.12 Intervals

`interval_make(lo, hi)` gives an `interval`, its ends any real numbers with `lo <= hi`;
any other call stops the program at its `require`. `interval_lo` and `interval_hi` read
the ends. An interval prints as `[lo,hi]` and stays an interval when its ends are equal.

- `[a,b] + [c,d]` is `[a+c, b+d]`, `[a,b] - [c,d]` is `[a-d, b-c]`, and `[a,b] * [c,d]` runs
  from the least to the greatest of the four products. `-[a,b]` is `[-b,-a]`. Each end
  follows the rules of its own numbers (1.3), so no rounding is added.
- A real operand counts as the interval from itself to itself. A complex operand, division
  and `%` stop the program, naming the class.
- Two intervals are equal when both ends are, and a real number equals the interval from
  itself to itself. `<` and its relatives do not apply to intervals.

### 1.13 Functions, commands and includes

- A call gives a function exactly as many arguments as it takes. A last parameter named `rest`
  takes any further arguments, as a list, and fewer than the parameters before it is still too
  few. A call naming a function with the wrong number is refused when the program is compiled,
  naming the function and both numbers. A closure knows how many parameters it takes, and a
  call with the wrong number, through a variable, `apply`, `send`, `parallel_map` or a thread's
  start, stops the program as a failed precondition of the closure (or of the function `apply`
  or `parallel_map` named, or of the method `send` named), naming both numbers. However it is
  called, a closure's arguments are fitted as a call naming a function's are, so a last
  parameter named `rest` takes any further ones. A closure is called with at most 8
  arguments; a call with more is refused when the program is compiled. A function declared
  `takes none`, or without `takes`, has no parameters; `none` is never a parameter's name.
  How to group parameters rather than pass many is in `docs/guides/passing-parameters.md`.
- A function that ends without `return` gives the value of its last statement. An
  expression gives its value and a `let` the value it bound. An `if` or a `while` gives the
  value of the last statement it ran, or `unit` if it ran none, and a function with no
  statements gives `unit`.
- A program's top-level statements give their value as a function's body does, and, as with a
  function whose value its caller does not use, nothing prints it: a program writes only what
  it prints. (`pat` printed the value of a program's last top-level expression; v2 does not.)
- The name `unit` in a program is that value, unless the program binds `unit` itself, as a
  parameter or with `let`.
- A call to a name nothing declares compiles, and stops the program when it is reached, with
  `host fn 'NAME' not found`, the lines before it having run. This holds in every build,
  WebAssembly's included, whatever arguments the call passes.
- `exec_capture` gives what the command wrote to standard output and to standard error.
- `list_dir(path)` gives a directory's entries, sorted, a subdirectory's name ending in `/`. A
  path with no directory to read gives `[]`, as `read_file` gives `""` for a file it cannot
  read, and the program goes on; `file_exists` tells a missing path from an empty directory.
- `exec_peak_memory(program, args)` runs the program with the list of arguments and gives two
  things: what it wrote to standard output, followed by what it wrote to standard error if it
  exited non-zero, and its peak working set in bytes, or -1 where the system gives none.
- `exec_measured(program, args)` runs the program and gives four things: what it wrote to
  standard output, what it wrote to standard error, whether it exited 0, and its peak memory
  in bytes (or -1): the most that it and every process it started committed between them.
- `cpu_count()` gives the machine's logical processors, at least 1. `cpu_times()` gives
  `[idle, busy]`, the processors' time since the machine started, summed over all of them, in
  milliseconds; how busy the machine was between two readings is in their differences.
  `memory_status()` gives `[total, available]`, the physical memory in bytes. Where the system
  gives no figures, as in a browser, `cpu_times` and `memory_status` give `[-1, -1]`.
- A file reached by several includes is included once, before the files that include it.
- The runtime has the stage-0 shims: `add(a, b)`, `multiply(a, b)` and `subtract(a, b)` give
  `a + b`, `a * b` and `a - b`; `calculate`, `calculate_result` and `get_value` of anything give
  0, and `process` and `validate` of anything give `true`.
- `progress_report(text)` keeps `text` as the program's latest status, and `progress_status()`
  gives it, `""` before any report.
- `action_clear()` forgets every action `action_add` added, and `plan_incremental(goals)` gives
  what `plan(goals)` gives.
- `plan(goals)` gives a cheapest sequence of the actions' steps from the stores' ground facts to
  a state meeting every goal, and `[]` only when no sequence reaches one: the search has no
  limit that gives up early. For n goals that independent steps meet, it takes time growing
  about as n cubed (40 goals in about 0.2 s, 160 in about 9 s, compiled).
- Adding a rule takes about the same time however many rules there are. A goal's cost does not
  depend on the rules of other predicates, and finding its solutions takes time in proportion
  to their number.
- Rules live in stores. `logic_store_new()` gives a new, unnamed store, which goes when its last
  holder does. `logic_store_named(name)` gives the store with that name, made the first time
  the name is used, and it lives until `store_delete(name)`; the name then names a new, empty
  store. The program's own rules are in the store named `"default"`, and the runtime records
  `contract_holds` facts in the store named `"contracts"`. `rule_add`, `fact` and a `rule`
  declaration add to the default store; `rule_add_to(store, pred, args, body)` adds to the
  store given, and `rule head(args) in NAME :- ...` to the store named NAME.
  `rules_clear()` empties the default store.
- A store holds each ground fact (a rule with no body and no variables) once: adding a fact
  the store holds changes nothing.
- `solve_in(stores, pred, args)` solves against a store or a list of stores: a goal sees the
  rules of every store listed, store by store in the order listed and, within a store, in the
  order they were added. A rule's body goals are solved against the same stores, except a goal
  written `pred(args) from NAME`, which is solved against the store named NAME alone.
  `solve(pred, args)` and `query` solve against the default store and the contracts store.
- `solve_into(target, stores, pred, args)` gives what `solve_in(stores, pred, args)` gives, and
  adds each solution to the store `target` as a fact of `pred`.
- `plan_in(stores, goals)` plans from the ground facts of the stores listed; `plan`, `pursue`
  and `plan_incremental` plan from those of the default store and the contracts store.
- `using kb as logic do ... end` gives a block a store for the `logic` role. Inside it,
  `rule_add`, `fact`, `solve`, `query`, `rules_clear`, `plan`, `plan_incremental`,
  `plan_with_state` and a `rule` declaration with no `in` use `kb` alone in place of the
  default and contracts stores (`rule_add_to`, `fact_in`, `solve_in`, `query_in`,
  `rules_clear_in`, `plan_in` and `plan_with_state_in` are the forms taking a store). The
  compiler makes this change where the block's text is, so it reaches a closure written inside
  the block, which keeps the store after the block ends, and not a function the block calls.
  An inner block giving the same role uses its own store until it ends, and a form naming its
  store keeps it. The store expression is evaluated once, when the block starts. A role other
  than `logic`, or one role given twice, is an error when compiling.
- A program may define a function with a name the runtime has. The program's calls reach its
  function, directly, from a closure or by name, and the runtime goes on using its own. Two of a
  program's files defining one name is an error, naming it, and nothing of the program runs.

### 1.14 Integers modulo n

`mod_make(x, n)` gives a `modint`: the integer `x` reduced modulo the integer `n`, with `n` at
least 2; any other call stops the program at its `require`. `mod_value(m)` gives the residue,
from 0 to n - 1, and `mod_modulus(m)` gives n, each an `int` or a `bigint` (1.3). A modint
prints as `3 mod 7`, and `type_of` and `numeric_kind` give `modint`. A modint's modulus is
fixed when it is made, and no operation changes it. `mod_make(m, n)` of a modint `m` gives
m's residue reduced modulo n: the way a value moves from one modulus to another, such as a
byte into a field or a field element's low byte out of it.

- `+`, `-`, `*` and unary `-` give the modint with the same modulus. An integer operand counts
  as the modint it reduces to. Two modints with different moduli, or an operand of any other
  class, stop the program.
- `a / b` is `a` times the inverse of `b`. A `b` with no inverse (one sharing a factor with n)
  stops the program. `pow(m, k)`, for an integer `k`, is `m` multiplied by itself `k` times, and
  for a negative `k` the inverse's power; `pow(m, 0)` is 1 modulo n.
- Two modints are equal when their moduli and their residues are; an integer equals a modint
  when it reduces to it. `<` and its relatives, and `%`, stop the program.
- When n is 2^k, for k from 1 to 64, a modint is a k-bit word: `band`, `bor` and `bxor` act on
  the words, an integer operand counting as the word it reduces to, `bnot` complements all k
  bits, `shl` and `shr` shift by an `int` count from 0 to k, the bits shifted out lost and zeros
  shifted in, and `rotl(m, s)` and `rotr(m, s)` rotate by `s` from 0 to k. For any other n
  these stop the program.
- **Time.** A modint's residue is secret, and its modulus is not. `+`, `-`, `*`, `/`, unary
  `-`, `==`, `!=`, the bit operators, `rotl` and `rotr` on modints of modulus n take time that
  depends on n alone, never on the residues, and the inverse behind `/` is found in a number of
  steps fixed by n. `pow(m, k)` takes time that depends on n, on the sign of k and on the size
  of its representation (64 bits for an `int`, its number of limbs for a `bigint`), never on
  its bits. `mod_make` of a modint takes time that depends on the two moduli alone. An
  integer operand is reduced as `mod_make` reduces it. Whether the program stops (no inverse,
  a count out of range) depends on the values. `mod_make` of an integer, `mod_value` and
  printing convert between modints and other values, and their time may depend on the values
  converted. The constant-time check (2.7) is how this is tested.

### 1.15 Worlds

A world is where a program's state lives: its named objects, its classes, the handlers
registered for events, the functions reached by name, its logic stores, actions and goals, the
contract facts recorded, and its virtual files. A program starts in a world of its own. A
program can make more, and run code in one, which then sees that world's state and none of
the caller's.

- `world_new()` gives a new world, an `int`. It holds what a program that has just started
  holds: the built-in classes and nothing else, apart from the functions reached by name of the
  world that made it. A program run in the world registers its own there (1.13), and they
  reach it alone.
- `world_call(w, f)` calls the closure `f`, which takes no arguments, in world `w`, on a fiber
  of its own, and gives `["done", value]`, `value` being what `f` returned. What `f` adds,
  declares, registers or writes is added to `w`, and none of it to the caller's world.
- What code in a world other than the program's own prints goes to the world, and nothing goes
  to standard output; `world_output(w)` gives everything printed in `w` so far.
- When code running in `world_call` stops (a failed contract, `exit_with`, a call to a name
  nothing declares, any stop), the stop ends the call and not the program: `world_call` gives
  `["stopped", code]`, `code` being the exit code the program would have stopped with, and its
  caller goes on. What the stop said is in the world's output. The frames between the stop and
  the call are unwound, and what they held is given back (2.2). That includes the frames of
  fibers that code in the call resumed.
- A fiber runs in the world it was made in, whoever resumes it, and a thread in the world of
  the code that started it. A stop on a thread other than the one `world_call` runs on ends
  that thread: its frames are unwound, and it finishes as any thread does, so `thread_poll`
  gives `true` and `thread_result` gives unit. `world_call` gives `["stopped", code]` when `f`
  returns, `code` being the first stop's.
- `world_call` may run inside a world: worlds nest, each with its own state.
- `world_steps(w, n)` gives world `w` a budget of `n` steps, and `world_step()` spends one step
  of the budget of the world the code runs in. When a step is spent with none left, the world
  stops with `step budget of N exhausted`, code 78. A world has no budget until it is given
  one; the program's own world has none. The interpreter spends a step at each call and at
  each jump back to an earlier instruction, so a budget bounds what a program interpreted in
  the world can do; compiled code spends none.
- A call of a runtime function in a program the interpreter runs reaches the function as the
  interpreter has it, whatever the program registers under that name when it starts. So a
  program that asks for every runtime function by name, as one that runs source in a world
  through the interpreter does, runs the same interpreted as compiled.
- `world_free(w)` gives back everything `w` holds, and `w` then names no world. A fiber made in
  `w` that is paused is unwound, as a stop would unwind it, and what its frames held is given
  back. Freeing a world that code is running in stops the program.
- A value `f` returns is an ordinary value in the caller's world, except an object of a class
  the world declared: its class is the world's, so it is taken out of a world as plain data
  (its fields' values) and never as the object.

## Part 2: the new version's runtime and compiler

### 2.1 Representation

- A value is two machine words:
  - a **type word**: the class, plus flags;
  - a **data word**: the full 64-bit payload. That is an `int`'s bits, a
    `float`'s IEEE bits, a `bool` or `unit`, or a pointer to a heap block
    for anything larger.
- The type is never stored in the data word, so an `int` uses all 64 bits,
  and no address range or tag pattern is needed to tell one kind of value
  from another.
- One flag of the type word is reserved for per-value metadata; nothing
  uses it yet.
- A list slot, an argument and a result are each a two-word value.
- Each class has a flag word saying whether any handler is registered for
  an event its methods raise. An operator whose class has no handler
  costs that one test, and nothing where the compiler can see that no
  handler exists.

### 2.2 Ownership

Ownership is the runtime's mechanism for freeing memory as Part 1.6
requires. It is invisible to programs. The rules:

1. A call borrows its arguments and returns a value its caller owns.
2. A local owns the value a call or a literal gave it. A copy of a local
   into another takes its own reference.
3. A structure (list, object, cell, rational, complex, interval) owns each
   value it holds, and releases each when it is freed or a slot is
   overwritten.
4. A heap block is freed when its last reference is released. Freeing it
   releases what it holds.
5. A value in the data word with no heap block (`int`, `float`, `bool`,
   `unit`) has nothing to count. The type word says so; no test of the
   data word is needed. Where the compiler can see that a slot only ever
   holds such a value (every write to it is a literal, a machine word or
   another such slot), it does not test the type word either.

There are no other rules. Each function's ownership behaviour follows
from its PatLang source by these rules. It is recorded per function as a
summary (2.5) and stated as the function's contract (2.4).

**Unwinding.** A stop inside a `world_call` (1.15) ends the frames between it
and the call, and those frames release what they own, by these same rules:

- The stop returns the **unwinding mark**, a value whose type word is 16.
  That is a class no value has, so a program never holds it.
- After each call, and each operator, list or closure that may run program
  code, the compiled code tests the result. On the mark, the function
  releases every slot it owns at that point and returns the mark in turn.
  The slots it releases are its variables and the temporaries still holding
  a value. Each one starts as unit when the function is entered, so each
  holds a value of its own or unit.
- The mark stops at a call written `caught(f(...))`, which gives it as its
  value. Only the runtime writes `caught`, in a file declaring
  `quiet_operators()`. It does so where a world call, a fiber or a thread
  begins, and where the interpreter gives back an interpreted frame.
- The calls the compiled code makes for a `branch` and a `release`
  (`rt_truthy`, `rt_release_last`) reach no program code. Only a failed
  contract of the runtime itself could stop there. Such a stop is still
  recorded, and the world call gives `stopped`, but the code runs on to its
  next test or its return.

A test costs a compare of the result's type word. A function that makes no
call that may give the mark has no unwind code.

### 2.3 Memory manager

- The heap reserves one large address range once, and commits pages from
  the system in chunks, only as needed.
- A block's size is rounded up to a size class: 8-byte steps to 256 bytes,
  then four classes per power of two. A freed block of any size goes to a
  free list.
- **Each thread** has its own free lists and its own bump chunk, taken
  from the reservation with one atomic add. A thread allocates and frees
  on its own lists with no lock and no atomic.
- A block freed by another thread goes onto the freeing thread's lists.
  Past a threshold, a thread trades a batch of blocks with a shared pool,
  taking one lock per batch.
- Freed memory is never returned to the system.
- Reference counts are atomic. Making them plain where the ownership
  summaries prove a value never leaves its thread is an allowed
  optimisation, not a requirement.

### 2.4 Contracts

- Every runtime function and every compiler stage states its contract
  with `require` and `ensure`: its ownership behaviour (2.2), and its
  representation invariants (2.1).
- A broken contract stops the program at the call that broke it, naming
  the contract.
- Contract checks run in every build.
- That policy is one setting, read in one place, the code that decides
  whether a `require` or `ensure` is checked. No contract and no other
  part of the compiler or runtime depends on it. Turning checks off for
  some builds later is a change to that setting alone.

### 2.5 Compiler structure

- The runtime is compiled by the same compiler, through the same stages,
  as any program. The compiler holds no list of facts about named runtime
  functions. Anything it knows about a function, it derives from that
  function's PatLang source.
- Each stage is a job: it takes input artefacts, produces one output
  artefact, and touches no shared mutable state (`__vars`). The
  program-wide inputs are explicit artefacts:
  - the `syntax` definitions;
  - the symbol index;
  - the program facts.
- Per-function ownership summaries are artefacts. A caller is compiled
  against its callee's summary, never its body.
- An artefact is used only when it is complete. One cut short, by an interrupted
  build or by another build writing it at the same moment, is built again.
- A build leaves artefacts in place, and marks those it reuses as just used.
  `compile.patlang --evict KEEP_MB` removes whole jobs, least recently used first,
  until the store is no larger than that. An evicted job is built again when next needed.
- Registrations (`when` handlers, rules, functions reached only by name)
  are recorded in the program facts, never rediscovered by scanning.
- Synthesized names are the declaration's identity plus a counter local
  to it. A sequential build and a parallel build of the same input
  produce identical bytes.

### 2.6 The IR and the bootstrap

- `compile.patlang SRC OUT.ir --ir` writes the program's IR. That is every
  function the program can reach, the runtime's included, after the
  ownership stage, and the one program fact that code generation reads.
  `docs/spec/ir.md` gives the text form and what each instruction means.
- A reader builds an executable from that IR, and it behaves as v2's own
  build of the program does.
- The first reader, `bootstrap/ir_reader.py`, is written in Python with
  only its standard library, and builds for Windows x64. It builds the
  compiler from the compiler's own IR. That compiler builds the compiler,
  the result builds it again, and the last two are byte identical.
- `compile.patlang SRC OUT.wasm --wasm` builds the program, from the same
  IR, as a WebAssembly module. It runs in a browser, or in Node, under the
  host in `self_hosting/v2/wasm/`, and gives the output and exit code that
  v2's own build gives. The exceptions are what a browser has none of:
  files, processes and sockets. `bootstrap/ir_wasm.py` builds the same
  module, byte for byte, from the IR text. `docs/spec/ir.md` gives the
  module's form and the host.
- Each thread and each fibre runs on a Worker of its own, sharing one
  memory. A fibre is still a fibre (1.8): one runs at a time on its thread,
  and it uses the per-thread context of the thread that resumed it.

### 2.7 The constant-time check

`compile.patlang SRC --constant-time` builds nothing. It follows every function the program can
reach, the runtime's included, as the IR is before the ownership stage, and reports each place
where the time taken can depend on a modint's residue (1.14):

- **What is secret.** A modint's residue. A word read from a modint's block, or from any block
  a secret was stored in, is secret, and so is a value computed from a secret. The modulus, and
  what the runtime computes from the modulus alone, is not. A call is followed with its
  arguments' secrecy, so a function is reported only where a secret reaches it.
- **What is followed.** The check knows, for each value, the classes it may have and, for a
  bool or a small int, the values it may hold, and follows only the instructions those allow:
  a test of a modint's class does not lead it into the string or list code beside it. A
  modint's block always holds a secret, so a value that points to none is not a modint. The
  runtime marks what the IR cannot show itself: where a modint's block is made, what is
  computed from the modulus, a residue leaving the class, and memory being freed, which reads
  only the block's size. A list's length, count and room, and an element's type word, are
  public too: they depend on how the list was used and on its elements' classes, never on
  what a residue is. A call whose argument may be of several classes is followed once for
  each kind (an int, a modint, a value that holds values, anything else), each with the
  secrecy that kind can carry, so a callee's `require` rules out the kinds it does not take.
- **What is not known.** An element read from a list, a vec or another cell is known only as
  some value, of any class. Arithmetic on it may be string or list arithmetic as far as the
  check can tell, and a secret reaching that code is reported. A program settles an
  element's class by reading it through `mod_make(x, shape)`, whose `require` admits only
  integers and modints, as `self_hosting/v2/lib/sha512.patlang` and `curve25519.patlang`
  do.
- **What is reported.** A branch (`if`, `while`, `and`, `or`, `match`) deciding on a secret,
  except one whose one side stops the program; an address computed from a secret, as a list,
  string or memory index; `+`, `-`, `*`, `/`, `%` or unary `-` on a secret integer, whose time
  depends on whether the result leaves the `int` class; the machine's division on a secret; a
  secret passed to a closure call or an external function, which the check cannot follow; and
  `mod_value` or printing of a modint, where the residue leaves the class.
- Each place is one line naming the function and what it does with the secret. With none it
  prints `v2: no value-dependent branch or access` and exits 0; with any it exits 1. While it
  runs, `self_hosting/build/v2_constant_time.progress` says how far it has got.
- The interpreter runs the same runtime routines, so the check of a program's modint
  operations covers both engines.
