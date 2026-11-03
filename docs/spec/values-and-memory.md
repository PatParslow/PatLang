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
`string_builder`, `vec`, `bool_array`, or the class a `class` declaration
or `new` gave it. No value is ever classless, and no operation changes a
value's class without producing a new value.

`new("Widget", "w1")` returns the object, whose class is `Widget`. This
changes today's behaviour: `new` returns the object's name, the string
`"w1"`, and `get`, `send` and `object_delete` look the object up by that
name. The name stays a way to find a named object (1.6).

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
  call itself. Other events are raised as usual. (Added 2026-11-02, while
  writing the scenarios: without it, any handler for an arithmetic event
  that does arithmetic never returns.)

### 1.5 Value semantics and identity semantics

- **Values:** numbers, booleans, unit, strings, lists and closures. An
  operation that "changes" one produces a new value. Every other holder
  of the old value keeps seeing the old value: `list_set` and `list_push`
  leave the list they were given unchanged. Two numbers, strings or
  lists are equal when their contents are. Closure equality is not
  specified here.
- **Objects with identity:** class instances, objects made by `new`,
  string builders, vecs and bool arrays. A change made through one holder
  is seen through every holder, and `bool_array_push` keeps the same
  array when it grows. Two of them are equal only if they are the same
  object.

### 1.6 Memory

- No program frees memory, and none can observe when memory is freed.
- A value lives as long as something holds it. A program whose live data
  is bounded runs in bounded memory however long it runs: a loop that
  replaces a value each iteration does not grow memory with the number of
  iterations.
- **Named objects** (`new` with a name) are the one exception: they live
  until `object_delete`, which frees them and releases what they hold.
- The bound is checked from outside the program, by the process's memory
  use. A program has no primitive for reading it.

### 1.7 The two engines agree

The interpreter and native code are two routes to one language. Every
scenario in Part 1 must give the same observable result on both.

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
   data word is needed.

There are no other rules. Each function's ownership behaviour follows
from its PatLang source by these rules. It is recorded per function as a
summary (2.5) and stated as the function's contract (2.4).

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
- Registrations (`when` handlers, rules, functions reached only by name)
  are recorded in the program facts, never rediscovered by scanning.
- Synthesized names are the declaration's identity plus a counter local
  to it. A sequential build and a parallel build of the same input
  produce identical bytes.
