# PatLang IR bootstrap (GitHub #25, Piece 2)

`bootstrap_interp.py` is a standalone Python interpreter for PatLang's own
IR (the list-shaped instruction format `lower_program()` in
`self_hosting/lib/lower.patlang` produces). It's a direct Python port of
`self_hosting/lib/interp.patlang`'s own meta-circular interpreter design
(same stack machine, same instruction set), scoped to the host-function
surface the self-hosted compiler's own source
(`self_hosting/build/patc1_all.patlang`) actually needs while driving a
`lower`/`emit_x64` compile.

**Why it exists**: proves out the claim that PatLang's bootstrap chain can
be started on a fresh machine with *no* PatLang or Rust tooling installed
at all -- just a language that's already nearly universal (Python), plus
NASM and a linker (already the only external dependencies `--x64` has).

## Usage

A `.ir` file is produced once, on any machine that already has PatLang,
via:

```
patc1.exe lower some_program.patlang some_program.ir
```

That `.ir` file is then a portable, plain-JSON artifact -- from here on,
no PatLang binary is needed at all:

```
python bootstrap_interp.py patc1_all.ir  <input.patlang> <output.exe> --x64
```

This mirrors `patc1.exe`'s own top-level CLI shape exactly (the IR being
interpreted, in this case, IS the compiler itself --
`self_hosting/build/patc1_all.ir`, lowered from
`self_hosting/build/patc1_all.patlang`) -- so the same invocation compiles
an ordinary user program, or, handed its own source's `.ir`, produces a
completely independent copy of the compiler itself, with zero PatLang/
Rust tooling anywhere in that second step.

**Confirmed working**: `python bootstrap_interp.py patc1_all.ir patc1_all.patlang out.exe --x64`
produces a genuinely functional native compiler in about a minute,
verified by using that output to compile and correctly run further test
programs (matching every other execution path this project already
cross-checks against).

## Scope, honestly

Implements: core (list_get/list_len/list_push/list_set/type_of/bit_*),
strings_ext, collections_handles (vec_*/sb_*/str_intern/sc_*), files,
io_misc, math, a minimal real object system (class_def/new/get/set_var/
send -- genuinely needed, since the compiler's own source declares real
classes), and process lifecycle (spawn/wait/is_alive/kill/exec_capture --
needed for the parallel nasm/gcc invocations the compiler's own object
cache uses).

**Not implemented**, deliberately: the logic/GOAP engine (rule_add/solve/
goal_def/pursue/...), and real TCP networking (tcp_listen/tcp_connect/...).
Both exist as CODE inside `interp.patlang`'s own dispatch table (part of
the bundled compiler source), but that code path is only reached if the
compiler's own `interpret` subcommand is invoked at runtime -- compiling
a program never calls into it. A real gap to fill only if this bootstrap
path is ever asked to also run `patc1 interpret` standalone.
