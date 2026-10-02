# PatLang IR bootstrap (GitHub #25, Piece 2 + #196)

`bootstrap_interp.py` is a standalone Python interpreter for PatLang's own
IR (the list-shaped instruction format `lower_program()` in
`self_hosting/lib/lower.patlang` produces). It's a direct Python port of
`self_hosting/lib/interp.patlang`'s own meta-circular interpreter design
(same stack machine, same instruction set), scoped to the host-function
surface the self-hosted compiler's own source
(`self_hosting/build/patc1_all.patlang`) actually needs while driving a
`lower`/`emit_x64` compile.

`ir_to_py.py` (GitHub #196) is a second way to run the same IR: instead of
tree-walking it, it compiles the IR into real Python source -- a
straight-line Python function per basic block, wired by a small `pc`
trampoline, so there's no per-instruction tag dispatch at runtime. Both
share `bootstrap_interp.py`'s own host-function implementations (`call_host`,
`interp_bin`, etc.), including its live-progress reporting.

**Why this exists**: proves out the claim that PatLang's bootstrap chain can
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
no PatLang binary is needed at all. Interpreted (works everywhere, slower):

```
python bootstrap_interp.py patc1_all.ir <input.patlang> <output.exe> --x64
```

Compiled (GitHub #196 -- translate once, then run, substantially faster for
a large input like the compiler's own bundle):

```
python ir_to_py.py patc1_all.ir patc1_all_compiled.py
python -c "
import sys; sys.path.insert(0, '.')
import bootstrap_interp as interp, patc1_all_compiled as compiled
import json
ir = json.load(open('patc1_all.ir'))
state = interp.HostState(['<input.patlang>', '<output.exe>', '--x64'], ir[2])
compiled.FUNCS[ir[1]](['<input.patlang>', '<output.exe>', '--x64'], state)
"
```

`build_frontend_ir.py` bundles just `lexer.patlang`/`parser.patlang`/
`lower.patlang` (expanding each file's own includes relative to its own
directory) and lowers it to `frontend.ir`, for exercising just the compiler
frontend without needing the whole bundle -- used by `test_frontend_
compiled.py` and `bench_frontend.py` below.

Either way mirrors `patc1.exe`'s own top-level CLI shape exactly (the IR
being interpreted/compiled, in this case, IS the compiler itself --
`self_hosting/build/patc1_all.ir`, lowered from `self_hosting/build/
patc1_all.patlang`) -- so the same invocation compiles an ordinary user
program, or, handed its own source's `.ir`, produces a completely
independent copy of the compiler itself, with zero PatLang/Rust tooling
anywhere in that second step.

**Confirmed working** (re-verified 2026-10-02, after several months of
drift -- see below): `python bootstrap_interp.py patc1_all.ir
hello_bootstrap.patlang out.exe --x64` produces a genuinely correct native
`.exe` (output byte-identical to `pat --ir-run`'s own), driven entirely by
Python with zero PatLang/Rust tooling in the compile step itself. Takes
37.7 minutes for that trivial 4-line program today -- slow in absolute
terms, considered acceptable for now (this is a bootstrap path for a fresh
machine, not the everyday build loop); see GitHub #196 for further
speed-up work if that changes.

## What re-verification found (2026-10-02)

This bootstrap hadn't been exercised since 2026-07-31. Re-checking it found
real drift, now fixed:

- **`self_hosting/build_patc1.patlang`'s own bundling** left a stray,
  unexpanded `include "mailbox.patlang"` line in `patc1_all.patlang`
  (from `signals.patlang`, added 2026-09-19) -- harmless for the normal
  compile path, fatal for `patc1.exe lower`'s own `expand_includes` step.
  Fixed: each bundle file's own includes are now expanded relative to its
  own directory before concatenation.
- Several `bootstrap_interp.py` primitives were missing or genuinely wrong
  (not just unimplemented) -- `hash_string` used 32-bit FNV-1a instead of
  the real 64-bit algorithm `hosts.rs` uses (so any fingerprint comparison
  against a file the real interpreter wrote always failed), `read_file`
  silently stripped CRLF (Python's own universal-newline translation,
  unlike Rust's byte-verbatim read), `%` floored instead of truncating
  toward the dividend's sign, `to_num` crashed instead of falling back to
  0 on Unit/None. Fixed, each checked against `hosts.rs`'s real behavior.
- **The dominant cost was a genuine O(n^2) bug, not just interpretation
  overhead**: `list_push`/`list_set` copied the whole list on every call
  instead of mutating in place, exactly reintroducing a failure mode
  `self_hosting/lib/x64_compile_unit.patlang`'s own `x64_chunk_to_bin`
  already documents fixing on the real backends (GitHub #75). Fixed by
  mutating in place, matching native x64's own already-shipped behavior.
  This took the trivial 4-line test from "900M+ instructions, still
  running after 15+ minutes, rate actively collapsing" to "completes in
  37.7 minutes with a steady rate."

Live progress reporting (`Progress` in `bootstrap_interp.py`, checked from
*inside* the real instruction/block loop, not just declared outside it) is
what made the O(n^2) bug diagnosable at all -- it showed the per-item rate
collapsing from 668K/s to 34K/s as the accumulator grew, the textbook
signature, rather than just "it's slow, no idea why." It writes to
`bootstrap/compile_status.json`, readable by anything else at any time
while a run is in progress.

## Scope, honestly

Implements: core (list_get/list_len/list_push/list_set/type_of/bit_*),
strings_ext, collections_handles (vec_*/sb_*/str_intern/sc_*), files (incl.
read_file_bytes/write_file_bytes for raw binary I/O -- a PE image or
machine code can't round-trip through a UTF-8 PatLang String), io_misc
(incl. getenv), math, the VFS driver (vfs_exists/read/write/delete/list --
an in-memory dict, never persisted; some bundled code checks these even
when the "fs" driver is what actually gets used), a minimal real object
system (class_def/new/get/set_var/send, including the generic `send(recv,
"push", field, val)` built-in -- genuinely needed, since the compiler's own
source declares real classes and uses this for append-without-aliasing),
and process lifecycle (spawn/wait/is_alive/kill/exec_capture -- needed for
the parallel nasm/gcc invocations the compiler's own object cache uses).

**Not implemented**, deliberately: the logic/GOAP engine (rule_add/solve/
goal_def/pursue/...), real TCP networking (tcp_listen/tcp_connect/...), and
`register_event_handler` (a documented no-op -- the compiler's own build-
progress instrumentation registers a handler this synchronous, single-shot
process never needs to actually fire). All three exist as CODE inside
`interp.patlang`'s own dispatch table (part of the bundled compiler
source), but that code path is only reached if the compiler's own
`interpret` subcommand is invoked at runtime, or an external process
actually queries a running build's status -- compiling a program never
calls into either. A real gap to fill only if this bootstrap path is ever
asked to also run `patc1 interpret` standalone, or support live external
status queries.
