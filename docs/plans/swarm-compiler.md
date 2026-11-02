# Swarm compiler: a second, artefact-graph compiler alongside patc1

**Status (2026-10-26): proposed, not started.** Plans an implementation of
`PatLang_Swarm_Lowering_Approach.docx` (the same specification already
distilled into `block-ownership-model-swarm-compilation.md`) as a **new
compiler driver** built beside `patc1`, rather than as a retrofit of
`patc1`'s own pipeline. `block-ownership-model-swarm-compilation.md`
remains the record of the specification's mapping onto this repo, its
Phase 0 global-state survey and its Phase 1 measurements; this document
is the implementation plan that follows from them.

**Update (2026-11-02):** the compiler and runtime are to be written again
as a new version (`memory-design-review.md`, section 6, decision 5), built
in this plan's shape from the start instead of retrofitted around `patc1`:
pure stage jobs with no `__vars`, declaration-derived names, recorded
registrations, per-function ownership summaries as contracts, and a
behavioural parity gate in place of byte parity with `patc1`. See
`memory-design-review.md` section 7. The phases below describe the
retrofit and stand as the record of that approach and its measurements.

## 0. Relationship to existing plans

- **`block-ownership-model-swarm-compilation.md`**: source of the stage
  mapping (its §3), the `__vars` survey (its Phase 0) and the Phase 1
  prototype results. Its Forks B-E reappear below as concrete decisions.
- **`contract-bounded-object-compilation.md`**: the language-side
  complement. This compiler needs no language change to work; contracts
  would later sharpen ownership summaries and give object-level effect
  boundaries (§8).
- **`swarm-implementation-note.md`**: expressiveness
  and contract precision; what it changes for this compiler is in §8a.
- **`general-refcounting.md`**: unaffected. The swarm compiler runs the
  same `native_codegen.patlang` passes per function, so every refcounting
  fix lands in both compilers at once.
- **Phase 1 prototype**: `self_hosting/swarm_compile/{artefact,job_queue,
  phase1_demo,phase1_bench,diag_*}.patlang`, built 2026-10-22 in the
  worktree `.claude/worktrees/agent-a3661055edffbf86b` and never
  committed there; copied into the main tree unchanged on 2026-10-26.
  They predate the #222-#226 fixes and have not been re-run since.

## 1. Why a new driver rather than a retrofit

`patc1`'s front end is whole-program by construction:

- `expand_includes` splices every file into one ~2.4M-character string
  (`self_hosting/build/patc1_all.patlang`), which is then tokenized,
  parsed and lowered in one pass.
- Lowering keeps program-wide state in `__vars`: `bm_fn_bound_names`,
  `bm_class_registry`, `bm_ct_blocks_by_name`, `bm_closure_blocks`,
  `bm_uses_box`, `bm_synth_counter` (survey in the swarm plan, Phase 0).
- Code generation then reads program-wide facts such as
  `bm_nc_program_has_any_closures`.

Retrofitting artefact boundaries into that pipeline means changing every
stage of the only working compiler at once. A separate driver keeps
`patc1` untouched as the **parity oracle** the specification requires,
and gives a clean place to put the coordinator, ledger and job model.

"New compiler" here means a **new driver, artefact layer and job model**,
not a reimplementation. Reused unchanged, called per unit instead of per
program: `lexer.patlang`, `parser.patlang`, `syntax_dsl.patlang`,
`block_model/lower.patlang`'s lowering functions, `native_codegen.patlang`,
`codegen_x64.patlang`, `x64_asm.patlang`, `x64_pe_link.patlang`,
`x64_runtime.patlang`, and `x64_compile_unit.patlang`'s `CompileUnit`/
`.chunkbin` cache, which is already the specification's
`CompiledFragment` in all but name. New: the coordinator, the ledger,
the binary artefact codec, the worker entry point, and the refactors
that let lowering run per declaration against explicit inputs (§2, J5).

## 2. The pipeline as job kinds

| Job | Unit | Inputs | Output artefact | Reuses | Cheap validation |
|---|---|---|---|---|---|
| J1 source | file | path | `SourceUnit` {bytes hash, include edges} | `includes.patlang` (edge extraction only, no splicing) | file hash matches; every include edge resolves |
| J2 dsl-env | program (barrier B0) | all `SourceUnit`s | `DslEnv` (frozen `syntax` definitions) | `sdsl_extract_syntax_defs` | defs list deterministic (sorted by declaring file, then position) |
| J3 parse | file | `SourceUnit`, `DslEnv` | `FileAst` | `expand_syntax_dsls_with`, `tokenize`, `parse_program` | every token consumed or diagnosed |
| J4 symbols | program (barrier B1) | all `FileAst` top-level headers | `SymbolIndex` {function names, classes, class blocks} | the declaration-collection half of `bm_lower_program` | no duplicate definitions; deterministic order |
| J5 lower | declaration | its AST, `SymbolIndex` | `DeclBlocks` {blocks, synthesized closures, summary} | `block_model/lower.patlang` | every block terminates; every JumpBlock target exists |
| J6 facts | program (barrier B2) | all `DeclBlocks` summaries | `ProgramFacts` {uses_box, has_any_closures, dispatch-by-name roots} | the whole-program checks in `native_codegen.patlang` | OR/union of summaries, recomputed independently |
| J7 nc | call root | its blocks, `ProgramFacts` | `FuncIR`s | `native_codegen.patlang` | jump targets in range; params match |
| J8 unit | function | `FuncIR`, runtime names | `.chunkbin` | `CompileUnit.ensure_chunk_native` (unchanged) | existing cache key + chunk decode |
| J9 link | program | all chunks in stable order | executable | `x64_link` | all symbols resolved |

Top-level statements form one `main` declaration: a composition root,
lowered as a single J5 job, as the specification recommends.

**The three barriers are real, not accidental.** B0 exists because a
`syntax` definition in one file changes how another file parses. B1 is
the swarm plan's Fork B: `bm_is_fn_bound_name` decides Call versus
CallHost for every call site. B2 exists because `bm_uses_box` and
"does any closure exist" are program-wide by design. Each barrier is
cheap (a scan or a fold over small summaries); the expensive work, J3,
J5, J7 and J8, sits between them and is per-unit.

## 3. Artefacts, identity and the ledger

- **Ledger**: an on-disk, content-addressed directory
  (`self_hosting/build/swarm/<kind>/<id>.bin`) plus one manifest per
  build listing every committed artefact. Commitment is "write to a
  temporary name, validate, rename", so a crashed worker leaves nothing
  visible.
- **Identity**: `id = hash(kind, transformation version, canonical
  payload, ids of every input artefact)`. The transformation version is
  a fingerprint of the source files that implement that stage, the same
  discipline `x64_compiler_fingerprint()` already applies to `.chunkbin`.
  Worker identity, timestamps and completion order never enter it.
- **Codec**: a generic binary encoding of nested PatLang values (lists,
  strings, ints, bools), built on the `x64_bin_*` helpers in
  `x64_compile_unit.patlang`. **Not JSON**: the Phase 1 prototype
  measured JSON round-trips as the entire 25-38% swarm overhead, and the
  `.chunkbin` cache had already moved off JSON for the same reason.
- **Validation** is a stage-specific structural check plus a hash of the
  encoded bytes, never a full decode/re-encode round-trip. The Phase 1
  prototype also never proved its validator could reject a bad
  candidate; every validator here gets a negative test.

## 4. Workers and isolation

- **Phases 1-4 run every job in-process, sequentially**, through the
  queue. That proves the artefact discipline with zero concurrency.
- **Parallel workers are separate processes** (`patc1 swarm-job
  <jobfile>`), following the existing `patc1 assemble_asm` child mode,
  not `parallel_map` threads. This departs from the specification's
  ordering (multi-process last, its Phase 8). The reason is specific to
  this repo: lowering and code generation write `__vars`, which threads
  share; that has already caused silent miscompiles (#80, CLAUDE.md §7).
  Process isolation makes that class of race impossible without first
  refactoring every stage to be `__vars`-free. Threads stay an option
  for any stage later proven free of `__vars` writes.
- **Batching**: a worker process takes a batch of jobs of one kind and
  loads only their input artefacts, amortizing process start and
  artefact decode, as `x64_build_unit_batches` already does for
  assembly. The minimum batch size is set by measurement (§6, Phase 5).
- **Host**: the driver runs under Gen A `patc1.exe` first (Rust runtime,
  real threads, stable memory behaviour). Running it under a native
  Gen B build is a later step that depends on the open native leak and
  refcount work in `general-refcounting.md`.

## 5. Determinism and parity

- **Gate**: for every corpus program, the swarm compiler's executable is
  **byte-identical** to `patc1 --x64`'s. The Phase 1 prototype already
  achieved this for 72 real units, so it is a realistic bar, not an
  aspiration.
- **Corpus**, in increasing size: the `native_codegen_check.sh` fixtures,
  `self_hosting/lib/x64_asm.patlang`, the mini bundle
  (`build_patc1_mini.patlang`), then the full `patc1_all.patlang` bundle.
- **Ordering**: chunks, symbols and diagnostics are ordered by source
  file order, then declaration order within the file, then synthesized
  block order within a declaration. Never by completion order.
- **Determinism test**: run the queue with a shuffled ready order and
  compare ledger manifests and executable bytes.
- The swarm plan's Fork E (is `x64_link`'s order stable today, or only
  accidentally stable?) is answered in Phase 0 by compiling the same
  input twice and comparing bytes.

## 6. Phases

Each phase keeps `patc1` unchanged except where a phase says otherwise,
and ends with the §5 parity gate plus the standing suites
(`native_codegen_check.sh`, `refcounted_heap_native_check.sh`,
`thread_safety_check.sh`, the language spec gate).

- **Phase 0: Measure.**
  - Make the existing `genb_tempdebug.txt` stage markers append instead
    of overwrite, so one full-bundle compile yields a real per-stage
    breakdown: read, DSL expansion, tokenize, parse, lower, native
    codegen, unit assembly, link.
  - Run it on the mini bundle and on the full bundle (about 1h50m today).
  - Answer Fork E.
  - Exit: committed numbers for every stage. These decide where the
    payoff is: parallel lowering, incremental reuse, or both.
  - **Results (2026-10-26).** Rather than change the markers, an outside
    script polled `genb_tempdebug.txt` once a second and logged each
    change with a timestamp (`self_hosting/swarm_compile/phase0_measure.sh`, output in `self_hosting/build/phase0/`), so
    `patc1` itself stayed unchanged. Object cache cleared before each
    run; `patc1.exe` built at eec4f77.

    | Stage | mini run 1 | mini run 2 | full |
    |---|---|---|---|
    | Stage (marker boundaries) | mini run 1 | mini run 2 | full |
    |---|---|---|---|
    | start → `lexing` (read, splice, DSL) | 136s | 152s | 152s |
    | lex + parse | 5s | 4s | 4s |
    | `bm_lower_program_start` → `lowering_done` | 58s | 71s | 142s |
    | `lowering_done` → first `ecn_emit_start` (no markers) | 175s | 221s | 208s |
    | per-function codegen + assembly | 1074s | 1445s | 8335s |
    | apply table + link | 71s | 76s | 121s |
    | **total** | **1519s** | **1978s** | **8970s** |

    The 136–152s before `lexing` is the same with and without the
    syntax DSL, so it is reading and include splicing rather than DSL
    expansion. The roughly 200s between lowering and the first emitted
    function has no markers; it is unit preparation and still needs its
    own breakdown.

    - **Fork E: the link output is already deterministic.** The two mini
      builds produced byte-identical executables (10,724,864 bytes).
    - **Wall-clock noise is large.** The same input, with the same output
      bytes, ran 30% slower the second time. Phase 5's speedup claim
      needs repeated runs, not a single before/after pair.
    - **Five functions take 75% of the full build.** `regex_match_node`,
      `regex_match_seq`, `regex_match_at`, `regex_match_string_at` and
      `__closure_938` each lower to 5.9–6.6 MB of assembly (for example
      `regex_match_node` is 69,591 IR instructions). Each spends about
      200s before its first emitted instruction and 800–1,380s in
      assembly afterwards, about 6,700s together. The mini bundle stubs
      out the regex/syntax-DSL code, which is why it builds 6× faster.
    - **Per-function assembly time is roughly quadratic in assembly
      size.** Most functions under 600 KB assemble in 1–12s, but from
      980 KB to 1.6 MB to 6.1 MB the time goes 36s → 88s → 1,181s.
      3.8× more text costs 13× more time, close to the 14× a square law
      predicts.
    - **What this means for the plan.** Everything before per-function
      codegen takes about 500s, all of it sequential, so Phases 2–3 can
      save at most that. Per-root parallelism (Phase 4/5) can't make the build
      faster than its largest single root, about 1,600s. The quadratic
      assembler, and why those regex functions are 69K instructions to
      begin with, are separate fixes that pay off before any swarm
      work: fixing them first shrinks the full build towards the
      mini-bundle time.
  - **Root causes (2026-10-26, same day).**
    - **Quadratic assembly was `split_lines`.** `x64_assemble_chunk`
      splits the whole function's assembly text with `split_lines`
      (`self_hosting/lib/includes.patlang`), which called
      `char_code(s, i)` once per character of the entire text. Both
      runtimes check `s.is_ascii()` over the whole string on every call
      (`hosts.rs` `host_char_code`, `codegen.rs`'s `char_code` prelude),
      so the split was O(n²). On generated label-only assembly, the split
      went 526ms → 2,123ms for 20K → 40K lines, while `xa_process_line`
      over the same lines went 339ms → 699ms. Include expansion also runs
      it over each file whole, and `patc1_all.patlang` is one 2.4 MB
      file, so it was also most of the 136–152s before `lexing`.
    - **The 69K-instruction regex functions were inlined dynamic
      dispatch.** Before code generation, `regex_match_node`'s
      compilation island is 4 blocks and 493 instructions, in the full
      bundle as in a 2-line test program. The island holds 4 functions
      because tail calls lower to `JumpBlock`. `bm_nc_translate_block_instrs`
      then expanded each of its 11 `CallDynamic` instructions (every
      closure call such as `k(pos + 1)`) through
      `bm_nc_emit_call_dynamic`. That function inlined an `rt_str_eq`
      chain with one branch for **every callable in the whole program**
      taking enough arguments. That was 313 instructions per site in the
      test program and about 6,300 in the full bundle. Each root that
      tail-calls into the island (`regex_match_at`,
      `regex_match_string_at`, `__closure_938`) got its own copy, so the
      same ~69.5K instructions were generated and assembled five times.
  - **Fixes (2026-10-26).**
    - `split_lines` now cuts the text into pieces of at most 1,024
      characters by repeated halving with `substr` (O(n log n)), scans
      only the pieces, and joins a line that spans pieces in a string
      builder. No new host primitive.
      `self_hosting/tools/split_lines_check.patlang` checks 13 edge
      cases against the old algorithm and the scaling: 40K → 80K lines
      went from 3,017 → 12,597ms (RED) to 197 → 373ms.
    - Each `CallDynamic` site is now one `Call` to a shared dispatcher
      per arity, `bm_fn___cdyn_<n>`, which holds the same comparison
      chain in the same order (`bm_nc_build_call_dynamic_funcirs`). The
      `bm_fn_` prefix keeps codegen_x64's block-model call unpacking
      (`x64_bm_fn_prefixed`) applying to it.
      `self_hosting/block_model/tools/call_dynamic_size_check.patlang`
      lowers one function with two closure calls alongside 20 and then
      80 filler functions: 868 vs 3,028 instructions before (RED), 66
      and 66 after. A native fixture covers one- and two-argument calls,
      unit padding, captures, continuation-passing recursion, and calls
      from main, a loop and a function.
    - Standing suites after both fixes: `native_codegen_check.sh`
      61/61, `refcounted_heap_native_check.sh` 13/13,
      `thread_safety_check.sh` 5/5, language spec 178/178.
    - **Full Gen B self-compile, cleared cache: 8,970s → 1,050s.**

      | Stage | before | after |
      |---|---|---|
      | start → `lexing` | 152s | 7s |
      | lex + parse | 4s | 6s |
      | lowering | 142s | 78s |
      | `lowering_done` → first `ecn_emit_start` | 208s | 37s |
      | per-function codegen + assembly | 8,335s | 836s |
      | apply table + link | 121s | 75s |

      The resulting compiler is 11.1 MB (was 15.3 MB) and compiles
      `print(1 + 2)` correctly. It still segfaults compiling a closure
      that captures a top-level `let`. A Gen B built before these fixes
      crashes identically, so this is an existing bug, filed as #228.
    - **Shared tail-call islands: measured, not done.** Across the full
      bundle, the 829 call roots' islands total 195,211 instructions
      against 170,929 with every block counted once, so absorbing other
      functions through tail calls duplicates at most about 24K
      instructions (≤12%). Most multi-block islands are a function's
      own loop blocks. Sharing islands needs a real native tail call:
      callers push arguments and pop them after the call, so a tail jump
      can only reuse the frame when the target takes no more arguments
      than the current function. The regex case is the opposite
      (`regex_match_node`, 5 with `__globals`, tail-calls
      `regex_match_seq`, 6). Ordinary calls would break constant-stack
      tail recursion. That calling-convention change is not worth ≤12%
      on its own; it is left for when Phase 4/5 measurements show island
      size on the critical path.
    - Both fixes change generated code, so the byte-parity baseline for
      swarm Phase 1 is taken after them.
- **Phase 1: Driver, ledger and codec, whole-program jobs.**
  - Re-run the prototype's `phase1_demo` against the current tree.
  - Add `patc1 swarm <in> <out>` with the coordinator, ledger and codec.
  - Run today's pipeline as four coarse jobs: source, parse, lower, and
    native codegen plus link.
  - Replace the prototype's JSON validation with §3's.
  - Exit: byte parity on the whole corpus; a negative test per validator.
- **Phase 2: Per-file source and parse units.**
  - J1-J3 become real per-file jobs: the include graph replaces
    splicing, DSL expansion runs against the frozen `DslEnv`, and the
    per-file ASTs are concatenated in include order before one lower job.
  - Exit: byte parity, with per-file parse artefacts reused across two
    builds where nothing changed.
- **Phase 3: Symbol barrier and per-declaration lowering.** This is the
  hard phase.
  - `bm_lower_program` splits into declaration collection (J4) and
    per-declaration body lowering (J5). Each `__vars` key in the survey
    becomes an explicit input (`SymbolIndex`) or a per-declaration output
    (`DeclBlocks`).
  - Synthesized names (`bm_synth_counter`, closure and loop block names)
    must be derived from declaration identity plus a local counter, the
    CLAUDE.md §7(a) fix pattern.
  - **That naming change goes into the shared lowering code first, so
    `patc1` emits the same names and byte parity survives** (Fork C).
  - Exit: byte parity; lowering one declaration needs no other
    declaration's body.
- **Phase 4: Program facts and per-root code generation.**
  - Add the B2 barrier.
  - J7 runs per call root and feeds the existing `CompileUnit` path, so
    the whole pipeline is a job graph.
  - Exit: byte parity on the full bundle through the graph.
- **Phase 5: Process workers.**
  - Add `patc1 swarm-job`, batching, and a worker pool sized from the 20
    available cores.
  - Measure per-kind job duration, queue occupancy, decode overhead and
    critical path, then choose minimum batch sizes.
  - Add fault tests: a killed worker, a duplicate result, a malformed
    candidate.
  - Exit: byte parity, plus a measured net speedup on the full bundle;
    if there's no net speedup, the phase has failed and the numbers say
    why.
- **Phase 6: Incremental builds.**
  - The ledger persists across builds; a changed file invalidates only
    along recorded edges: its parse and the declarations it defines;
    `SymbolIndex` only if its header changed; dependants only if the
    index or `ProgramFacts` changed.
  - Exit: editing one function body in the compiler and rebuilding takes
    minutes, not the full build time, with byte parity against a clean
    build.
- **Phase 7: Ownership summaries and speculation.**
  - The swarm plan's Forks C/D: per-function ownership transfer
    summaries in place of in-line dominance analysis.
  - Only if Phase 5/6 measurements show native codegen on the critical
    path.

## 7. Decisions

**All four recommendations below were accepted by the project owner on
2026-10-26**: subcommand entry point, program-wide DSL environment,
shared synthesized-name change, process workers. Fork E stays a Phase 0
measurement.

- **Fork A: entry point.**
  - Option 1: `patc1 swarm` as a subcommand compiled into the same
    bundle. One build, one binary, shared stage code, and the worker
    child mode lives beside the existing `assemble_asm`.
  - Option 2: a separate `patcs` bundle, which costs a second
    self-compile on every change.
  - *Recommended: subcommand*, with the driver in its own
    `self_hosting/swarm_compile/` files so it can be split out later.
- **Fork B: DSL environment.**
  - Option 1: freeze all `syntax` definitions program-wide (B0, as above).
  - Option 2: scope them to files that include the defining file.
  - *Recommended: program-wide*, since it matches what whole-program
    expansion does today and so keeps parity.
- **Fork C: synthesized-name change.**
  - Option 1: change the shared lowering code so `patc1` emits
    declaration-derived names too, which keeps byte parity.
  - Option 2: swarm-only names, which relaxes the gate to behavioural
    parity.
  - *Recommended: shared change*, since behavioural parity is a much
    weaker gate on a 500-function compiler.
- **Fork D: worker isolation.**
  - Option 1: processes from Phase 5.
  - Option 2: first refactor lowering and codegen to be `__vars`-free,
    then use threads.
  - *Recommended: processes*; the refactor can follow later where it
    pays.
- **Fork E: link order.** Answered by measurement in Phase 0, not chosen.

## 8. The language side

The specification's "swarm-friendly program" rules (no mutable ambient
globals, capability-shaped objects) matter here in two distinct ways
that should not be conflated:

- **Compile-time independence** depends only on the *compiler's* hidden
  state (§1's `bm_*` keys). A user program's `set_var` or object fields
  do not create compile-time edges between declarations; they create
  runtime ones. So J5 parallelism needs no user-program discipline at
  all.
- **Analysis precision** (ownership summaries, effect summaries, Phase 7)
  does depend on the program: an object field in the shared `__vars`
  table is an undeclared input to every method that touches it. That is
  the subject of `contract-bounded-object-compilation.md`, and the
  natural point to add "mutable ambient global" diagnostics is once
  Phase 7 consumes such summaries.

## 8a. Implementation note: expressiveness and contract precision

`swarm-implementation-note.md` follows the
independent-object compilation description. Its central rule: an object
implementation observes another only through a contract, and
**imprecision lowers guarantees and optimisation, never validity**.
Most of it concerns the language and `contract-bounded-object-compilation.md`.
These parts bear directly on this compiler:

- **Never stricter than `patc1` (note §§19, 22–23).** The swarm driver
  must never reject a program `patc1` accepts. Where a job can't
  compute a precise fact (a summary, a capture set, a dispatch target),
  it emits the conservative one, which is what the byte-parity gate
  (§5) already enforces in practice. Validators (§3) check that an
  artefact is well formed, never that a program is "swarm-friendly".
- **One compiled implementation, many uses (note §1).** The note says
  identical machine code must not be generated once per use. Phase 0
  found that violated twice. `CallDynamic` inlined a whole-program
  dispatch chain at every closure call; it now calls one dispatcher per
  arity, which took the full self-compile from 8,970s to 1,050s together
  with the `split_lines` fix. Each root that tail-calls into an island
  still re-emits the whole island; that duplication is at most 12% of
  the bundle's instructions and is deferred (Phase 0 fixes). Smaller,
  more even J7/J8 units also help Phase 5's batching.
- **Cycles are not islands (note §15).** Mutually tail-recursive
  functions (`regex_match_node`/`_seq`/`_alt`/`_repeat`) are merged
  into one JumpBlock island today. The note's guidance is to compile
  each implementation against the other's contract, which here is its
  calling convention, and only merge where the cycle is in the contracts
  themselves. For J7 that means a root's island should stop at another
  root's entry block (a real call or an explicit tail jump to a shared
  symbol) instead of absorbing it. This is a later refinement: it
  changes code shape, so it needs its own parity re-baseline.
- **Program-wide facts become per-unit descriptors where they can
  (note §§12, 14).** The note lowers closures to an implementation plus
  an environment descriptor, and infers minimal contracts locally.
  Today `bm_nc_program_has_any_closures` disables the multi-block
  string-refcount pass for the *whole program* if any closure exists.
  Under the note it becomes a per-declaration capture descriptor in
  `DeclBlocks`, and B2 shrinks to the facts that really are global
  (`uses_box`, the dispatch-by-name root set). It changes what the
  pass does for every program with a closure, so it belongs to Phase 7.
- **Registrations are explicit dependencies (note §§4, 13).** `when`
  handlers, `rule`/`action_add`, and functions reached only by runtime
  name (`apply`, `fiber_new`, `parallel_map`, `budgeted_run`; CLAUDE.md
  §9) are the compiler's ambient dependencies. J6 should record them as
  explicit `ProgramFacts` entries (registry, kind, target name), never
  rediscover them by scanning. That also turns the §9 "keep the
  registry exhaustive" rule into something a validator can check.
- **Workers receive immutable inputs only (note §10).** This matches
  Fork D: worker processes get artefacts and job files, never live
  runtime state, so nothing a worker needs has to be serialisable
  beyond the §3 codec.
- **Metadata shape (note §18).** The ledger's artefact identity (§3)
  covers `implementation_hash`, `compiler_contract_hash` (the
  transformation version) and required inputs. Phase 6 adds the
  distinction that matters for invalidation: a dependant that only uses
  a callee's *contract* (name, arity, calling convention) is
  invalidated only when that changes. A dependant that has inlined or
  absorbed the callee's *implementation* (today's islands and dispatch
  chains) depends on its body, and that edge has to be recorded
  separately. Removing the inlining above shrinks that second kind of
  edge, and so the rebuild scope.
- **Out of scope here:** assurance levels (note §16), reflection
  classes (§5), binding policies (§7), sealed/open contracts (§8),
  identity policy (§9), foreign boundaries (§11) and runtime `eval`
  (§6). All are language-side; one point to carry forward is that a
  runtime compilation request must name its syntax environment, the
  same `DslEnv` B0 makes explicit here.

## 9. Explicitly out of scope

- A static type system (the specification's typing stage, §6.4).
- Sub-file lexing, per-basic-block jobs, and speculation before Phase 6's
  invalidation is proven.
- Changing what any lowering or codegen stage computes, beyond Fork C's
  naming change.
- The WASM and Rust-source backends.
