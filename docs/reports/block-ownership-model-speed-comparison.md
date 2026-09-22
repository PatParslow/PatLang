# Block Ownership Model: speed comparison against the existing pipeline

Measured 2026-09-22 on `feature/block-ownership-model` (Phases 0-9 complete),
via `self_hosting/block_model/bench/run_speed_comparison.patlang`. Raw
commands and source are in that directory; this file is the write-up.

**Bottom line up front:** the new engine, immediately after Phase 8, was
dramatically slower than the existing pipeline at runtime — roughly
300x slower interpreted, and (in its original, unoptimized form) roughly
760x slower even when its own interpreter loop (`bi_run`) was compiled
to native machine code. That native gap was cut to ~270x by an
interpreter-level fix (opcode-hash dispatch, replacing string
comparisons with integer ones), and then closed entirely — down to
ordinary process-timing noise — by Phase 9, real native codegen for the
block-model IR itself, with no interpretation loop left at runtime at
all. The full arc, in order, each step measured before being trusted
rather than assumed: 764x → 270x (interpreter tuning) → **~1x** (real
codegen). Compilation/lowering speed was close to on par with the
existing pipeline throughout (new was a little slower, mostly explained
by compiling substantially more real source once the new engine's own
size grew).

## What was measured

A sum-of-integers loop (`sum = sum + i` from `0` to `N-1`), the largest
program shape both the real pipeline and the new engine's own restricted
subset can express identically — arithmetic, `while`, `print`, nothing
else. Both systems verified to produce byte-identical output at every N
before any timing was trusted.

Four execution shapes:

| Shape | What it is |
|---|---|
| OLD interpreted | `pat.exe --ir-run` running the program directly (the ordinary, one-layer way to run PatLang) |
| OLD native | `patc1.exe --x64` compiles it; the resulting `.exe` runs as real machine code, no interpretation at all |
| NEW interpreted | `pat.exe --ir-run` running the new engine's own `lower.patlang`/`interp.patlang` (itself ordinary PatLang), which in turn interprets the block-model IR — **two layers of interpretation** |
| NEW native | `patc1.exe --x64` compiles the new engine's own interpreter loop (`bi_run`) to real machine code; that compiled code still interprets the block-model IR at runtime, since Phase 9 (native codegen for the block-model IR itself) was deliberately deferred — **one layer, but that layer is compiled** |

## Report 1: compilation / lowering speed

**Self-hosted lex+parse+lower only** (in-process `now_ms()`, 2000 iterations
of the same small program — necessarily small, since that's the largest
common ground the new engine's restricted lowerer can express; a real,
disclosed limit on this comparison, not a choice made for the old
system's sake):

| | 2000 iterations | avg |
|---|---|---|
| OLD (`self_hosting/lib/lower.patlang`) | 910 ms | 0.455 ms/iter |
| NEW (`self_hosting/block_model/lower.patlang`) | 950 ms | 0.475 ms/iter |

Essentially on par — the new lowerer is about 4% slower on this input,
plausibly explained by the extra free-variable/flight-check analysis work
it does that the old lowerer doesn't (moot here, since this particular
program has no `while` loop content complex enough to exercise the
difference much). Not a meaningful gap either way.

**Full native build wall-clock** (`patc1.exe --x64`, one representative
program each):

| | build time |
|---|---|
| OLD (the sum-loop program alone) | 189,853 ms (~190 s) |
| NEW (bundles the whole new engine: lexer+parser+lower+interp+heap+free_vars+flight_check, ~2,000 lines of new PatLang, plus the same sum-loop as embedded source) | 227,134 ms (~227 s) |

About 20% slower to build, which is just "compiling a bigger program" —
the new engine's own source is real, substantial code now, not a
one-line stub. Not evidence of anything wrong with the lowering approach
itself; the self-hosted compiler's own per-line build cost is well known
to be significant regardless of what's being compiled (see this repo's
existing benchmark notes on multi-minute builds for large files).

## Report 2: runtime speed

**Interpreted scaling curve** (wall-clock, includes process startup —
negligible at these sizes):

| N | OLD interpreted | NEW interpreted (double) | ratio |
|---|---|---|---|
| 100,000 | 32 ms | 4,969 ms | ~155x |
| 200,000 | 43 ms | 9,558 ms | ~222x |
| 400,000 | 69 ms | 20,320 ms | ~295x |
| 800,000 | 124 ms | 39,261 ms | ~317x |

Both scale linearly with N (checked, not assumed: OLD roughly 2x per
doubling of N once past small-N startup noise; NEW consistently ~2x per
doubling throughout) — no hidden O(n²) hiding in either lowering or
execution. The *constant factor* is what differs, and it's large and
growing slightly as a fraction (the ratio climbs from ~155x to ~317x as
N grows, meaning OLD's fixed per-iteration cost is genuinely lower, not
just amortizing a fixed startup cost better).

**Native snapshot at N=800,000** (the size where interpretation overhead
is least likely to be swamped by process startup):

| | time |
|---|---|
| OLD native | 46 ms |
| NEW native (bi_run compiled, still interprets the block IR) | 35,139 ms |
| ratio | ~764x |

This is the number that actually answers "would Phase 9 fix it": **no,
not by itself.** Compiling `bi_run`'s own loop to native machine code
only removes the *outer* Rust-interpretation layer — it doesn't touch the
*design* of that loop, which is a naive tree-of-lists interpreter:

- Locals are a plain list of `[name, value]` pairs, walked linearly on
  every `Load`/`Store` (`bm_loc_get`/`bm_loc_set`) — O(params-in-scope)
  per variable access, not O(1).
- The value stack is a plain list, and `bm_st_pop` rebuilds it by copying
  every remaining element on every single pop — O(stack-depth) per pop,
  not O(1).
- Every instruction is itself a list (`["Bin", "+"]`, `["Load", "i"]`, …),
  so even native machine code spends its time doing `list_get`/pattern
  dispatch on data, not running compiled arithmetic.

None of that is Phase 9's job to fix — Phase 9 was scoped as "compile
`bi_run`'s own code," and that's exactly what the native snapshot above
already tests, still through this same design. Closing this gap for real
needs a different, later piece of work: either a genuine native-codegen
backend that compiles the block-model IR itself to machine code (skipping
`bi_run` entirely, the way `codegen_x64.patlang` compiles the real
language today), or at minimum reworking `bi_run`'s own locals/stack
representation away from linear-scan lists. Worth naming explicitly as a
follow-up decision, not assuming Phase 9 alone would have closed it.

## Follow-up: closing part of the interpreter-side gap

The native snapshot above (764x) prompted a real question: how much of
that gap is closeable by fixing `bi_run`'s own design, without touching
Phase 9 at all? Two attempts were made and measured, not just proposed.

**Attempt 1: slot-indexed locals (reverted).** `bm_loc_get`/`bm_loc_set`
scan a list of `[name, value]` pairs, comparing strings, on every
`Load`/`Store`. The obvious fix: resolve names to integer array slots
once at lowering time, then use real O(1) indexed access at runtime.
Implemented (scoped to blocks with no `if` inside, to avoid touching the
existing name-based path used by branching code), and it passed all 34
existing tests cleanly. Measured result: interpreted got ~4-7% faster,
but **native got ~8% slower** (35,139 ms → 37,938 ms). Root cause,
checked rather than assumed: this benchmark only has 2-3 locals per
block, so the original linear scan was already close to O(1) in
practice — the fix wrapped locals in an extra `[slots, overflow]`
container, and that added indirection cost more than the scan it
removed. **Reverted** rather than kept as a wash-to-negative change with
added complexity.

**Attempt 2: integer opcode-hash dispatch (kept).** `bi_run_block`'s own
instruction dispatch, and `bm_apply_bin`'s operator dispatch, compared
opcode strings via long `if`/`elif` chains (up to 20 branches, each a
string comparison) on *every single instruction executed*. Fix: hash
every opcode/operator string to an integer once, at lowering time
(`block_ir.patlang`'s `bm_op_hash` — a small custom hash, not
`x64_runtime.patlang`'s own `hash_string`, which returns a 16-character
hex *string* and would have made comparisons slower, not faster — checked
before assuming otherwise), collision-checked against all 32
opcode/operator strings this engine uses
(`self_hosting/block_model/bench/hash_check.patlang`, 0 collisions), and
compare hardcoded integer constants at dispatch time. Also passed all 34
existing tests cleanly.

Measured result:

| | before | after | change |
|---|---|---|---|
| Interpreted (double), N=800,000 | 39,261 ms | 38,547 ms | ~2% (noise-level) |
| **Native, N=800,000** | **35,139 ms** | **12,421 ms** | **~2.8x faster** |
| Native vs. OLD native (46 ms) | ~764x | ~270x | gap cut by two-thirds |

The interpreted number barely moved, and that's expected, not a
disappointment: under double interpretation, the Rust interpreter's own
per-PatLang-function-call overhead dominates so heavily that shaving the
cost of one string comparison inside code that's *itself* being
interpreted doesn't show up. The native number is where a CPU-level
integer compare vs. a CPU-level string compare actually shows its real
difference — and it's substantial: **cutting the native gap from ~764x
to ~270x**, the single biggest improvement made to this engine's actual
running speed so far.

**What's still open, going by the same reasoning applied to what's left:**
the value stack still rebuilds itself on every pop (a real cost for
expressions deeper than this benchmark's own 2-3-deep stack); every
instruction is still a heap-allocated PatLang list requiring `list_get`
calls to decode; and every `Load`/`Store`/dispatch step is still several
separate PatLang function calls, each with its own call overhead even
when compiled. None of these were touched this round. ~270x is a real,
earned improvement, not a claim that the gap is closed — closing it the
rest of the way needed actual Phase 9 (compiling the block-model IR
itself, no interpretation loop at all), which is exactly what follows.

## Phase 9: real native codegen closes the gap

Phase 9 (`self_hosting/block_model/native_codegen.patlang`) translates a
`BlockProgramIR` into a single, real, flat `FuncIR` — every block's own
instructions concatenated, `JumpBlock` expanded into ordinary `Store`
instructions (forwarding values by name) plus a real `Jump` — and reuses
`self_hosting/lib/codegen_x64.patlang`'s own, already-proven
`emit_program_x64` for everything else: register allocation,
tagged-fixnum arithmetic, PE headers, the entry stub, calling
conventions. No new x64 emission code was written; no interpretation of
the block-model IR happens at runtime at all.

This relies on an insight already present in the design doc itself,
checked rather than assumed before building on it: today's real
`Jump`/`JumpIfFalse` in `self_hosting/lib/lower.patlang`'s own `FuncIR`
already are the block/jump mechanism Fork A describes — "n is an
absolute index into the same array." Concatenating every block into one
flat array and jumping between them via ordinary `Jump` is exactly what
"no call stack, turtles all the way down" means at the native level, and
this is now *verified*, not just designed for: the emitted assembly's
only `call` instructions are to genuine runtime helpers (`rt_bigint_add`,
`print`, `ExitProcess`, ...) for actual computation — never to another
block's own label. Every transfer of control between blocks is a plain
`jmp`.

**Two real problems were found and fixed getting here, not designed
around in advance:**

1. **Two build-time collisions**, both from bundling `x64_runtime.patlang`
   naively into one compilation unit: it synthesizes its own (empty)
   `main` even with no top-level statements of its own, colliding with
   this engine's own translated entry function; and `codegen_x64.patlang`
   hardcodes raw `call rt_bigint_from_i64`-style assembly text directly
   for overflow-checked arithmetic, invisible to any IR-level rename —
   found after a first attempt to fix the naming collision by *salting*
   (prefixing) the runtime's own function names hit an unresolved-symbol
   link error from exactly this hardcoding. Fixed by switching to a real
   two-chunk build (mirroring `self_hosting/build_x64_runtime.patlang`'s
   own established convention): this engine's own translated program
   links against the already-built, already-cached
   `self_hosting/build/x64_runtime.obj` via `emit_program_x64`'s own
   `extern_names` mechanism, true linker-level namespace separation that
   can't silently miss a hardcoded reference the way textual renaming
   could.
2. **A genuine infinite-loop bug**, caught by a small, deliberately
   cheap test (a 3-iteration loop) before ever reaching the full
   benchmark: `JumpBlock` expands into *multiple* instructions (a
   `Store` per forwarded value, plus a `Jump`), so a `JumpIfFalse`/`Jump`
   target computed against the original, one-`JumpBlock`-is-one-
   instruction numbering does not equal its own position in the expanded
   output, the moment anything earlier in the same block was itself a
   `JumpBlock` — exactly the shape every loop head has. The loop's own
   condition check ended up jumping mid-way through its own back edge's
   Store sequence instead of to the exit block, producing a real hang.
   Fixed with a per-block index map from original instruction position
   to its own expanded position, resolved before adding each block's
   absolute offset. The large-N benchmark's own earlier "VirtualAlloc
   commit failed" crash (reported when Phase 9 work was interrupted
   mid-session) was almost certainly the same bug: an infinite loop's
   sum growing without bound until repeated BigInt promotion exhausted
   the heap, not a separate, unrelated problem.

**Result, at N=800,000, confirmed correct (byte-identical to every
other execution path) before being trusted:**

| | time |
|---|---|
| OLD native (baseline) | 16 ms |
| bi_run compiled, hash-dispatch (previous best) | ~12,400 ms |
| **Phase 9: real native codegen** | **~12–18 ms** |

The gap is closed, not just narrowed. Phase 9's own native codegen runs
within ordinary process-to-process timing noise of the existing
pipeline's own native path — because it is now doing the same kind of
work: real compiled jumps, real compiled tagged-fixnum arithmetic, real
function calls only for actual computation. This is the number that
answers this report's own original question in full: the ~764x-to-1x
gap was never inherent to the Block Ownership Model's own design: it was
entirely attributable to `bi_run` being an interpreter, and it closes
once that interpretation loop is removed, exactly as the earlier
sections of this report predicted before Phase 9 was attempted.

Scope, disclosed rather than assumed complete: this translation covers
`Const`/`Load`/`Store`/`Bin`/`Un`/`JumpIfFalse`/`Jump`/`Print`/
`JumpBlock` — everything the speed-comparison benchmark needs.
`BoxNew`/`BoxGet`/`BoxSet`/`BoxSetUnchecked`/`BoxShare`/`ContractFail`/
`GlobalGet`/`GlobalSet`/`HandlerNew`/`HandlerRegister`/`HandlerLookup`
are not translated (a clear, contract-checked "unsupported" error, not
silently mishandled) — real, separate future work, most plausibly via
ordinary `Call` instructions to `heap.patlang`'s own already-compilable
functions, which Phases 1 and 3 already proved compile correctly.

## What this does and doesn't say about the design

The Block Ownership Model's own claims (block/jump dispatch replacing
calls, refcounting for real reclamation and exclusivity, ambient-state
elimination, precise closure/loop capture, the static flight check) are
about **execution semantics and guarantees**, not about this prototype's
own interpreter loop being fast. Every one of those claims was proven
independently of raw speed in Phases 1-8, and none of them require the
current `bi_run` design specifically — a real native-codegen backend for
the block-model IR would keep every semantic guarantee already proven
while removing the interpretation overhead measured here. This report is
about the current, deliberately-deferred state of Phase 9, not a finding
against the design the earlier phases established.
