# GPU-accelerated relational compilation (RelationalBlockIR) — the stage after SwarmCompile

**Status (2026-10-22): proposed, research-stage, not started.** Distilled
from a second design specification the project owner provided
(`PatLang_GPU_Relational_Compilation_Specification.docx`, explicitly
titled "Companion to the Swarm Lowering and Compilation specification"),
translated here into this repo's own files and conventions. **Nothing in
this document is authorized to start yet** -- it depends on `docs/plans/
block-ownership-model-swarm-compilation.md` reaching a mature state
first (see §1), and that plan's own Phase 0 hasn't finished yet either.

## 0. Relationship to existing plans -- read this before anything else

- **Depends on, does not replace, `block-ownership-model-swarm-
  compilation.md`.** The source spec is explicit: "The GPU design is
  orthogonal to the swarm design and should reuse its artefact
  envelopes, stable identities, dependency graph, validation contracts,
  and deterministic coordinator." Concretely: the swarm scheduler
  identifies independent work (its `JobEnvelope`/`CandidateResult`
  machinery, already prototyped in `self_hosting/swarm_compile/`); the
  GPU batcher groups ready jobs by shape; the GPU processes regular
  relation data; the CPU validates and commits -- using the SAME
  commit/validate discipline the swarm plan already established, not a
  second one.
- **Overlaps with, and may be the real first step toward, `docs/plans/
  future-work-cuda-kernel-generation.md` -- correction from an earlier
  draft of this document.** That doc frames GPU-targeting as something
  only a COMPILED USER PROGRAM would do. But PatLang's own compiler
  (`patc1.exe`/`patc2.exe`) is itself written in PatLang and compiled by
  a PatLang-authored compiler -- so once this plan's own host primitives
  let a PatLang program allocate GPU buffers, upload data, launch a
  kernel, and read results back, the COMPILER using those primitives
  to accelerate its own analyses genuinely IS "a PatLang program
  targeting a GPU," not a separate, unrelated concern. Do not describe
  this plan as "build-side, not output-side" -- that distinction doesn't
  hold once self-hosting is taken seriously. What's still true: this
  plan's own near-term phases (§10) don't need the OTHER doc's specific
  prerequisites (a typed numeric-array `Value` variant, loop structure
  preserved through lowering) because the relational projection in §5
  already produces flat integer/bitset arrays directly, bypassing that
  gap rather than fixing it. But the host primitives this plan adds
  (buffer management, kernel launch, sync) are infrastructure any OTHER
  PatLang program could later call too -- see the new §3.1 below. The
  two plans should be read as converging, not parallel.
- **Builds on `docs/plans/general-refcounting.md` and `block-ownership-
  model.md`/`-implementation-plan.md`** as the CPU-side canonical
  ownership semantics this plan's own §6.3 (ownership propagation) must
  stay provably consistent with -- GPU results here are candidates, the
  CPU dominance passes remain the ground truth until a GPU result is
  independently validated against them.

## 1. Central proposition (from the source spec, unchanged)

Compilation is not well described as dense matrix multiplication.
Substantial parts of it are iterative algebra over SPARSE program
relations: matrices/tensors hold relations, masks express predicates,
gather/scatter propagate facts, reductions implement joins, transition
tables encode finite semantic rules, and fixed-point iteration stabilizes
analysis results. The Block Ownership Model stays the one canonical
semantic authority throughout -- every GPU result is a candidate fact
until an independent CPU-side validator accepts it.

## 2. Non-negotiable rules (from the source spec, kept verbatim)

- BOM is canonical; the accelerator representation (`RelationalBlockIR`,
  §3) is a lossless or explicitly-scoped projection for analysis only.
- Every GPU result is a candidate until an independent validator accepts
  it -- never trust-on-write.
- Measure TOTAL elapsed cost: packing, host-to-device transfer, kernel
  execution, fixed-point synchronization, device-to-host transfer,
  unpacking, AND validation. Never report kernel time alone as "the
  speedup."
- Batch many functions/islands together -- never assume one ordinary
  function is enough work to occupy a GPU.
- Prefer sparse indexed relations and structure-of-arrays layouts over
  pointer-rich trees.
- Keep a CPU implementation as permanent parity oracle and fallback.
- Use deterministic integer identifiers and stable ordering -- GPU
  scheduling must never alter compiler output, even though GPU execution
  order internally may be nondeterministic.
- Adopt GPU execution only past an empirically measured break-even
  threshold -- not as a default.
- Keep irregular semantic decisions, diagnostic commitment, island
  merging, and final linking CPU-led unless real evidence says otherwise
  (§7 lists these explicitly).

## 3. What this repo actually has available (checked directly, not assumed)

- A real GPU is present on this development machine: `nvidia-smi` reports
  an **NVIDIA GeForce RTX 5070 Ti, 16303 MiB VRAM, driver 610.88** -- this
  is not a purely theoretical exercise, experiments can genuinely run
  here.
- **CUDA Toolkit 13.1 is installed** (`nvcc` on PATH, "D:\Program Files\
  Nvidia GPU Computing Toolkit\bin\nvcc"). There is no existing GPU
  integration anywhere in this repo today, in either `rust-runtime/` or
  `self_hosting/` -- this is a genuinely new primitive category, not an
  extension of something already wired in.

### 3.1 PatLang-first, not Rust-first — correction from an earlier draft

An earlier draft of this document treated "a Rust GPU crate
(`cudarc`/`wgpu`) called from `rust-runtime/`" as the natural home for
this work, reasoning that it was "purely a host-boundary data-layout
concern." **That reasoning is wrong for this project specifically.**
Per this project's own standing conventions (self-hosted `.patlang` is
canonical EVERYWHERE, including new primitive work -- not just
pre-existing logic; Rust exists only for the Gen A bootstrap and
correctness-mirroring, never as the default venue for new capability),
and per the project owner's own correction: PatLang's compiler is
ITSELF a PatLang program, compiled by a PatLang-authored compiler. Once
this plan adds host primitives that let a PatLang program allocate a
GPU buffer, upload data, launch a kernel, and read results back, the
compiler using those primitives to accelerate its own analyses is
PatLang targeting a GPU -- not Rust targeting a GPU with PatLang
calling in from outside.

**Consequence for how this gets built**: the actual GPU-facing
primitives (allocate buffer, upload, launch kernel, download, sync,
query device) must be added as genuine host primitives in the SAME
place and the SAME way every other OS-boundary primitive in this
project already is -- `hosts.rs` for the interpreter, and (critically,
not deferred) `codegen_x64.patlang`'s `CallHost` dispatch + a thin
`x64_runtime.patlang` wrapper for the native path, mirroring this
session's own `tls_counter_next`/`vec_extend` work exactly. The driver-
level glue underneath those primitives (the actual CUDA/driver API
calls) is Rust/C only because that's genuinely unavoidable host-OS
surface, same category as `VirtualAlloc`/`TlsAlloc`/`lock xadd` already
are -- not because "GPU work belongs in Rust." Everything ABOVE that
thin boundary -- deciding what to batch, building `RelationalBlockIR`'s
flat arrays, the fixed-point loop driving kernel launches, validating
results -- is compiler logic and belongs in `self_hosting/`, in PatLang,
full stop. This also means these new primitives are not compiler-private:
once they exist, ANY PatLang program can call them, which is the real
bridge to `docs/plans/future-work-cuda-kernel-generation.md` noted in §0.

### 3.2 Sequencing decision: a real codegen backend FIRST, not hand-written kernels (revised, per project owner's direction)

An earlier draft of this section treated a genuine PatLang-to-GPU
codegen backend -- compiling a restricted subset of PatLang (the
relational/algebraic operations §5-§6 describe: gather, scatter,
segmented reduction, fixed-point join) DIRECTLY to GPU kernel code, the
same way `patc1_main.patlang` already dispatches to `--x64` and
`wasm32-wasip1` -- as a "long-term, not scoped" aspiration to revisit
only after hand-written kernels were proven. **Reversed.** Hand-writing
kernels first means throwing that work away once a backend exists --
the opposite of "replicable route," and inconsistent with §3.1's own
"PatLang first, always" correction. Building the backend FIRST means
every workload in §7's priority list becomes "write this analysis as an
ordinary PatLang function, let the compiler generate the kernel," not a
bespoke hand-authored `.cu` file plus bespoke FFI wiring repeated nine
more times.

This is not starting from nothing: `self_hosting/lib/codegen.patlang`'s
`emit_program_rs` ALREADY does exactly this shape for the WASM path --
emit target-language source text (Rust), shell out to the vendor
compiler (`rustc --target wasm32-wasip1`). A GPU backend emitting CUDA
C++ source text and shelling out to `nvcc` (confirmed installed, §3)
is a THIRD instance of a pattern this codebase already has twice, not a
new architecture -- see Fork A, now resolved accordingly. The honest
tradeoff, stated plainly rather than glossed over: this defers the
spec's own "prove the complete economic case" step (§10's old Phase 0)
until the backend itself is also built and proven correct -- a bigger,
riskier upfront investment than one hand-written kernel would have been,
justified here on consistency/maintainability grounds (the project
owner's own explicit call), not on a claim that it's the cheaper path
to a first result.

## 4. Decisions needed (genuinely undecided for THIS codebase)

### Fork A — Backend target: CUDA-source emission first, resolved per §3.2

**Resolved, superseding an earlier draft's "hand-written kernel
language" framing.** Per §3.2, the first real deliverable is a codegen
backend, not a hand-written kernel -- so the question is what that
backend EMITS, mirroring `emit_program_rs`'s existing "emit source text,
shell to vendor compiler" shape:
1. **Chosen for Phase 0 (§10)**: emit CUDA C++ source text for the
   restricted relational-algebra subset, compile it via `nvcc` (already
   installed, §3), launch via the §3.1 primitives. Vendor-specific (the
   spec's own §19 anti-pattern technically applies), but it is the
   lowest-risk way to prove the backend's own mechanics work at all,
   using the exact toolchain already present on this machine, with the
   exact architectural shape (`emit_X` + shell to vendor compiler) this
   codebase already trusts for WASM.
2. **Deferred, not abandoned**: a portable compute-shader target (WGSL
   via a minimal `wgpu` driver shim) for vendor neutrality, once the
   CUDA-source backend has proven the overall "PatLang subset ->
   generated kernel source -> vendor compile -> launch -> validate"
   pipeline works at all. Revisit once Phase 0 (§10) succeeds, not
   before -- deciding a second target before the first one is proven
   would be premature generalization.
This choice only affects the backend's OWN emission target -- it does
not change where the batching/projection/validation logic lives
(PatLang, always, per Fork B).

### Fork B — Projection logic: entirely PatLang, confirmed

Resolved by §3.1's own correction, stated here for clarity since an
earlier draft left this genuinely open: the `RelationalBlockIR`
projection (deciding what's ready/compatible/same-shape, building the
flat integer/bitset arrays) is PatLang code in `self_hosting/`, full
stop -- not a Rust host-boundary concern. The ONLY Rust/C surface is the
primitive set named in §3.1 (buffer alloc/upload/launch/download/sync),
each one as minimal and dumb as possible, exactly mirroring
`rt_atomic_fetch_add`'s own "one atomic hardware operation, nothing
more" scope.

### Fork C — Which artefact from the swarm plan is the first GPU input

The swarm plan's own Phase 1 slice produces `ChunkImage`-style compiled
fragments (§7's recommendation), which are a LATE-stage artefact (post
native codegen) -- not the right shape for liveness analysis, which
needs block/operation-level relations (§4's schema), a MUCH earlier
artefact than what SwarmCompile's own first slice touches. **Needs the
swarm plan's own Phase 5 or 6 (control-flow formation / closure
summaries as artefact jobs) to exist first** before this plan's own
Phase 1 (§10, "first experiment") has a real artefact to project from,
not just
`bm_patc_lower`'s in-memory IR accessed ad hoc. This is the concrete
reason this plan is correctly sequenced AFTER swarm, not just
thematically -- there is a real data dependency, not just a resourcing
one.

## 5. Core relational schema (from the source spec §4, kept intact)

Initial relations -- physical representation may use sparse edge arrays
or compact bitsets rather than literal dense matrices:

| Relation | Shape | Meaning |
|---|---|---|
| `Control` | blocks × blocks | block i may transfer to block j |
| `Defines` | blocks × values | block i defines value v |
| `Uses` | blocks × values | block i uses value v |
| `Calls` | functions × functions | function i may call function j |
| `SymbolDependency` | regions × symbols | region depends on a symbol contract |
| `Capture` | closures × values | closure captures a value |
| `TypeCandidate` | values × type classes | type remains possible for a value |
| `ReadEffect` / `WriteEffect` | regions × capabilities | read/mutation authority |
| `RetainEffect` / `ReleaseEffect` | regions × values/capabilities | access survives / obligation ends |
| `Live` | program points × values | value is live at a point |
| `Interference` | values × values | simultaneous liveness / allocation conflict |

`RelationalBlockIR` requirements: dense batch-local integer identifiers
with stable mapping back to canonical (BOM) identifiers; sparse topology
via CSR/CSC/COO/sorted-edge/segmented arrays (measured, not assumed);
structure-of-arrays operation fields; compact-integer/bitset semantic
state; no kernel ever follows a host pointer or consults mutable global
compiler state (the SAME rule the swarm plan's Fork B/§4 already
established for ordinary CPU workers -- this is that rule's GPU-side
restatement, not a new one); every projection records its source
canonical artefact hashes; every result records kernel/transformation
version, batch shape, assumptions, and validation summary.

## 6. Algebraic execution model (kept from the source spec)

```
general forward form:   next_state = seed JOIN transfer(Control-transpose APPLY current_state)
general backward form:  next_state = seed JOIN transfer(Control APPLY current_state)
repeat until:           next_state equals current_state
```

Pick the operation matching the semantic domain -- Boolean reachability,
minimum-cost selection, set union/intersection, finite-state transition,
ownership-lattice join, type-domain narrowing -- never force floating
point for an exact semantic decision (§12/§19 of the source spec).

## 7. Candidate workloads, in the source spec's own priority order

1. **Batched liveness (§14)** -- the mandated FIRST experiment.
   `live_out = successor_gather_and_union(live_in)`;
   `live_in = uses OR (live_out AND NOT defines)`. Pack many functions
   block-diagonally/segmented; function boundaries must never leak.
2. **Ownership-state propagation (§15)** -- gated explicitly on (1)
   succeeding first. Compact lattice (`absent, owned, shared, borrowed,
   exclusive, consumed, invalid, escaped`), transition table, join
   table. Must return obligations/conflicts (required retain/release,
   broaden-to-shared, use-after-invalidation, failed exclusivity) --
   **the GPU must never silently resolve a semantically ambiguous
   join**. This is the single highest-stakes workload in the whole
   document given how much of this session's own prior work
   (`general-refcounting.md` Phases 1-4) is exactly CPU-side ownership
   dominance analysis -- any GPU version must be proven against that
   existing, tested implementation, not alongside it as an equal.
3. Reachability/dependency propagation -- sparse frontier reuse, simplest
   after liveness infrastructure exists.
4. Effect/capability summaries -- directly supports the swarm plan's own
   §7 "proxy-global-bearing objects" island-formation analysis.
5. Batch relational verification -- independently-structured verifier
   (different implementation shape than BOM's own constructive one);
   high correctness value, low commitment risk since it only CHECKS,
   never produces artefacts that get committed.
6. Local rewrite candidate matching (constant folding, redundant
   retain/release pair removal, etc.) -- CPU validates side conditions
   and commits; GPU only proposes.
7. Type-domain narrowing for built-in classes.
8. Interference construction / register-allocation prep -- final
   allocation stays CPU-led (irregular: coloring, splitting, conflict
   repair).
9. Instruction candidate filtering -- target-oriented compatibility +
   cost reduction; complex graph covering stays CPU-led.
10. Dominance / complex graph properties -- explicitly LAST ("attempt
    only after sparse convergence behaviour is understood"); also
    directly relevant to this project's own EXISTING dominance-based
    refcounting passes (`general-refcounting.md`), so any eventual work
    here should be co-designed with that plan's own maintainer, not
    treated as a green-field analysis.

## 8. What stays CPU-led, period (from the source spec §7, kept verbatim)

Parsing and syntax error recovery; canonical symbol-index commitment and
ambiguous language-level decisions; adaptive semantic-island merging;
complex graph rewrites with substantial topology changes; final
diagnostic wording/ordering/source presentation; final register-
allocation decisions; code layout, address assignment, relocation
commitment, and executable linking; small interactive edits below the
measured break-even point; any transformation whose GPU representation
is not demonstrably lossless or independently checkable.

## 9. Determinism, caching, memory policy (from the source spec §11-13)

- GPU execution order may be internally nondeterministic; semantic
  OUTPUT must not be. No unordered first-writer-wins decisions; use
  associative/commutative joins, stable tie-breaking, explicit conflict
  reporting where no unique legal result exists.
- Every batch result attributable to exact canonical input hashes,
  projection version, kernel version, target context, device-independent
  semantic policy. Device-specific tuning changes performance, never
  meaning.
- The swarm artefact cache and GPU residency cache are DISTINCT caches
  with distinct keys (`canonical content + contracts + transformation
  version + target policy` for the semantic cache;
  `semantic artefact identity + projection version + relation format +
  shape bucket` for the GPU projection cache). Device buffers are
  disposable acceleration state, always reconstructible from committed
  artefacts -- never the only copy of anything that matters.
- Never make compiler correctness depend on a particular GPU model or
  vendor -- the reason Fork A treats the CUDA-source backend as a
  starting point to prove the pipeline, not a permanent vendor lock-in;
  a second, portable target is explicitly planned (§10's Phase N), just
  not before the first one works.

## 10. Phased roadmap

- **Phase 0 (gated on swarm plan maturity, see Fork C) -- build the
  minimal PatLang-to-GPU codegen backend itself**, per §3.2/Fork A.
  Scope deliberately tiny and self-contained, proving mechanics before
  any real compiler analysis touches it: define the restricted PatLang
  subset the backend accepts (gather, scatter, segmented reduction,
  bitset/mask ops, fixed-point loop -- the algebra from §5-§6, nothing
  resembling general PatLang); add a new codegen target following
  `emit_program_rs`'s existing shape (emit CUDA C++ source text for a
  PatLang function restricted to that subset, shell out to `nvcc`); add
  the §3.1 host primitives (buffer alloc/upload/launch/download/sync) to
  BOTH `hosts.rs` and `codegen_x64.patlang`'s `CallHost` dispatch +
  `x64_runtime.patlang` wrapper, in the same pass, per this project's
  own mirror-sync discipline -- not deferred. **Exit criterion**: a
  trivial PatLang function in the restricted subset (e.g. an elementwise
  array OR/AND over a fixed-size integer array) compiles through the new
  backend, launches via the new primitives, and produces output
  byte-identical to a CPU-computed reference -- proving codegen -> vendor
  compile -> launch -> readback works end to end, independent of any
  real liveness/ownership logic yet.
- **Phase 1 (gated on Phase 0) -- first real experiment: batched
  liveness**, following the source spec's §14 checklist, now WRITTEN AS
  A PATLANG FUNCTION compiled by Phase 0's backend rather than a
  hand-written kernel: representative corpus (tiny functions, loops,
  branches, closures, large generated programs -- `self_hosting/
  block_model/spec_fixtures/` already has most of these shapes); capture
  current canonical (CPU, `bm_patc_lower`-adjacent) liveness results +
  timing as the oracle; define the `RelationalBlockIR` projection
  (control edges, defines, uses, function boundaries only -- nothing
  else yet); implement a RELATIONAL CPU liveness solver using the same
  packed representation FIRST (proves the representation itself is
  correct before the GPU path runs at all -- this step is easy to skip
  and must not be); compare relational-CPU against canonical-CPU; only
  then run the PatLang liveness function through Phase 0's backend on
  the GPU; validate GPU against BOTH CPU implementations; measure every
  cost component from §9's table, not kernel time alone (now also
  including the backend's OWN compile time, since `nvcc` invocation cost
  is part of the real pipeline, not free); randomize function/batch
  ordering to test determinism; derive and record a real break-even
  size/shape policy; integrate ONLY as an optional feature-flagged
  analysis backend; promote only when parity is complete AND total
  elapsed time improves on intended workloads.
- **Phase 2 (gated on Phase 1's own success) -- ownership-state
  propagation**, per §15: limited subset already well-covered by
  existing BOM tests first, explicit obligation/conflict outputs,
  adversarial joins (consumed/shared/exclusive combinations) as
  deliberate test cases, validated against the canonical CPU ownership
  implementation on every single result during rollout -- no exceptions.
- **Phase 3+ -- the remaining workloads from §7's own priority-ordered
  table**, each written as a PatLang function compiled by Phase 0's
  backend, each gated on the previous one's measured success, never
  started out of order "for conceptual completeness" (an explicitly
  named anti-pattern, §11 below).
- **Phase N (deferred, per Fork A) -- a second, portable backend
  target** (WGSL/`wgpu`) once the CUDA-source backend has proven the
  pipeline shape works, for vendor neutrality. Not scheduled against any
  specific phase number above -- revisit once there's real experience to
  generalize from, not before.

## 11. Anti-patterns (from the source spec, kept verbatim — they apply directly)

- Describing all compilation as dense matrix multiplication.
- Porting pointer-rich AST visitors directly to GPU kernels.
- Moving one tiny function at a time to the device.
- Reporting only kernel execution time as compilation speed-up.
- Using floating-point approximations for exact semantic facts.
- Allowing nondeterministic atomic update order to choose semantic
  winners.
- Combining unrelated shapes into a severely padded batch.
- Letting GPU buffers become the only copy of compiler state.
- Committing rewrites without validation and canonical identity checks.
- Removing the CPU oracle before extensive differential testing.
- Assuming one vendor-specific optimisation defines the architecture.
- Attempting parsing, linking, and every irregular stage merely for
  conceptual completeness.

## 12. Acceptance criteria (from the source spec, kept verbatim)

`RelationalBlockIR` documented, versioned, deterministic, tied to
canonical artefact identities. At least one fixed-point analysis runs
through relational-CPU AND GPU paths with complete parity. Batched
functions remain isolated and deterministic under reordered packing.
Total end-to-end cost measured and a break-even routing policy
implemented. GPU failures fall back safely without corrupting committed
compiler state. Candidate results independently validated before
commitment. The implementation reuses swarm artefacts/scheduling rather
than competing with it. Performance benefit demonstrated on
representative, sufficiently large workloads. Tiny/irregular workloads
remain on the CPU path. Ownership-state propagation is not promoted
until conflicts and join obligations are exactly represented.

## 13. What this plan is explicitly NOT about

- **Not** "only the compiler's own internal concern, unrelated to what
  PatLang programs can do" -- corrected in §3.1/§0: because the
  compiler is itself a PatLang program, this plan's host primitives
  (buffer alloc/upload/launch/download/sync) are real new PatLang
  language capability, usable by any program once they exist, not a
  private compiler-internal hack. What this plan does NOT include is
  `docs/plans/future-work-cuda-kernel-generation.md`'s OWN specific
  prerequisites for arbitrary user numeric GPU compute (a typed
  numeric-array `Value` variant, loop structure preserved through
  lowering) -- this plan's relational arrays sidestep that gap rather
  than closing it, so a user program wanting to do its OWN GPU numeric
  work still needs that separate doc's prerequisites, even after this
  plan's primitives exist.
- Replacing any CPU implementation -- every GPU path here is additive,
  feature-flagged, and requires a permanent CPU fallback per §2's own
  non-negotiable rules.
- Starting before `block-ownership-model-swarm-compilation.md`'s own
  Phase 5/6 (control-flow-formation-as-artefact-job) exists -- per
  Fork C, there is a real data dependency, not just a sequencing
  preference.

## 14. Background references (from the source spec, for context only)

Cited by the spec as motivation for operation-graph/dataflow execution
patterns in OTHER domains -- they do not themselves establish that
PatLang compilation will be faster on a GPU, and no claim here rests on
them: NVIDIA's cuDNN Graph API docs; Davies/Crago/Sankaralingam/Keckler,
"Kitsune: Enabling Dataflow Execution on GPUs" (arXiv:2502.18403, 2025);
Li & Huang, "GPU-CFR" (arXiv:2609.11923, 2026).
