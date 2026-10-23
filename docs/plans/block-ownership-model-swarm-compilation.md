# SwarmCompile: artefact-based incremental/parallel compilation on top of BOM

**Status (2026-10-22): proposed, not started.** Distilled from a design
specification the project owner provided
(`PatLang_Swarm_Lowering_Approach.docx`, "PatLang Swarm Lowering and
Compilation — Implementation specification for a local development
agent"), translated here into this repo's own file references, existing
test suites, and plan-doc conventions. **Phase 0 (§5) is the only
authorized next increment, and only once GitHub #222 is fully closed and
committed** -- nothing in this document should be started before then.
Nothing below is implemented yet.

## 0. Relationship to existing plans

- **Generalizes and supersedes** `docs/plans/block-ownership-model-
  incremental-compilation.md` (written earlier the same session, scoped
  narrowly to caching lex/parse/lower for the self-hosted compiler's own
  `patc1_all.patlang` build). That doc's Fork A-D and Phase 1-2 are a
  strict subset of this one's §5 Phase 0-3 -- keep the narrower doc as a
  worked example of *why* this is worth doing (it has this session's own
  real timing numbers: ~7s for a trivial program, 40+ minutes for the
  full bundle, both dominated by whole-bundle lex/parse/lower), but treat
  THIS document as the actual plan of record going forward.
- **Builds on** `docs/plans/block-ownership-model.md` and `block-
  ownership-model-implementation-plan.md` -- this proposal's entire
  "ownership-explicit block graph" stage (§3.6-3.8 below) assumes BOM's
  existing block/continuation lowering (`bm_patc_lower`,
  `self_hosting/block_model/lower.patlang`) as its starting
  representation, not a replacement for it.
- **Distinct from** `docs/plans/general-refcounting.md` -- that plan is
  about *runtime* reference counting of values a compiled PROGRAM
  manipulates. This plan is about *compile-time* caching/parallelism of
  the COMPILER's own work. The two share vocabulary (ownership, refcount-
  like fixed-point propagation) by deliberate design -- the source spec
  states PatLang compilation should "mirror the language design it
  encourages" -- but operate on completely different objects.

## 1. Central proposition (from the source spec, unchanged)

Treat a PatLang compilation as a distributed fixed-point computation over
owned semantic artefacts. A well-structured PatLang program already
exposes its state topology through parameters, closures, receiver
objects, and narrow capability-bearing objects (not ambient mutable
globals). The compiler should derive its own work topology from that same
explicit dependency/ownership topology, rather than imposing an unrelated
scheduling scheme on top.

## 2. Two ownership systems that must never be conflated

| System | Question answered | Already exists in this repo as |
|---|---|---|
| **Program ownership** | Who owns/may access a *runtime value* the compiled program manipulates? | `rc_inc`/`rc_dec`, `bm_alloc`/heap.patlang's refcount header, the Box/String/List work from `general-refcounting.md` |
| **Compiler-work ownership** | Which *worker* may transform/publish a *compilation artefact*? | Does not exist yet -- `x64_compile_unit.patlang`'s `ensure_chunk_native`/`.chunkbin` cache is the closest existing precedent (see §4) |

A worker may exclusively own the task of lowering some function while
that function's own body manipulates a runtime value that is merely
`shared`. Keep these two notions textually and representationally
distinct everywhere (types, diagnostics, variable names) -- the source
spec calls this out as a hard requirement, not a style preference, and
this codebase already has a precedent for exactly this kind of
accidental conflation causing real bugs (CLAUDE.md §7's own audit of
`__vars`-based counters raced across `parallel_map` workers -- that is
literally "compiler-work state accidentally sharing identity with
something that looked like program state").

## 3. Architectural outcome, mapped onto this repo's actual pipeline

Source units -> syntax regions -> resolved declarations -> typed semantic
regions -> canonical core regions -> control-flow fragments ->
ownership-explicit block graphs -> compilation islands -> target-specific
blocks -> relocatable fragments -> deterministic executable

Mapped onto what exists today:

| Spec stage | Current implementation | Status |
|---|---|---|
| 3.1 Source acquisition | `build_patc1.patlang`'s `expand_includes` + concatenation into `patc1_all.patlang` | Exists, NOT artefact-ized (whole-blob, no caching -- this is exactly `block-ownership-model-incremental-compilation.md`'s own subject) |
| 3.2 Skeleton/parsing | `tokenize`/`parse_program` (`self_hosting/lib/lexer.patlang`, `parser.patlang`) | Exists, whole-program only |
| 3.3 Declaration/name resolution | `bm_fn_bound_names` global list (`self_hosting/block_model/lower.patlang:554`, `bm_is_fn_bound_name`) | Exists as the ONE required global barrier -- see §6 Fork B |
| 3.4 Typing | PatLang has no static type system today | Not applicable; skip in the near-term phases |
| 3.5 Canonical desugaring | Partial, inside `bm_patc_lower`'s own statement handling | Exists, not separated into its own artefact stage |
| 3.6 Control-flow formation | `bm_lower_while`/`bm_lower_if_with_nested_while`/continuations (the exact code this session's GitHub #222 fix touched) | Exists; this IS the "ownership-explicit block graph" stage already, just not artefact-wrapped |
| 3.7 Closure/escape analysis | `bm_fv_stmt_list`, `bm_lower_closure_expr` | Exists |
| 3.8 Ownership transfer | `bm_nc_insert_string_rc_decs`/`bm_nc_insert_list_element_incs`/the dominance passes from `general-refcounting.md` Phases 2-4 | Exists, framed as dominance analysis rather than explicit transfer-function fixed-point -- see §6 Fork D |
| 3.9 Compilation islands | `x64_make_compile_unit`/`CompileUnit` -- **already function-granularity, already content-hashed** | **Closest existing match to the whole spec** -- see §4 |
| 3.10 Target lowering/fragments | `ensure_chunk_native`'s `.chunkbin` (`ChunkImage`: code bytes, relocations, externs) | Exists and already proven (10.9x measured speedup on parallel assembly, GitHub #197/#80) |
| Deterministic assembly | `x64_pe_link.patlang`'s `x64_link` | Exists, sequential, not yet derived from stable-sort-then-hash ordering explicitly (see §6 Fork E) |

The practical reading of this table: **this codebase already has a real,
working, measured instance of the spec's target architecture at exactly
one stage** (function-level compilation islands + content-addressed
relocatable fragments, assembled deterministically). The entire thrust of
this plan is extending that same discipline to the stages *before* it
(source acquisition through ownership-transfer generation), which today
are one monolithic, uncached, whole-program pass.

## 4. Existing precedent worth copying deliberately

`x64_compile_unit.patlang`'s `CompileUnit` class is already most of an
`ArtefactEnvelope`:

```
content_hash = name + "_" + x64_content_hash(json_stringify(to_json_value(func_ir))) + "_" + x64_compiler_fingerprint()
```

This already does exactly what the spec's §5 "Stable identity and
canonicalisation" demands: canonical payload hash, derived from content
not worker identity/timing, mixed with a compiler-version fingerprint so
a compiler change invalidates every cached fragment. `ensure_chunk_native`
already implements the spec's "candidate becomes visible only after
validation" rule in its simplest form (the cache write only happens after
`x64_assemble_chunk` succeeds). `x64_assemble_unit_batch`'s own doc
comment already states the exact numbers the spec's §15 metrics table
asks for (10.9x speedup, measured against real contention). Every later
phase below should be graded against whether it holds itself to this same
standard, not a lower one.

## 5. Decisions needed (genuinely undecided for THIS codebase)

### Fork A — Unit of work for the pre-lowering stages

The spec recommends file-level skeleton parsing, function-level body
resolution. **Decided, matching `block-ownership-model-incremental-
compilation.md`'s own Fork A**: file-level for lex/parse (matches
`self_hosting/lib/*.patlang`'s existing organization and
`deps.manifest`), function-level for everything from control-flow
formation onward (matches `CompileUnit`'s existing granularity exactly).

### Fork B — The one unavoidable global barrier

`bm_fn_bound_names` requires a whole-program function-name table before
ANY statement can be lowered (Call vs CallHost resolution). The spec's
§6.3 names exactly this pattern ("short canonical barrier: collect
declarations in parallel, commit one symbol index, then resolve
independently"). **Needs a design, not yet decided**: should this symbol
table be built from a cheap header-only scan (fast, but means every
compile still touches every file at least once) or should it itself be
cached per-file and merged (same two-level caching the spec describes
generally)? Lean toward the cheap-scan version first (Phase 2 below) --
it is already nearly free relative to full lowering, and caching it adds
its own invalidation-correctness burden for a stage that isn't the
bottleneck Phase 1's measurement is expected to find.

### Fork C — Where ownership-transfer analysis actually needs cross-function visibility

The spec's §6.8 describes a graph work-list fixed point "at joins." Right
now, `general-refcounting.md`'s dominance-based decrement insertion is
explicitly SINGLE-BLOCK / single-function (confirmed throughout that
plan's own phases). **Needs investigation, not yet decided**: does any
existing refcounting pass actually need to see another function's body
to make a correct decision, or does it only need that function's own
*signature* (does it consume/borrow/retain each parameter -- a summary,
not a body)? If signatures suffice (the spec's own preferred design,
§6.4's "explicit signatures are valuable boundaries"), ownership-transfer
analysis can be genuinely per-function-cacheable; if some pass secretly
needs callee bodies, that pass needs to be found and either given an
explicit summary-based replacement or merged into a bigger island per the
spec's own "merge strongly coupled regions" rule.

### Fork D — Reframe dominance passes as transfer summaries, or leave them as-is

Related to Fork C: the spec wants `OwnershipTransfer {consumes, produces,
borrows, retains, releases, mutates_exclusively, invalidates, escapes}`
as an explicit, cacheable, per-function artefact. Today's dominance
passes (`bm_nc_insert_string_rc_decs` et al.) compute something
equivalent implicitly, inline, every time, with no serializable
intermediate form. **Decided: defer this reframing to Phase 5+** -- it is
real, valuable work, but changing a proven, tested mechanism's internal
representation purely to make it cacheable is exactly the kind of
premature-generalization risk CLAUDE.md's own engineering-discipline
section warns against; do it only once Phase 0-4's measurements show
ownership-transfer computation is itself a meaningful fraction of total
time, not on the assumption that it must be.

### Fork E — Deterministic assembly ordering

`x64_link` today assembles chunks in whatever order `chunks` arrives in
(the caller's own list order), not yet the spec's §10 "section class,
exported symbol identity, function identity, canonical block traversal,
then content hash as tie-breaker." **Needs a decision**: is today's order
ALREADY stable (e.g., because the caller always builds `chunks` in a
fixed, deterministic order derived from source order) or merely
accidentally stable? This needs a direct check (two compiles of the same
input, diff the object/PE bytes) before Phase 3 can claim determinism as
a property rather than an assumption.

## 6. Phased roadmap (adapted from the source spec's Phase 0-8)

Each phase below keeps the source spec's own exit criteria but grounds
them in this repo's actual test suites and files.

- **Phase 0 — Baseline and instrumentation.** Identify current lowering
  entry points (`bm_patc_lower`, `x64_make_compile_unit`,
  `ensure_chunk_native`, `x64_link`) and every mutable global compiler
  state they touch. Add timing/size metrics for: read+concat, tokenize,
  parse, lower, per-unit assembly, link (this directly continues
  `block-ownership-model-incremental-compilation.md`'s own Phase 1
  measurement work). Capture baseline parity using the existing suites:
  `native_codegen_check.sh`, `self_hosting/block_model/
  refcounted_heap_native_check.sh`, `thread_safety_check.sh`, the
  language spec suite, and a real Gen B/C self-compile timing. **Exit
  criterion**: a repeatable baseline, committed, with real numbers for
  every stage above -- not estimates.

  **Progress (2026-10-22): the global-state identification half is
  done** (read-only survey, done opportunistically while a Gen B
  self-compile was running in the background and could not safely be
  rebuilt/retimed yet -- see below). The instrumentation/timing half is
  still pending. `get("__vars", ...)`/`set_var(...)` keys actually
  touched by `self_hosting/block_model/lower.patlang`,
  `self_hosting/lib/x64_compile_unit.patlang`, and
  `self_hosting/lib/codegen_x64.patlang`:

  | Key | Touched by | Scope / risk for Fork A-D |
  |---|---|---|
  | `bm_fn_bound_names` | `lower.patlang` (read at `bm_is_fn_bound_name`, written once after the declaration-collection pass) | **The** required global barrier -- Fork B is entirely about this key |
  | `bm_class_registry` | `lower.patlang` | Whole-program class table; read during member-access lowering |
  | `bm_ct_blocks_by_name` | `lower.patlang` | Per-class block table, same whole-program-visibility shape as the registry above |
  | `bm_closure_blocks` | `lower.patlang` | Accumulates synthesized closure blocks; written incrementally during lowering, read back at program assembly time |
  | `bm_uses_box` | `lower.patlang` | **Whole-program flag** ("does any function anywhere use Box") consulted by `bm_lower_member_access` to pick a codegen strategy -- a genuine cross-function dependency by design, not an accident; any per-function caching scheme (Fork C/D) must treat this the same way it treats `bm_fn_bound_names` |
  | `bm_current_fn` | `lower.patlang` | Set/read per-function, for diagnostics -- looks safely function-scoped (reset on entry) but not yet proven race-free if lowering ever runs on multiple functions concurrently |
  | `bm_budgeted_depth` | `lower.patlang` | Push/pop nesting counter for `Budgeted` blocks -- looks function-scoped |
  | `bm_synth_counter` | `lower.patlang` | **Already flagged by CLAUDE.md §7** as "not currently reachable from a parallel call site... re-check if that ever changes" -- Phase 5/6 (parallelizing lowering itself) is exactly the change that section warned about; this counter needs the same per-unit-local-counter fix GitHub #197 already applied elsewhere (not a new problem, a known fix pattern to reapply) |
  | `__x64_compiler_fingerprint` | `x64_compile_unit.patlang` | Set once before any parallel work starts, read-only after -- matches the "read-only broadcast state is fine" pattern CLAUDE.md §7 already documents as safe |
  | `__x64_build_port` | `x64_compile_unit.patlang` | Already audited and confirmed safe by CLAUDE.md §7(b)'s own correction (only ever touched from sequential/parent-thread code) |
  | `__x64_extra_float_func_names` | `codegen_x64.patlang` | Needs the same "set once before parallel work, read-only during" check as the fingerprint above -- not yet verified |
  | `tls_counter_next("xa_id")` / `tls_counter_next("x64_cv")` | `x64_asm.patlang`, `codegen_x64.patlang` | Compiler-work-level uniqueness counters (label/captured-value IDs), NOT the GitHub #222 follow-up runtime-level primitive -- under Gen A these resolve to `hosts.rs`'s genuinely-per-OS-thread `TLS_COUNTERS`; worth noting for Fork C/D that Gen A's semantics here (per-thread) and the native x64 runtime's own new implementation (single global counter, see `x64_runtime.patlang`) are deliberately different in a way that's fine for uniqueness but would matter if SwarmCompile ever needed genuine per-worker isolation rather than just race-freedom |

  **Net reading for Fork B/C/D**: `bm_fn_bound_names` and `bm_uses_box`
  are the two keys that are *genuinely, by-design* whole-program in
  scope (not just accidentally global) -- any artefact/caching design
  must treat both as inputs to every per-function lowering job's cache
  key, not just the function's own AST. `bm_synth_counter` is the one
  confirmed future hazard once lowering itself parallelizes (Phase 5/6),
  with an already-known fix shape to reuse. Everything else surveyed
  looks function-scoped or safely broadcast-only, but none of the
  "looks safe" rows above have been proven under actual concurrent
  access yet -- that proof is Phase 4's own audit job, not something to
  assume from this read-only pass.

  Timing/instrumentation remains explicitly deferred until a Gen B/C
  self-compile isn't actively running (rebuilding `patc1.exe` while a
  background compile is using it is unsafe, and concurrent CPU
  contention would make any timing numbers collected right now
  meaningless anyway).
- **Phase 1 — Artefact envelopes and stable identities.** Introduce a
  typed artefact-identifier/transformation-version concept, generalizing
  `CompileUnit.content_hash`'s existing pattern. Wrap ONE existing stage
  (recommend: per-file AST from Fork A) without changing its semantics;
  prove identical input produces identical identity across repeated
  local runs.

  **Done and proven (2026-10-22), via an isolated worktree, not yet
  merged into the main tree.** Built in `self_hosting/swarm_compile/`
  (new directory; `self_hosting/block_model/lower.patlang`,
  `self_hosting/lib/codegen_x64.patlang`, and `self_hosting/lib/
  x64_runtime.patlang` confirmed untouched):
  - `artefact.patlang` — `SwarmArtefact` envelope wrapping
    `CompileUnit.ensure_chunk_native`'s existing output (content hash =
    the SAME `content_hash` -- function-IR JSON hash folded with
    `x64_compiler_fingerprint()` -- that `.chunkbin` already uses, per
    §4's own observation that this was the closest existing precedent).
  - `job_queue.patlang` — one-worker `ready -> claimed -> candidate ->
    validated -> committed` (or `failed`) state machine. `job_id` is the
    unit's own content hash, never assignment order. Validation
    re-derives the hash independently and round-trips the `ChunkImage`
    through the existing binary cache codec before committing -- this is
    real validation, not a rubber stamp, though it was not yet proven to
    actually REJECT a bad candidate (no negative-path test built yet --
    flagged explicitly as a Phase 2 gap, not silently skipped).
  - `phase1_demo.patlang` — driver proving the whole thing end to end on
    `self_hosting/block_model/spec_fixtures/closures_basic_reference.
    patlang` (an existing `native_codegen_check.sh` fixture, 3 source
    functions + closures, 10 real compile units after block-model
    lowering expands closures into their own synthesized functions).

  **Results**: the swarm-queued path and the direct/sequential
  `--x64` CLI path produced **byte-identical executables** (`cmp`
  confirmed), reproduced across two fully independent OS processes with
  separate cache directories (so the second run genuinely rebuilt its
  own 10 `.chunkbin` files rather than reusing the first run's cache).
  All 10 artefact ids/hashes matched exactly, same order, across both
  runs. `native_codegen_check.sh` still 57/57 (expected, since nothing
  existing changed -- run anyway, per standing practice).

  **Phase 2 recommendation from this slice** (not implemented):
  do NOT reach for in-process `parallel_map`/`thread_spawn` for the
  "run" step -- CLAUDE.md §7 already documents a confirmed `__vars`-
  table race in exactly this codegen path, and `x64_compile_unit.
  patlang`'s own `build_native` already abandoned in-process worker
  threads for assembly in favor of spawning a separate OS process per
  job for exactly this reason. The claim/validate/commit state machine
  built here needs no change for that -- `swarm_validate`/`swarm_commit`
  already only look at a candidate's own declared identity and its
  on-disk artefact, never who produced it or when. Add a timing harness
  BEFORE adding a second worker (10 functions is too small for queue
  overhead to be measurable either way) -- the real test corpus is the
  self-hosted compiler's own full bundle (~534 compile units per
  `build_native`'s own existing comments, ~1.5s/unit), where a
  multi-worker win or loss would actually be visible.

  **Not yet done**: merging this worktree's new files into the main
  tree (git branch `worktree-agent-a3661055edffbf86b`) -- held pending
  the project owner's own review and GitHub #222's own work finishing
  first, per this document's own top-level status note.

  **Measurement done (2026-10-22), at real scale, superseding the
  "measure before granularity" precondition from the recommendation
  above.** The literal ask (measure against the full `patc1_all.
  patlang` bundle) was blocked twice by a real, pre-existing bug --
  `patc1_main.patlang`'s own top-level `program_funcs`-filtering loop
  hits the SAME bug family as GitHub #222 (a sibling `__loop_exit_N`
  case, in `main` itself, which can't be excluded from the measurement
  without excluding the whole bundle) -- confirmed genuine (not a hang)
  via CPU-time-vs-wall-clock accounting (~98% utilization for the full
  ~2.2h lowering cost, both attempts). Substituted `self_hosting/lib/
  x64_asm.patlang` (72 real compile units, genuine production code, not
  a toy fixture) after finding and working around a SECOND, previously
  undocumented bug along the way -- `bm_patc_lower` synthesizes a
  corrupted `main` (another function's body, wholesale) for a source
  unit with zero top-level statements, now tracked as GitHub #225,
  distinct from #222/#223/#224.

  **Results, two independent full runs, both from a cold cache:**

  | | Run 1 | Run 2 |
  |---|---|---|
  | DIRECT total (72 units) | 33,840ms | 35,044ms |
  | SWARM total | 42,680ms | 48,529ms |
  | Overhead (swarm vs. sum of its own run+validate+claim+commit) | 25.3% | 25.0% |
  | Cross-pass delta (swarm vs. direct) | +26% | +38% |
  | Validate fraction of swarm total | 25.3% | 25.0% |
  | Claim+commit total cost | ~1-2ms (negligible) | ~1-2ms (negligible) |

  Claim/commit are genuinely free (sub-millisecond bookkeeping, as
  expected). **Validate is the entire overhead story** -- it's the full
  `x64_chunk_to_bin`/`x64_chunk_from_bin` round-trip plus two
  `json_stringify(to_json_value(...))` calls over the ChunkImage's
  byte-array-heavy payload, consistent with this project's own already-
  documented history of `json_parse`/`json_stringify` being costly on
  byte-dense structures (the exact reason `x64_compile_unit.patlang`'s
  own chunk cache moved off JSON originally). Excluding one explained
  20-25x outlier unit (a function calling `tls_counter_next`, which this
  backend doesn't have a real fast-path for outside its normal bootstrap
  context), ordinary units show validate costing **~40% of the
  underlying transformation's own cost**, not a rounding error.

  **Correctness, proven at 72 real functions, not just Phase 1's 10-unit
  toy fixture**: direct-linked and swarm-linked executables are
  byte-identical to each other AND byte-identical across both
  independent runs. Both run correctly.

  **Direct answer to Phase 1's own open question ("is the overhead
  negligible, proportional, or dominating"): proportional, and not
  small.** At single-worker scale this is a real, consistent ~25-38%
  wall-clock tax, almost entirely attributable to `swarm_validate`'s
  JSON round-trip -- not a queue-scheduling-overhead problem (claim/
  commit are free), a VALIDATION-cost problem. **Revised Phase 2
  precondition**: a second worker needs to buy back at least ~25-38%
  just to break even before any real parallelism gain shows up, so
  cheapening `swarm_validate` (e.g. replacing the full JSON round-trip
  with a raw byte-length + lightweight checksum comparison, or making
  the full round-trip check sampled/opt-in rather than per-unit) is now
  the FIRST thing to do, before worker count, not an optional follow-up.
- **Phase 2 — Local job queue, sequential execution.** Route the wrapped
  stage through an explicit claim/validate/commit queue with exactly one
  worker; keep the direct call as fallback and parity oracle. This
  mirrors `block-ownership-model-incremental-compilation.md`'s own
  Phase 2 almost exactly, just generalized to the job-queue abstraction
  rather than a bespoke per-file cache.
- **Phase 3 — Relocatable function/island fragments, made explicit.**
  Formalize what `CompileUnit`/`ensure_chunk_native` already do into the
  spec's own `CompiledFragment` shape (imports, exports, relocations,
  stack effect, ownership summary) -- most of this is already present
  informally in `ChunkImage`; this phase is about making it a named,
  validated contract rather than an implicit one. Resolve Fork E here.
- **Phase 4 — Parallel local code generation.** This already exists
  (`x64_assemble_unit_batch` via `parallel_map`) -- this phase is "audit
  it against the spec's own race/retry/stale-lease/duplicate-result test
  list" rather than building it from scratch. Re-run `thread_safety_
  check.sh` as part of this audit, and extend it if the spec's fault-
  injection list (§14) finds gaps the current 5 scenarios don't cover.
- **Phase 5 — Progressive swarm lowering.** Move control-flow formation,
  closure summaries, and ownership-transfer generation (Fork C/D's
  decisions) behind artefact jobs. Function-level granularity stays
  default.
- **Phase 6 — Declaration/resolution islands.** Resolve Fork B. Skeleton
  discovery + canonical symbol-index commit, then parallel body
  resolution against the frozen index.
- **Phase 7 — Caching and speculation.** Persistent cache keyed per §11's
  formula (canonical input, imported contracts, ownership contract,
  transformation version, language feature set, target spec, opt
  policy) -- note this is a STRICT SUPERSET of what `x64_compiler_
  fingerprint()` already captures for `.chunkbin`; extending that same
  fingerprint discipline backward is most of the work.
- **Phase 8 — Optional multi-process workers.** Not scoped until Phases
  0-7 are mature. Transport carries the same typed contracts; no
  alternative semantic path.

## 7. First concrete development slice (unchanged from the source spec, repo-grounded)

Per the spec's own §18: function-level x64 fragment production and
deterministic assembly through a one-worker job queue, using a small
existing multi-function program with at least one closure or ownership-
sensitive value as the test case (a `general-refcounting.md` spec
fixture, e.g. `native_list_rc_element_cascade.patlang`, is a good
candidate -- it already exercises closures/ownership AND already has a
known-correct baseline to diff against). The slice is complete only when
the executable is assembled from independently validated fragments
through the new queue, not merely when functions compile on different
threads -- this repo already HAS the "compile on different threads" part
(`x64_assemble_unit_batch`); the slice must demonstrate the artefact/
validation/commit discipline around it, which is the actual new thing.

## 8. Anti-patterns (from the source spec, kept verbatim — they apply directly)

- Creating one task per tiny block without measuring overhead first.
- A universal mutable compiler context passed into workers (this
  codebase already has the cautionary tale: `__vars` itself, and
  CLAUDE.md §7's three-shape audit of what breaks when a worker touches
  it).
- Workers allocating final addresses or globally-ordered identifiers
  (exactly what Fork E must rule out for `x64_link`).
- Publishing unvalidated worker results to dependants.
- Using completion order to order diagnostics, sections, symbols, or
  blocks.
- Treating a proxy-global object as proof of independence when every
  method may mutate the whole object.
- Inferring dependencies by searching strings after lowering rather than
  recording semantic edges (this codebase has direct, confirmed scars
  from exactly this shape — `list_contains_str`'s own linear-scan cost
  being the dominant factor in an earlier "~100-second compile"
  regression, per `x64_pe_link.patlang`'s own header comment).
- Adding speculative work before invalidation/assumption tracking are
  correct.
- Removing the legacy sequential oracle before adequate parity coverage
  exists.
- Claiming distributed-compilation success when only a thread pool was
  added around otherwise-monolithic lowering.

## 9. What this plan is explicitly NOT about

- Adding a static type system to PatLang (the spec's §6.4 typing stage
  has no current equivalent and is out of scope until/unless that
  exists).
- Changing BOM's own lowering semantics (§3.6-3.8 above describe
  *wrapping* `bm_patc_lower`'s stages in artefact/job machinery, never
  changing what they compute).
- Reducing output-binary size/tree-shaking (`docs/plans/stage-37*.md`) --
  a different concern, as already stated in `block-ownership-model-
  incremental-compilation.md` §5.
- Gen A's own `rustc` bootstrap, which never goes through this pipeline.
