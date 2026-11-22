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
`string_builder`, `vec`, `bool_array`, `rule_store`, `modint`, `logic_var`, or the class a `class` declaration
or `new` gave it. No value is ever classless, and no operation changes a
value's class without producing a new value.

`new("Widget", "w1")` returns the object, whose class is `Widget`. This
changes today's behaviour: `new` returns the object's name, the string
`"w1"`, and `get`, `send` and `object_delete` look the object up by that
name. The name stays a way to find a named object (1.6): `s.field` and
`s.field = x`, where `s` is a string holding the name, reach the object's field,
and `get`, `send` and `object_delete` given the name reach the object. A program
can declare otherwise: once it calls `object_names_explicit()`, a string is only a
string in its world (text from a file or a socket that equals a name reaches
nothing), and `object_named(name)` gives the object with that name, or `unit`
when none has it. `object_named` works whichever a program declares.
`new` takes a class and a name and nothing more: further arguments stop the program,
since inheritance and traits belong to a `class` declaration. A class is found by its
name in one look, whatever else is declared: where two classes have one name, the first
declared is the one `new`, an inheriting class and a trait find. An object's field is
found by its name in about the same time wherever it is among the object's fields: an
object with more than 16 keeps an index of them, which only setting a field changes.

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

A `rational` is always in lowest terms, its denominator positive, so two
equal rationals have the same numerator and denominator. Dividing a
d-digit integer by an e-digit one costs time growing as (d - e + 1) * e, and
a gcd of two d-digit numbers as d squared. Adding, subtracting and
multiplying rationals reduce by the gcds of their parts' factors, never of
the whole result (Knuth, TAOCP 4.5.1), so adding 1/k to a fraction of many
digits costs about one division by k.

### 1.4 Operators are methods, and raise ordinary events

An operator is a method of its left operand's class: `3 + 5` sends `+` to
3 with argument 5. Each of `<`, `>`, `<=` and `>=` is sent as itself: an
object's class defines the ones it uses, and one it does not define stops the
program naming the operator and the class. `==` and `!=` are never sent to a
class, since objects compare by identity (1.5), and a class declaring a method
by either name is refused before anything runs. A float NaN is ordered against
nothing, itself included: every comparison with one is false, but `!=`, which
is true. A method's declaration may name events it raises. They
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
  string builders, vecs, bool arrays, bytes and rule stores. A change made through one holder
  is seen through every holder, and `bool_array_push` keeps the same
  array when it grows. Two of them are equal only if they are the same
  object.
- **Reading a field:** `get(v, key)` gives the field's value, or `unit` when `v`
  has no field `key`, including when `v` is not an object. A field holding `false`
  reads as `false`, so `get(v, key) == unit` tells a missing field from one set to
  `false`. `unit` is false as a condition.
- **When nothing is there:** indexing a list or a vec past its ends, or indexing a
  value that has no elements, gives `unit`, as `get` does for a missing field.
  Indexing a string past its ends gives `""`. `getenv` gives `""` for an unset
  variable and `read_file` gives `""` for a missing file; `file_exists` tells a
  missing file from an empty one. `vfs_exists` gives `true` or `false`, and
  `vfs_read` of a missing path stops the program. (`vfs_exists` gave the text `"1"` or
  `"0"`, both true as a condition, so `if vfs_exists(p)` always took its first branch.) `query` gives the number of matches, 0 for none.

- **bytes** (class 18) is a buffer of bytes, one byte of memory each, where a list of
  ints holds a 16-byte value for each. `bytes_new(n)` is `n` zero bytes; `bytes_len`,
  `bytes_get(b, i)` and `bytes_set(b, i, v)` read and write them, each an int from 0 to
  255, and an index outside it stops the program as a bool array's does. `b[i]` reads as
  a list's index does, the byte or unit past either end, and `list_len(b)` is its length.
  `bytes_push`
  grows it in place; `bytes_extend(b, more)` appends a bytes, copied whole, or a list of
  ints; `bytes_slice(b, start, n)` is a new bytes. `bytes_eq` compares contents.
  `bytes_from_str` and `bytes_to_str` go through UTF-8, `bytes_from_list` and
  `bytes_to_list` through lists of ints. `read_file_raw(path)` gives a file's bytes (none
  for a file that cannot be read), and `write_file_bytes` takes a bytes or a list.

### 1.6 Memory

- No program frees memory, and none can observe when memory is freed.
- A value lives as long as something holds it. A program whose live data
  is bounded runs in bounded memory however long it runs: a loop that
  replaces a value each iteration does not grow memory with the number of
  iterations.
- Freeing a value takes no more stack however deeply it is nested: a list nested a
  million deep is dropped like any other.
- Values that hold each other (two objects each in a field of the other, a vec
  that holds itself, a closure in the vec it captured) are freed too, once
  nothing else holds any of them, though not at once: the runtime looks for
  them each time the number of objects, vecs and rule stores has doubled, and
  only while no thread but the first is running.
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
  A fiber is found by its id in a number of steps growing as the logarithm of the
  fibers paused, so a resume among 2000 costs about what one among 125 does.
  Resuming a finished fiber, and yielding on no fiber, stop the program. A fiber
  runs on one thread at a time: resuming one that is running (from inside
  itself, or from a second thread while the first runs it) stops the program,
  saying it is already running.
- `budgeted(ms, handle) { body }` runs the body on a fiber until `ms` have passed,
  checking at the back-edges of the loops lexically in the body, and yielding early
  if the next iteration, judged by the recent ones, would pass the deadline. It
  gives `["done", value]` or `["paused", handle]`; passing the handle back continues
  the body. The body captures what it reads as a closure does.
- The clock is read once per batch of back-edges: as many iterations as take about a
  millisecond, or half the time left, at the rate the recent ones predict, and at least one.
  An iteration of a millisecond or more is a batch of its own. 2 million cheap iterations take
  46 ms budgeted and 9 ms plain (reading the clock at each back-edge took 950 ms). A batch of
  fast iterations can pass the deadline by what the rate it was judged at underestimated.
- `thread_spawn(closure, args...)` calls the closure with the arguments that follow it, none or
  more, on a thread of its own; their number is checked as any closure call's is (1.13).
  `thread_poll(id)` says, without waiting, whether it has finished. `thread_result(id)`
  waits for it and gives what it returned, once: taking the result gives back all the
  thread held, and a further call stops the program.
- Any number of threads may run the same function at once, including the first time
  it is called: each gives what one thread alone would.
- What threads share. The runtime's own tables may be changed from any thread, each change
  one step: the virtual files (`vfs_write`, `vfs_append`, `vfs_delete`), handlers, classes,
  named objects, named rule stores, actions and goals, connections and processes. Four
  workers writing virtual files together leave every write there.
- A vec, a string builder, a bool array, an object's fields and a rule store each belong to
  one thread at a time. Threads may read one together, and one thread may hand it to
  another. When a thread changes one while another thread is reading or changing it, the
  program stops (98) saying so; it is never left with corrupted memory. Whether two threads
  meet depends on timing, so a program that shares one without taking turns may run or may
  stop: give each worker its own and merge afterwards. The language has no lock.
- TCP is on this machine only. A listener binds 127.0.0.1 itself, not every address, and while
  it holds the port Windows refuses another socket binding 127.0.0.1 on it, from this process
  or another, even one that sets `SO_REUSEADDR` (checked 2026-11-17). Once the listener's
  program has ended the port is free, even when it closed a connection's end first: on Linux
  that end waits in TIME_WAIT for a minute, and the runtime sets `SO_REUSEADDR` so that a bind
  is not refused for it, while one on a port another socket listens on still is. `tcp_connect` takes
  `localhost` or a `127.x.x.x` address; another address stops the program saying it is not this
  machine, and text that is not four numbers of 0 to 255 stops it saying it is not an address.
  A program that declares `tcp_allow_remote()` (once, like `object_names_explicit()`, for
  its world) reaches beyond this machine: `tcp_connect` then takes any IPv4 address or a
  name, a name with no address giving `-1` to `tcp_try_connect`. `dns_resolve(name)` gives
  a name's IPv4 addresses as text, none twice, `[]` for none (an address gives itself), from
  `getaddrinfo` on Windows and, on Linux, `/etc/hosts` and then an A query to each
  `nameserver` of `/etc/resolv.conf`, 5 seconds twice. `dns_query(server, port, name,
  wait_ms)` asks one DNS server over UDP for a name's A records, following a CNAME the
  answer gives, and gives `[]` for a name the server says is not there or when no answer
  comes within `wait_ms`, twice. Both stop a program that has not declared
  `tcp_allow_remote()`. IPv6 is not covered.
  A connection nothing accepts stops it too; `tcp_try_connect` gives `-1` there instead, and
  takes the same addresses.
- The runtime's locks go to whichever waiting thread is running when the lock comes free, not
  to the waiters in turn, and a waiting thread spins briefly, then gives up the rest of its
  time slice each turn. So more threads than processors, or a machine busy with other work,
  do not hold a lock back for one waiter to be run: 16 threads take about as long as 4 for the
  same work, idle or loaded, where they once took up to 165 times as long.
- `tcp_accept_timeout(port, ms)` gives a connection made within `ms`, else -1, and leaves the
  listener waiting as before: a later `tcp_accept` waits for its client. Threads may wait on
  one listener at once, with either call: each connection goes to one of them, and each timed
  wait still gives -1 when its time is up.
  `tcp_read_timeout(conn, ms)` gives what arrives within `ms`, and `""` when nothing does,
  when the peer has closed, or when the read fails; `tcp_read_status(conn, ms)` tells those
  apart, giving `[text, "data"]`, `["", "wait"]`, `["", "end"]` or `["", "error"]`. Text
  read keeps the bytes as they came, so `bytes_from_str` gives them back exactly, binary
  data included. `tcp_try_write(conn, data)` gives `false`
  when the peer has gone, where `tcp_write` stops the program. `random_bytes(n)` gives `n`
  bytes, each 0 to 255, from the system's random source, fit for a secret.
- A fiber's and a thread's memory is given back when it has ended and, for a thread,
  its result has been taken. A fiber that never finishes keeps its stack and what its
  frames hold, since its id can still resume it.

### 1.9 Syntax definitions

- `syntax NAME { ... }` defines a trigger keyword, tokens and rules. Each block
  `trigger { ... }` is replaced by what its rules give, before the program is parsed.
- A rule's step `expect NAME` matches the token declared as `NAME`, whatever its name.
  Four steps are built in: `Symbol("text")` matches the text, `Many(STEP)` repeats a
  step, and `Identifier` and `Block` match a name and a braced block. `Symbol` and `Many`
  are those steps only with their parenthesis, so a token may be named `Symbol` or
  `Symbols`; a token named `Identifier` or `Block` could never be reached, and the
  definition says so.
- `AST.Name(args)` gives a node, the list `["Name", args...]`, in a rule or in any other
  code, and nodes nest. A rule can pass one to a function:
  `return handle(AST.Route(verb, path));`. A variable named `AST` keeps its meaning.
- A definition may stand anywhere a statement may, on a line of its own or not, and holds
  in its own file and the files collected after it, each file coming after the files it
  includes.

### 1.10 Text

A string holds characters, whatever bytes they take. `.length`, indexes, `substr`,
`char_code`, `chr` and the string cursor (`str_intern`, `sc_len`, `sc_code`, `sc_char`,
`sc_substr`) all count characters; `byte_length`, `hash_string` and `str_hash` see the UTF-8
bytes. `str_hash(s)` is FNV-1a over them, its low 62 bits as a non-negative int, the same on
every engine: for a program's own hash tables, where hashing a name a character at a time cost
about 4 us. `bytes_hash(b)` is the same over a bytes's bytes, so it gives a bytes the hash
`str_hash` gives a string of those bytes: for checking that stored bytes are the ones stored.
An ASCII string indexes in O(1). Any other walks from its start, so a scan of one uses
the cursor. `chr(n)` gives the character whose code is the int `n`; anything else, a
surrogate code (U+D800 to U+DFFF) included, stops the program.

Text from outside (`read_file`, `tcp_read`, a child's output) holds whatever bytes arrived,
and keeps them. Its characters are its well-formed UTF-8 sequences (Unicode's table 3-7: no
overlong form, no surrogate, nothing past U+10FFFF, each wholly within the string), and each
byte that starts none is a character of its own whose code is 65533 (U+FFFD). Counting,
indexing, `substr`, `char_code` and the cursor all read characters this way, and none reads
past the string's last byte.

`str_contains(text, needle)` says whether the text holds the needle, in time that grows
with the text's bytes whatever characters it holds. The empty needle is in every text.

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
`round` are exact for exact numbers; `round` takes a half away from zero. The math functions
are the runtime's own (`runtime/libm.patlang`, fdlibm's algorithms by way of musl), not the
system's, so every target gives the same bits: each of the functions above is within one unit
in the last place of the exact result, and `sqrt`, `floor`, `ceil`, `trunc`, `round` and `%` on
floats are exact. `float_bits(x)` gives a number's IEEE 754 double bits as an int (the 64 bits
read as signed), and `float_from_bits(n)` the float an int's bits are. A compiled `+`, `-`,
`*`, `/` or comparison of two floats is one machine operation, about the cost of one on two ints
(a float add took about 940 cycles through the runtime's operator function, and takes about 10). `abs` of a
complex number is its modulus. `to_fixed` rounds the float's exact value, a tie to even.
`max(a, b)` and `min(a, b)` give the larger and the smaller of two real numbers, keeping its kind.
`bnot` of an int is its bitwise complement, so `bnot n` is `-1 - n`; of anything else it stops the
program, as the other bit operators do. `to_num` reads text as the number it spells: digits with an
optional sign as an int or bigint, digits, `/` and digits (as a rational prints) as that rational in
lowest terms, or the int when it divides evenly, and otherwise a float; text that spells no number,
a zero denominator included, gives 0.0.

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
- The primitives that read or write memory (`mem_load`, `mem_store` and the rest), make or take
  apart a value's words (`value_make`, `value_data`, `value_type_word`), or reach the system or
  the runtime's state (`extern_call`, `extern_call_float`, `atomic_add`, `runtime_state`,
  `thread_entry_address`, `closure_call_unchecked`, `runtime_functions_by_name`), and every
  function named `rt_` that the runtime declares and the program does not, belong to the
  runtime: only a file declaring `quiet_operators()` calls one, or names one as a by-name
  argument. Anywhere else the build is refused, naming each, before anything runs; the
  interpreter refuses the same. A name made at run time reaches no runtime `rt_` function on
  either engine. Word and float arithmetic, `value_class`, `value_live` and the constant-time
  marks are open to every program.
- `now_ms()` gives the wall clock, in milliseconds since 1970: for a time of day, which the
  system may set back or forward. `clock_ms()` gives milliseconds from an unspecified start that
  never go back: for intervals and deadlines. The runtime's own deadlines (`budgeted`,
  `tcp_accept_timeout`, `tcp_read_timeout`, a process's timeout) use `clock_ms`, so changing
  the wall clock moves none of them.
- `cpu_cycles()` counts the processor cycles this thread has run: for comparing the cost of
  two pieces of work. The time the thread waits for a processor is not in it, as it is in
  `clock_ms`; the processor's changing speed, and another thread sharing its core, still move
  it by a third or more. It is a count, not a time, and never goes back. In a browser, which
  counts no cycles, it is the clock in nanoseconds.
- A `match` case may be a glob (`case *.txt then`, `case img* then`): the case is taken when
  `glob_match(subject, pattern)` holds, in any program. `glob_match` is whether the whole text
  matches: `*` matches any run of characters, none included, `?` any one character, and every
  other character itself. A subject that is not a string matches no glob.
- `host_caps()` says what the host running the program can do: `["x64", "subprocess", "tcp",
  "tcp_remote", "fs"]` in a native build, and `["wasm"]` in a browser, which has none of
  those. `tcp_remote` means TCP can reach beyond this machine once the program declares
  `tcp_allow_remote()` (1.8).
- A native build is for Windows (a PE) or, with `--linux`, for Linux (a static PIE using no
  libc); a program prints the same on both. Where the systems differ, Linux gives:
  `cpu_cycles()` the thread's CPU time in nanoseconds (it has no cycle count for a thread),
  so compare two counts, not a count with a constant; the peak `exec_peak_memory` and
  `exec_measured` give, the child's peak resident set from `wait4` (not including the
  processes it starts); and `dir_files`' times in Windows' FILETIME steps, as on Windows.
  A path's separator is `/` alone. `os_target()` names the system a build runs on,
  `"windows"` or `"linux"`; a compiler builds for its own unless told otherwise.
- A statement that is only a value (a literal, a variable, operators on them, a list of them)
  prints that value, wherever it is, the program's last statement included: nothing takes its
  value. A call whose value nothing uses prints nothing, and a function's or closure's last
  statement is the value it returns, not printed.
- `not` binds more loosely than a comparison and more tightly than `and` and `or`: `not a == b`
  is `not (a == b)`, and `not a == b and c` is `(not (a == b)) and c`.
- Any expression followed by `(` on its line is called, as a closure held in a variable is:
  `make_adder(3)(7)`, `fs[0](x)`, `(|x| { return x })(1)`. A bare name followed by `(` calls
  the function or variable of that name, as before.
- An error found while building names the line of the statement it is in (`line 6: undefined
  variable nope`), and the lexer's own errors the line they start on: a string never closed is
  refused at the line where it opens. A string may run over several lines, and the lines after
  it keep their numbers. A number may have an exponent, and is then exact as any number written
  without one is: `1e3` is 1000, `2.5e-2` is 1/40, `4E+1` is 40.
- A stop says what went wrong in the program's terms: an exact number divided by an exact zero
  is `division by zero` (exit 74); an operation given a type it does not take names it (`this
  operation does not take a modint`, exit 70); running out of memory says so (exit 71); a value
  freed twice, a defect in the runtime, says so with an exit code of its own (69), apart from a
  call of a name nothing declares (72).
- The interpreter takes the runtime's declarations (each function's name and parameters; it
  runs the runtime's compiled functions themselves) from `self_hosting/build/
  v2_runtime_declarations.txt` when that file's key, each runtime file's name, size and time
  of writing, is the runtime's now, and otherwise parses the runtime and writes the file again
  (under a name of its own, then moved over the old). A start then takes about 0.3 s, where
  parsing the runtime took about 2.4 s.
- `program_path()` gives the path of the executable running the program, in full: the program
  itself when it is compiled, the interpreter when it is interpreted; `""` in a browser.
- A call to a name nothing declares compiles, and stops the program when it is reached, with
  `host fn 'NAME' not found`, the lines before it having run. This holds in every build,
  WebAssembly's included, whatever arguments the call passes. The compiler names each such
  name as it builds (`v2 warning: NAME is called, and nothing declares it`), so a typo is seen
  before the call is reached; the build still succeeds.
- A `let` has no block scope, so a loop's body that sets a name the loop's condition reads, from
  a value that does not read it, and then counts an inner loop with that name, loses the loop's
  own count. The compiler warns of each such loop in the program's own files (`v2 warning: FILE:
  line N: this loop's body sets NAME, ...`), naming the loop's line; the build still succeeds and
  the program runs as written. An inner loop that moves the shared index on (it reads the name it
  sets) is not warned of.
- `exec_capture` gives what the command wrote to standard output and to standard error.
- A child process inherits its own standard handles and nothing else this process holds: not
  the pipes another thread made for its own child, and not a socket. A program that spawns a
  long-running child and ends is seen to end at once by whoever captured its output, and its
  listening ports are free once it has ended. `is_alive(pid)` asks whether a process runs and
  changes nothing, so `wait(pid)` after it has said `false` still gives the exit code (on
  Linux it asks with `waitid` and `WNOWAIT`, which leaves the ended child to be waited for).
- A program named with no directory (`"cmd"`, `"git"`) is looked for in the directories in
  `PATH` alone, `.exe` added when the name has no extension: never first in the current
  directory or the running program's own, where Windows would look. A name that no directory
  in `PATH` holds does not start. A name with a directory in it is that file.
- `list_dir(path)` gives a directory's entries, sorted, a subdirectory's name ending in `/`. A
  path with no directory to read gives `[]`, as `read_file` gives `""` for a file it cannot
  read, and the program goes on; `file_exists` tells a missing path from an empty directory.
- `read_file` reads every byte of a file, whatever its size, and gives `""` for one it cannot
  open or read; a file cut short while it is read gives the bytes there were. `write_file` and
  `write_file_bytes` give `true` only when every byte was written and the file closed.
- A thread that the system cannot start stops the program, saying so, rather than giving
  `unit` as its result. A pipe that cannot be made is a program that cannot start:
  `exec_capture` gives `""`, as for any program that cannot start, and `exec_capture_io`
  stops the program.
- A path, command line or environment name given to the system that holds the character with
  code 0 stops the program before the system sees it: the system would read only the part
  before it, so `write_file("safe.txt" + chr(0) + ".tmp", ...)` would write `safe.txt`.
- `path_absolute(path)` gives the path in full, with `/` between its parts, or stops the program
  saying the system could not make it absolute; it never gives a wrong path. (Windows' ANSI
  calls, which the runtime uses, take no path longer than 260 characters.)
- `vfs_flush_to_disk(prefix, dir)` writes each virtual file under `prefix` to `dir` followed by
  its path, read with `/` and `\` as separators, `.` dropped and each `..` taking off the part
  before it. A path that would leave `dir`, or that names a drive or a stream (a `:` in a
  part), stops the program naming it, before any file is written.
- `try_rename_file(from, to)` moves a file over another, replacing it, and gives whether it
  moved; the system may refuse (the file it replaces is open elsewhere, or, in a browser, there
  are no files) and the program goes on. `rename_file` is the same, but a refusal stops the
  program.
- `make_directory(path)` makes the directory and any missing above it, and gives whether it is
  there afterwards.
- `cwd()` gives the directory the program runs in, in full, as `path_absolute(".")` does, and
  `set_cwd(path)` makes `path` that directory, giving whether it could (a browser has none to
  change, so there it gives `false`).
- The console a key at a time, for a line editor (`lib/line_edit.patlang`):
  `console_raw_enable()` stops the console echoing and waiting for a line, and gives the mode
  it had, to pass back to `console_raw_disable(old_mode)`; where standard input is not a
  console or terminal (a pipe, a file, a browser) it changes nothing and gives -1, and the
  caller reads a line at a time instead. `console_read_raw_byte()` gives the next byte typed, or
  -1 at the input's end. `console_echo_byte(b)` and `console_echo_str(s)` write to standard
  output with no line end after them. `console_set_utf8()` makes a Windows console read and
  write UTF-8 (a Linux terminal does already), and `console_enable_colors()` gives whether
  standard output takes ANSI colour sequences, turning them on in a Windows console.
- A pseudo-console, a program's console that this program types into (for testing the
  above with no person at the keyboard): `pty_start(program, args)` starts the program on a
  console 80 columns by 25 rows of its own (Windows' ConPTY; on Linux a pseudo-terminal from
  `/dev/ptmx`, its controlling terminal and its 0, 1 and 2), and gives the pty, or `[]` where
  there is none (a browser) or the program could not start. `pty_write(pty, text)` types
  text at it, giving whether all was written; `pty_read(pty)` gives what the console has
  shown since the last read, with its VT sequences, without waiting; `pty_wait(pty, ms)`
  waits up to `ms` for the program to end and gives its exit code, or -1 while it runs (its
  output is not read meanwhile); `pty_close(pty)` ends the program if it still runs, closes
  the console and gives what it showed that was not yet read. A program's last output can
  come after it has ended, since ConPTY draws what was written a moment later, so a
  transcript's end is what `pty_close` gives. The program starts with Ctrl+C on, as one a terminal starts does: on
  Windows, where whether a process ignores Ctrl+C is inherited with no call to ask it,
  `pty_start` turns it on in the calling process first. What a key gives differs as the
  systems' terminals do: Enter is 13 on Windows and 10 on Linux (the terminal's CR to NL),
  Backspace 8 and 127 (spec: `self_hosting/pty_selftest.patlang`).
- `dir_files(path)` gives a directory's files, each `[name, bytes, written]`, sorted by name:
  `written` is when the file was last written, in 100-nanosecond steps since 1601 (Windows'
  FILETIME), so the larger is the later. Subdirectories are left out, and a path with no
  directory to read gives `[]`, as for `list_dir`.
- `exec_peak_memory(program, args)` runs the program with the list of arguments and gives two
  things: what it wrote to standard output, followed by what it wrote to standard error if it
  exited non-zero, and its peak working set in bytes, or -1 where the system gives none.
- `exec_capture_io(program, args, input, timeout_ms)` gives the child its input a part at a time
  while it reads the child's output, so a child that writes more than a pipe holds before it
  reads its input does not wait on the program, nor the program on it. A timeout counts from the
  start, whatever the child is doing.
- `exec_measured(program, args)` runs the program and gives four things: what it wrote to
  standard output, what it wrote to standard error, whether it exited 0, and its peak memory
  in bytes (or -1): the most that it and every process it started committed between them.
- `cpu_count()` gives the machine's logical processors, at least 1. `cpu_times()` gives
  `[idle, busy]`, the processors' time since the machine started, summed over all of them, in
  milliseconds; how busy the machine was between two readings is in their differences.
  `memory_status()` gives `[total, available]`, the physical memory in bytes. Where the system
  gives no figures, as in a browser, `cpu_times` and `memory_status` give `[-1, -1]`.
  `memory_used()` gives the program's own committed private memory in bytes, `-1` in a
  browser: for a long-running program to report, and for a test of what it holds.
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
  about as n squared (40 goals in about 70 ms, 160 in about 1.1 s, 511 in about 12 s,
  compiled; it grew as n cubed, 511 taking 546 s, before a state's facts were found by value
  and a step's state was made only when the search took it).
- A plan's step is `[name, values, names]`: the action's name, its preconditions' variables'
  values as bound, in the order the preconditions first name them, and those variables'
  names. A value keeps its type: an int stays an int, a text holding a comma stays one value.
  `step_name(step)` and `step_values(step)` give the first two; `step_label(step)` writes the
  step as text, `build(X=house,Y=2)` (the name alone for an action with no variables), and
  `plan_labels(steps)` writes each. `plan`, `plan_in`, `plan_incremental`, `pursue` and
  `plan_with_state` give steps; `activate(steps)` calls each step's bound closure with its
  values as one list. (Steps were their labels, and `activate` split a label at its commas and
  equals signs, so a value holding either was cut apart and every value arrived as text.)
  `action_base_name(label)` and `action_label_args(label)` still read a label a program holds.
- Numeric fluents (PDDL 2.1): `fluent_set(name, value)` gives a fluent a number (or a number's
  text), in the world's own store. `action_add_numeric(name, preconds, numeric_preconds,
  add_effects, del_effects, numeric_effects, cost)` adds an action that also needs each
  `[fluent, op, value]` condition (`<` `<=` `>` `>=` `==` `!=`) to hold and applies each
  `[fluent, op, value]` effect (`=` `+=` `-=` `*=` `/=`); a value is a number, a number's text,
  or a variable the fact preconditions bind. A condition on a fluent with no value fails; an
  effect on one starts from 0; an instance whose effect divides by zero or reads an unbound
  variable is not applicable. `plan_numeric(goal_facts, numeric_goals)` plans to both, as
  `plan` does; a state is its facts and its fluents. Counting down from n takes time growing
  as n (2000 steps in about 0.6 G cycles, compiled). Fluents that can grow without bound can
  give states without end, and a goal none of them meets is then searched for without end.
- A virtual file is found by a hashed look-up: writing, reading or checking one takes about the
  same time however many files there are, and appending to one copies nothing it already holds,
  so n appends take time in proportion to n.
- A goal whose first argument is bound looks only at the rules whose head's first argument is
  that value or a variable, in the order they were added; following a chain of n facts takes
  time growing as n (1900 in about 0.4 s, compiled, where it took about 100 s).
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
- A logic variable is a value of its own, of type `logic_var`: `logic_var(name)` makes one, and
  a bare name that starts with a capital letter in a `rule` or `goal` declaration is the
  variable of that name. Two variables with the same name are equal, `to_s` of one is its name,
  and `is_logic_var(v)` tells one from any other value. Every string is a constant, whatever
  its first letter, in a declaration (`rule likes("Dave", X)`) and in every call
  (`rule_add`, `fact`, `solve`, `query`, `action_add`, `plan`): a name, a path or a code read
  as data matches only itself. (Before, a string starting with a capital was a variable, so a
  fact about `"Bob"` matched every query.)
- A store holds each ground fact (a rule with no body and no variables) once: adding a fact
  the store holds changes nothing.
- `solve_in(stores, pred, args)` solves against a store or a list of stores: a goal sees the
  rules of every store listed, store by store in the order listed and, within a store, in the
  order they were added. A rule's body goals are solved against the same stores, except a goal
  written `pred(args) from NAME`, which is solved against the store named NAME alone.
  `solve(pred, args)` and `query` solve against the default store and the contracts store.
- A search follows rules up to 2000 deep, as far as every target's stack goes (a browser's runs
  out between 2000 and 10000). A search that would go deeper, through a rule that leads back to
  itself or a longer chain, stops the program naming the goal, since an answer cut short would
  read as "no". (It stopped at 200 and gave the answers found so far, silently.) Planning has no
  limit: `plan` says there is no plan only when none exists.
- `solve_up_to(pred, args, n)` and `solve_up_to_in(stores, pred, args, n)` give the first `n`
  of the solutions `solve` and `solve_in` give, in the same order, and stop searching once they
  have them: asking whether a goal has a solution is `solve_up_to(pred, args, 1)`, one proof,
  where `solve` finds every one first. A search is depth first, each goal's rules tried in
  order and each proof carried through the rest of the body before the next is tried.
- Binding variables costs the same however many a search has bound: a rule body of 1600 goals,
  each binding a variable, is proved in 71 ms, and one of 800 in 33 ms. (A substitution was a
  chain searched from its newest binding for a variable not yet bound, so the same took 1.9 s
  and 0.5 s.)
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
from 0 to n - 1, and `mod_modulus(m)` gives n, each an `int` or a `bigint` (1.3).
`mod_reveal(m)` gives what `mod_value(m)` gives, and says the residue is meant to be public
(an AEAD's tag check, a signature's verdict): the constant-time check lists it rather than
reporting it (2.7). A modint
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
  converted. The constant-time check (2.7) is how this is tested. A modint modulo 2^k for k
  up to 64 costs about what an int does, being held as a word (2.1); nothing else about it
  differs from any other modint.

### 1.15 Worlds

A world is where a program's state lives: its named objects, its classes, the handlers
registered for events, the functions reached by name, its logic stores, actions and goals, the
contract facts recorded, and its virtual files. A program starts in a world of its own. A
program can make more, and run code in one, which then sees that world's state and none of
the caller's. A world isolates state, not authority: code in it can do whatever the program
running it can (files, processes, sockets, time), and a step budget bounds only interpreted
loops and calls.

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
- A modint whose modulus is 2^k, for k from 1 to 64, is held in the two
  words as a float is: its type word is class 15 with no heap bit and k in
  bits 40 to 46, and its data word is the residue. Every other modint is a
  heap block (`runtime/numbers.patlang`). This is the runtime's affair
  alone. Such a modint is the same modint to a program: its class, printing,
  `mod_value`, `mod_modulus`, equality, which operations stop the program,
  the time each takes (1.14) and its residue's secrecy to the constant-time
  check (2.7) are as they were. `vi_modint_word_form` holds what each engine
  printed before the change. The compiler does `+`, `-`, `*`, `band`, `bor`,
  `bxor`, `==` and `!=` on two of one modulus inline, a machine operation
  and a mask, and `rotl` and `rotr` are one runtime call. An add, an xor and
  a rotate on 32-bit modints cost about 19,000 cycles held as blocks and
  about 250 held as words, against about 60 on ints masked to 32 bits
  (`modint_cost_selftest`).
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
  the system in steps of 16 MB, only as needed: a small program commits
  about 18 MB, where steps of 256 MB made it 270 MB.
- A block's size is rounded up to a size class: 8-byte steps to 256 bytes,
  then four classes per power of two. A freed block up to an allocation
  chunk's size (1 MB) goes to a free list.
- A block larger than a chunk is memory of its own: taken from the system
  for it alone, as many pages as it needs with no size class's rounding,
  and given back when it is freed. A browser's memory only grows, so there
  it comes from the range as any other block does.
- **Each thread** has its own free lists and its own bump chunk, taken
  from the reservation with one atomic add. A thread allocates and frees
  on its own lists with no lock and no atomic.
- A block freed by another thread goes onto the freeing thread's lists.
  Past a threshold, a thread trades a batch of blocks with a shared pool,
  taking one lock per batch.
- Freed memory up to a chunk is never returned to the system; larger blocks
  are (above).
- Reference counts are atomic. Making them plain where the ownership
  summaries prove a value never leaves its thread is an allowed
  optimisation, not a requirement.

### 2.4 Contracts

- Every runtime function and every compiler stage states its contract
  with `require` and `ensure`: its ownership behaviour (2.2), and its
  representation invariants (2.1).
- A broken contract stops the program at the call that broke it, naming
  the contract.
- A program's own clauses, and the runtime's `require` and `assert` clauses, are checked in
  every build. The runtime's `ensure` clauses, which restate what its own code has just done,
  are checked when the build asks for them: `v2.exe SRC OUT --check-runtime` (with `--ir` or
  `--wasm` too). A file that declares `quiet_operators()` but is not one of the runtime's
  files is a program's file, and its ensures are checked. Checking every runtime clause made
  them over half of a build's time: 1.2 billion clause runs in a front-end build of the
  interpreter, most in the smallest, most called functions (`list_get`, `op_eq`, `list_len`);
  leaving out the runtime's ensures took that build from 36 s to 25 s.
- That policy is one setting, `v2_contracts_checked` in `contracts.patlang`, read in one place,
  the lowering of a clause. No contract and no other part of the compiler or runtime depends on
  it.

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
- An artefact is stored under its job's key: the SHA-256 of an encoding of everything
  the job's output depends on, in which each item says what it is and how long, so two
  different inputs never share a key and no input can be made to reuse another's
  artefact.
- A build leaves artefacts in place, and marks those it reuses as just used.
  `compile.patlang --evict KEEP_MB` removes whole jobs, least recently used first,
  until the store is no larger than that, reading the store with `dir_files` (no shell,
  so a directory's name is never a command). An evicted job is built again when next
  needed.
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
  a secret was stored in, is secret, and so is a value computed from a secret. A modint held as
  a word (2.1) is a secret word itself: the runtime makes one from a public integer through
  memory marked secret, and its type word, one literal for each k, tells the check it is
  that kind of modint. The check keeps the two kinds apart: a modint in a block has the one
  type word 4294967311, so a test of which kind a modint is (`rt_mod_is_word`) is decided for
  each, and neither's data word is taken for the other's. A secret raw word and a residue
  held in a value are two kinds of secrecy, and memory holding either is followed as such:
  a value read whole from a list keeps its residue as a residue. A raw word read where
  values hold residues may be one, so it is secret, except a block's header. The modulus,
  and what the runtime computes from the modulus alone, is not. A call is followed with its
  arguments' secrecy, so a function is reported only where a secret reaches it.
- **What is followed.** The check knows, for each value, the classes it may have and, for a
  bool or a small int, the values it may hold, and follows only the instructions those allow:
  a test of a modint's class does not lead it into the string or list code beside it. A
  modint is a secret word or points to a block holding a secret, so a value that is neither is
  not a modint. The
  runtime marks what the IR cannot show itself: where a modint's block is made, what is
  computed from the modulus, a residue leaving the class, and memory being freed or released,
  which reads only blocks' counts and headers and the type words of what they hold. A list's
  length, count and room, and an element's type word, are
  public too: they depend on how the list was used and on its elements' classes, never on
  what a residue is. A call whose argument may be of several classes is followed once for
  each kind (an int, a modint in a block, a modint held as a word, a value that holds values,
  anything else), each with the
  secrecy that kind can carry, so a callee's `require` rules out the kinds it does not take.
- **What is not known.** An element read from a list, a vec or another cell is known only as
  some value, of any class. Arithmetic on it may be string or list arithmetic as far as the
  check can tell, and a secret reaching that code is reported. A program settles an
  element's class by reading it through `mod_make(x, shape)`, whose `require` admits only
  integers and modints, as the `sha512` and `curve25519` packages (`packages/`)
  do.
- **What is reported.** A branch (`if`, `while`, `and`, `or`, `match`) deciding on a secret,
  except one whose one side stops the program; an address computed from a secret, as a list,
  string or memory index; `+`, `-`, `*`, `/`, `%` or unary `-` on a secret integer, whose time
  depends on whether the result leaves the `int` class; the machine's division on a secret; a
  secret passed to a closure call or an external function, which the check cannot follow; and
  `mod_value` or printing of a modint, where the residue leaves the class.
- **What is declared.** `mod_reveal(m)` (1.14) is a reveal the program says it means. It is
  listed, one line for each function that calls it with a secret
  (`declared: tag_matches reveals a residue through mod_reveal`), and is not counted: a
  program whose only places are declared ones passes, and the check ends
  `no value-dependent branch or access, and N declared reveals`. Its result is public.
- Each place is one line naming the function and what it does with the secret. With none it
  prints `v2: no value-dependent branch or access` and exits 0; with any it exits 1. While it
  runs, `self_hosting/build/v2_constant_time.NAME.progress`, for the source file NAME, says
  how far it has got. When it ends, `v2_constant_time.NAME.why` beside it gives, for each
  place, the chain of calls that brought the secret there, then every function followed,
  with its arguments' secrecy and classes and what it returns.
- The interpreter runs the same runtime routines, so the check of a program's modint
  operations covers both engines.
