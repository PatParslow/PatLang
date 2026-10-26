# Swarm compiler: a second, artefact-graph compiler alongside patc1

**Status (2026-10-26): proposed, not started.** Plans an implementation of
`PatLang_Swarm_Lowering_Approach.docx` (the same specification already
distilled into `block-ownership-model-swarm-compilation.md`) as a **new
compiler driver** built beside `patc1`, rather than as a retrofit of
`patc1`'s own pipeline. `block-ownership-model-swarm-compilation.md`
remains the record of the specification's mapping onto this repo, its
Phase 0 global-state survey and its Phase 1 measurements; this document
is the implementation plan that follows from them.

## 0. Relationship to existing plans

- **`block-ownership-model-swarm-compilation.md`**: source of the stage
  mapping (its §3), the `__vars` survey (its Phase 0) and the Phase 1
  prototype results. Its Forks B-E reappear below as concrete decisions.
- **`contract-bounded-object-compilation.md`**: the language-side
  complement. This compiler needs no language change to work; contracts
  would later sharpen ownership summaries and give object-level effect
  boundaries (§8).
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

## 9. Explicitly out of scope

- A static type system (the specification's typing stage, §6.4).
- Sub-file lexing, per-basic-block jobs, and speculation before Phase 6's
  invalidation is proven.
- Changing what any lowering or codegen stage computes, beyond Fork C's
  naming change.
- The WASM and Rust-source backends.
