# Block Ownership Model: speed comparison against the existing pipeline

Measured 2026-09-22 on `feature/block-ownership-model` (Phases 0-8 complete),
via `self_hosting/block_model/bench/run_speed_comparison.patlang`. Raw
commands and source are in that directory; this file is the write-up.

**Bottom line up front:** the new engine, as it stands after Phase 8, is
dramatically slower than the existing pipeline at runtime — roughly
300x slower interpreted, and still roughly 760x slower even when its own
interpreter loop is compiled to native machine code. Compilation/lowering
speed is much closer (roughly on par, new is a little slower). Neither
number is a surprise once you know what Phase 9 does and doesn't cover,
but the *size* of the native-vs-native gap is worth being precise about
rather than waving at "it's a prototype."

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
