# Incremental / per-file compilation for the self-hosted compiler's own build

**Status (2026-10-22): proposed, not started.** Prompted by a real
observation during GitHub #222 follow-up work: a *trivial* 4-line
`--x64` program took ~7 seconds to compile, and the full Gen B
self-compile fixpoint (`./patc1.exe self_hosting/build/patc1_all.patlang
patc2.exe --x64`) regularly runs 20-30+ minutes. Both numbers are
dominated by work that has nothing to do with the size of the actual
target program -- see §1.

## 1. Why

Every `--x64` compile, no matter how small the target program, pays the
cost of lexing, parsing, and lowering the **entire** bundled self-hosted
runtime from scratch:

- `self_hosting/build_patc1.patlang` builds `patc1_all.patlang` (and the
  equivalent in-memory source for an ordinary `--x64` compile) by
  `read_file` + `expand_includes`-ing every `self_hosting/lib/*.patlang`
  file and **concatenating them into one text blob** (confirmed:
  `build_patc1.patlang` lines ~106-145). There is no per-file caching at
  this stage at all.
- That whole blob is tokenized once, parsed once into one AST, and
  lowered once (`bm_patc_lower`) into per-function IR. All three steps
  are O(total bundle size), run sequentially, every single time,
  regardless of whether a single line changed or nothing changed.
- Only **after** lowering does the pipeline become unit-granular:
  `x64_compile_unit.patlang`'s `x64_make_compile_unit` hashes each
  function's own lowered IR (`content_hash`, mixing in
  `x64_compiler_fingerprint()`) and `ensure_chunk_native` skips
  re-assembling any unit whose `.chunkbin` is already cached. That cache
  is real and already proven (measured 10.9x on the parallel-assembly
  mechanism itself, GitHub #197/#80's own write-ups) -- it just starts
  one stage too late to help with the dominant cost.

So the architecture already embraces exactly the caching philosophy this
plan proposes extending backward -- **content-hash-keyed, fingerprint-
guarded, skip-if-unchanged** -- it just currently only covers assembly,
not lex/parse/lower. This plan is about moving that same discipline
earlier in the pipeline, not inventing a new one.

## 2. The real blocker: lowering isn't actually per-file independent today

The tempting-sounding version of this plan ("cache each file's own
lowered IR, only re-lower what changed") runs into a genuine, confirmed
architectural fact, not a hypothetical: `bm_is_fn_bound_name`
(`self_hosting/block_model/lower.patlang:554`) resolves every call site
to either an ordinary `Call` or a generic `CallHost` by checking
membership in `bm_fn_bound_names` -- **one global list, built from the
whole merged program's function declarations before lowering begins.**
A file that calls a function defined in a *different* file needs that
global name set to already exist. Lowering today is correct specifically
*because* it never lowers a file in isolation.

This means "cache lowered IR per file" cannot be a direct port of the
assembly-stage cache -- it needs one new piece: a **global function
symbol table** (names + arities, not bodies) built once per compile from
a cheap scan of every file's own top-level headers. That scan is itself
nearly free relative to full lowering (it is exactly the same shape as
`x64_make_compile_unit`'s own header-reading, just file-level instead of
function-level) -- so the real design question is Fork C below, not
whether this is possible at all.

## 3. Decisions needed

### Fork A -- cache granularity for lex/parse

**Leaning: per-file**, matching `self_hosting/lib/*.patlang`'s own
existing unit of organization and `deps.manifest`'s own file-level
dependency declarations (`docs/plans/stage-37b-dependency-aware-library-
inclusion.md`) -- reuse that infrastructure rather than inventing a
second one. Per-function would be finer-grained but lexing/parsing don't
have the same natural "statement belongs to exactly one function"
boundary tokenizing operates on; staying file-level keeps Phase 2 (below)
simple and already covers the dominant cost if lex+parse, not lower, is
what Phase 1's measurement shows dominates.

### Fork B -- cache key and invalidation

**Decided, reusing precedent exactly**: `(file content hash,
x64_compiler_fingerprint())` -- the same two-part key
`ensure_chunk_native` already uses for `.chunkbin`. The fingerprint
MUST cover the lexer+parser's own source (so editing `lexer.patlang` or
`parser.patlang` invalidates every cached AST, not just the file that
changed) -- this is the same class of correctness requirement CLAUDE.md
already states generally ("no unprincipled fudge factors... a cache
invalidation bug could silently compile against stale output"); get it
wrong once and compiles silently use a stale AST after a lexer/parser
change, which is strictly worse than today's always-correct-but-slow
baseline.

### Fork C -- what exactly gets cached: tokens, AST, or lowered IR

**Needs real measurement before deciding (Phase 1).** Three candidate
cache boundaries, increasing in both payoff and risk:

1. **Tokens only.** Lowest risk (parsing is usually cheap relative to
   lexing for this grammar), lowest payoff.
2. **Per-file AST**, post-parse. Matches Fork A's chosen granularity
   exactly; needs no new global-symbol-table machinery since lowering
   still runs on the full merged AST exactly as today -- this is the
   safe, incremental first real win.
3. **Per-file lowered IR.** Highest payoff (skips lowering entirely for
   unchanged files), but requires the new global symbol-table scan from
   §2 AND requires proving that a file's own lowering output genuinely
   depends only on (its own AST, the global symbol table) and nothing
   else file-order-dependent (`bm_synth_counter`-style synthesized names
   are a candidate hazard here -- see CLAUDE.md §7's own prior audit of
   cross-worker synthesized-name counters; this is a NEW instance of the
   same class of question, cross-*file* rather than cross-*thread*, and
   needs its own explicit audit before Phase 3, not an assumption that
   the thread-safety audit already covered it).

### Fork D -- where the cache lives

**Leaning: alongside the existing `.chunkbin` cache directory**
(`self_hosting/build/`), same `cache_dir` parameter `ensure_chunk_native`
already threads through -- one cache location, one cleanup story, not
two.

## 4. Phased roadmap

- **Phase 1 -- measure, don't assume.** Instrument
  `build_patc1.patlang`'s own pipeline (and the equivalent path an
  ordinary `--x64` compile takes) to log wall-clock time for: read+concat,
  tokenize, parse, lower, per-unit assembly (should already be fast on a
  warm `.chunkbin` cache), link. Run once on the full `patc1_all.patlang`
  bundle and once on a trivial single-file program, matching this
  session's own real numbers (~7s trivial, ~20-30min full) so the
  before/after comparison in later phases is against real data, per
  CLAUDE.md's performance-validation discipline -- do not skip this step
  even though the qualitative culprit (lex/parse/lower) seems obvious;
  confirm the split between lex+parse vs lower specifically, since that
  split decides whether Phase 2 alone is enough or Phase 3 is needed.
- **Phase 2 -- per-file AST cache (Fork C, option 2).** Lowest-risk real
  win: cache each file's tokens+AST keyed per Fork B, reuse on a hit,
  still lower the full merged AST exactly as today. No new global
  symbol-table machinery. Verify: re-run this session's own two timing
  points from Phase 1 with a warm cache; confirm a single-character
  comment edit in one file still forces exactly that file's re-parse and
  nothing else (a deliberate RED case before GREEN, per standing TDD
  discipline); confirm full regression suites
  (`native_codegen_check.sh`, `refcounted_heap_native_check.sh`,
  `thread_safety_check.sh`, the language spec suite, a real Gen B
  fixpoint) stay green with the cache warm AND cold.
- **Phase 3 -- per-file lowered-IR cache (Fork C, option 3), gated on
  Phase 1/2's real numbers actually showing lowering itself as a
  significant remaining cost.** Build the cheap global symbol-table
  scan from §2, audit synthesized-name independence across files (Fork
  C's own named hazard), then cache lowered IR per file. This is the
  phase that would meaningfully shrink Gen B/C fixpoint time, not just
  ordinary small-program compiles.
- **Phase 4 (aspirational, not promised) -- true incremental linking.**
  Extend the existing per-function `.chunkbin` assembly cache's own
  philosophy one level further: skip re-linking files whose own output
  units are all still cache-hits. Not scoped in detail here; revisit
  only if Phases 1-3 show link time is itself a meaningful remaining
  cost once lex/parse/lower stop dominating.

## 5. What this plan is explicitly NOT about

- **Output-binary size/tree-shaking** (`docs/plans/stage-37a/37b/37c-*.md`)
  -- that work is about which host functions and library code get
  *embedded in a compiled program*, a completely different concern from
  how long *the compiler itself* takes to compile anything. Do not
  conflate the two; a smaller output binary says nothing about faster
  compiles, and this plan's caching does not reduce what gets bundled
  into any `--x64` output.
- **Gen A's own bootstrap.** `patc1.exe`'s original build (via `rustc` +
  `codegen.rs`'s native Rust-source emission) never goes through this
  pipeline at all and is out of scope.
- **Changing the Block Ownership Model's own lowering semantics.** This
  plan is about *when and how often* `bm_patc_lower` runs on a given
  file's AST, never about changing what it produces.

## 6. Risk: this makes correctness bugs quieter, not just absent

Every cache layer added here is a new way for a compile to silently
produce output from stale input instead of failing loudly. The existing
`.chunkbin` precedent already pays for this risk with a fingerprint that
must be kept exhaustive; the same discipline applies to every cache this
plan adds, and the fingerprint's own completeness (which source files
actually affect a given cached artifact's validity) must be re-verified
whenever a new file is added to `self_hosting/lib/`, not assumed stable
forever. A cache that is merely *fast* and sometimes wrong is a worse
outcome than today's slow-but-always-correct baseline.
