# Plan: dynamic heap growth for x64-compiled programs

**Status: deferred design, not scheduled — written down after issue #89's
follow-up work hit the current fixed-reservation heap's ceiling twice in
one session (512MB -> 1.9GB -> 2.1GB) and NASM itself refused a third
bump to 3GB.**

## Context

Every PatLang program compiled via `--x64` links against
`x64_runtime.patlang`'s own heap allocator (`rt_heap_alloc`): a single
atomic bump allocator over a **fixed-size `.bss` reservation**
(`g_heap resb <N>`, `N` a literal baked into `codegen_x64.patlang` at
two places that must match by hand). It never frees, and it has a hard
ceiling: once `used + requested > N`, `rt_heap_alloc` prints "heap
exhausted" and calls `os_exit(97)` — there is no way to get more memory
short of recompiling the entire toolchain with a bigger `N`.

This has already needed raising twice this session (`patlang-x64-argv-
frame-size-corruption-issue89` memory has the full trail): 512MB, then
1.9GB (when patc2.exe's own self-assembly needed more), then 2.1GB (when
compiling the compiler's own ~27k-line source bundle missed 1.9GB by 32
bytes). A third attempt, 3,000,000,000, didn't even assemble — see
`codegen_x64.patlang`'s own comment on `g_heap` for what happened: NASM's
multi-pass optimizer does not handle a `resb` count that overflows
signed 32-bit (2,147,483,647) consistently, producing "label ... changed
during code generation" errors on completely unrelated `.bss` labels
whose offsets swung by billions between passes. That's a real, separate
ceiling *on top of* the "pick a big enough number" problem: even before
the toolchain outgrows whatever `N` is currently set, `N` itself cannot
safely exceed ~2GB via this mechanism at all.

`rt_heap_alloc`'s own header already names the real fix as a known,
deliberately-deferred gap: "a second VirtualAlloc'd region once this one
fills, or a proper segmented heap." This plan works that out concretely.

## Design: reserve large, commit incrementally

The standard technique for "I don't know how much memory I'll need, but
I don't want to pay for it until I do" on Windows is exactly what
`VirtualAlloc` is for: `MEM_RESERVE` claims a range of **virtual address
space** with no physical or page-file cost at all, and `MEM_COMMIT` (on
an already-reserved range) is what actually backs pages with memory,
incrementally, only as needed. This replaces the current ".bss reserves
`N` bytes, loader zero-fills lazily, but there's still a hard ceiling at
`N`" scheme with ".bss goes away entirely for the heap; reserve
something enormous (say 64GB) once at startup, commit in chunks as the
bump pointer advances." Reserving 64GB costs nothing until touched, same
"zero-fill-on-demand" property the current design already relies on for
its cost argument — this just removes the need to guess `N` at all,
since 64GB is far beyond anything a real compile will need.

### 1. New primitive: `VirtualAlloc`

Add `"VirtualAlloc"` to `x64_default_import_spec()`'s `KERNEL32.DLL`
list (`x64_build.patlang`). Calling convention is the same as every
other imported WinAPI function already used here (`GetEnvironmentVariableA`
in `x64_os_getenv_asm` is a good template: RCX/RDX/R8/R9 for the four
args, `sub rsp, 32 / and rsp, -16` before the call for the required
shadow space + stack alignment, restore `rsp` after):

```
VirtualAlloc(lpAddress, dwSize, flAllocationType, flProtect) -> LPVOID
```

Two call shapes needed: reserve (`lpAddress=NULL`, `flAllocationType=
MEM_RESERVE (0x2000)`, `flProtect=PAGE_READWRITE (0x04)`) and commit
(`lpAddress=<specific address within the reserved range>`,
`flAllocationType=MEM_COMMIT (0x1000)`, same protect). A single
`x64_os_virtualalloc_asm(kind)`-style helper parameterized by
allocation-type immediate, mirroring how `x64_os_bind_listen_asm`/its
`_try_` sibling already share structure via near-verbatim variants
rather than one over-parameterized function (this file's own established
convention, per `x64_os_connect_try_asm`'s header), covers both.

### 2. One-time reservation, lazily, using the pattern this file already has

`rt_heap_alloc` needs the reserved base address and current commit
watermark somewhere — two new `.bss` qwords (`g_heap_base`,
`g_heap_committed`) replacing the current `g_heap resb <N>` block
entirely (no more giant static reservation at all).

The reservation itself must happen exactly once, before any thread's
first allocation. This codebase already has the exact primitive for
"run this initialization exactly once, other threads spin until it's
done": `g_scratch_cs_ready`'s 3-state lazy-init (`x64_scratch_lock_asm`'s
own header, `codegen_x64.patlang` ~line 2543) — 0 = never started, 1 =
in progress, `lock cmpxchg` to claim the 0->1 transition, the winner does
the real work and sets 2, everyone else spins reading the flag until it
sees 2. `g_heap_base` gets the identical treatment: `g_heap_reserved_ready`
flag, winner calls `VirtualAlloc(NULL, 64GB, MEM_RESERVE, PAGE_READWRITE)`,
stores the returned base into `g_heap_base`, sets the flag to 2.
`rt_heap_alloc`'s very first action becomes "ensure reserved" (this
lazy-init check) before doing anything else.

### 3. Committing more, without a new lock

This is the part that could have gone wrong and doesn't need to:
`MEM_COMMIT` on a page that's already committed is documented as a
harmless no-op, not an error. That means concurrent commit doesn't need
coordinating with a lock at all — reuse the ALREADY-EXISTING atomic
fetch-add for `used` exactly as today, and after it, compare the new
`used` against `g_heap_committed`; if it's past the watermark, call
`VirtualAlloc(g_heap_base + g_heap_committed, chunk, MEM_COMMIT,
PAGE_READWRITE)` for a generously-rounded-up chunk (e.g. round up to the
next 256MB boundary past what's actually needed) and then update
`g_heap_committed` (a plain store is fine here too — if two threads both
commit overlapping ranges because they both saw a stale watermark, both
calls succeed harmlessly per the no-op-on-already-committed guarantee,
and the store that "loses" only sets the watermark to a technically-stale
value that a LATER allocation's own comparison will simply commit past
again; nothing is lost or corrupted, just an occasional redundant syscall
under real contention).

### 4. Exhaustion becomes "ran out of virtual address space," not "hit an
arbitrary constant"

`rt_heap_alloc`'s exhaustion check changes from `used + size >
mem_heap_size()` (a compile-time constant) to checking `VirtualAlloc`'s
own return value on the commit call (NULL on failure — genuinely out of
address space or page file, an extremely high bar at 64GB reserved).
The "heap exhausted (X requested, Y reserved)" message becomes
essentially unreachable in practice; keep it as the fallback path for
that genuine failure rather than removing it.

## What this removes

- The two-places-must-match-by-hand `N` literal (`mem_heap_size()`'s
  `mov rax, N` and `g_heap resb N`) goes away entirely — no more manual
  bumping, no more NASM-signed-32-bit ceiling on how big `N` can even be.
- `codegen_x64.patlang`'s comment trail documenting three successive
  bumps (512MB/1.9GB/2.1GB) becomes historical, not a pattern that needs
  a fourth entry next time something bigger gets compiled.

## What this does NOT do

- No compaction, no freeing, no garbage collection. Still a bump
  allocator — this only removes the artificial ceiling on how far it can
  bump, not the "never reclaims anything" property. A genuinely
  long-running process that allocates unboundedly would still eventually
  exhaust 64GB of address space (or physical memory/page file, once
  enough of it is actually committed) — just a much, much higher bar
  than 2.1GB, appropriate for a compiler process that runs once and
  exits, not a design intended for an always-on server.
- No change to `rt_list_push`/`rt_list_set_functional`'s own no-
  refcounting, in-place-when-possible semantics — this is purely about
  where the BYTES those functions write ultimately live, not how list
  values alias.

## Files to touch (when implemented)

- `self_hosting/lib/x64_build.patlang` — add `VirtualAlloc` to
  `x64_default_import_spec()`.
- `self_hosting/lib/codegen_x64.patlang` — new `x64_os_virtualalloc_asm`
  (or reserve/commit variants), remove `g_heap resb N` and the
  `mem_heap_size()` constant, add `g_heap_base`/`g_heap_committed`/
  `g_heap_reserved_ready` `.bss` qwords, wire the lazy-reserve pattern.
- `self_hosting/lib/x64_runtime.patlang` — `rt_heap_alloc`'s own body:
  ensure-reserved check, commit-on-demand after the existing atomic
  fetch-add, updated exhaustion path.
- `self_hosting/lib/runtime_rs.patlang` — NOT touched: this is x64-
  codegen-specific (native codegen's own Rust runtime template has no
  fixed-heap-ceiling concept at all; it uses real Rust allocation).

## Verification (when implemented)

- `self_hosting/tests/x64_asm/run_tests.sh` (10/10) and
  `run_full_runtime_test.sh` (real 94k-line runtime + bench_fib) must
  still pass unchanged.
- Re-run the actual motivating case: `patc1.exe` compiling its own
  ~27k-line bundle via `--x64` (`patc2.exe`), then `patc2.exe` compiling
  the same bundle again (`patc3.exe`) — the exact fixpoint check this
  plan exists for — and confirm it no longer depends on a hand-tuned `N`
  at all, i.e. it would keep working if the bundle grew substantially
  larger without any further constant-bumping.
- A small deliberate stress program that allocates well past 2.1GB (the
  current ceiling) to confirm the commit-on-demand path is actually
  exercised, not just present in the source.
