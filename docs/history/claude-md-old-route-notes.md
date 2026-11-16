# Old-route notes moved out of CLAUDE.md

These sections of CLAUDE.md were about the old compiler (patc1, the block-model
backend, `__vars`) and the Rust interpreter. They moved here on 2026-11-16 when
CLAUDE.md was cut back to v2; the general rules they illustrate are in CLAUDE.md
(shared state in workers, registries that must stay complete).

## 7. Thread safety: `__vars` is one shared namespace across `parallel_map`/`thread_spawn` workers

This section is about the old compiler and `pat`. v2 has no `set_var`, and its
worlds (spec 1.15) hold a program's state. The three shapes below still apply to
any shared mutable state a worker can reach.

Found via GitHub #197 (native x64 parallel assembly, already built and
measured at 10.9x on the mechanism itself, blocked on this): `get("__vars",
key)`/`set_var(key, val)` reads/writes ONE process-wide table. A
`parallel_map`/`thread_spawn` worker does NOT get its own isolated copy of
it — code that assumes otherwise races, non-deterministically, and the
failure often looks unrelated to concurrency at first (e.g. "undefined
symbol 'S2'" on one run, a different symbol on the next). A full audit
(2026-10-02) found this is not a one-off mistake but a recurring shape
across the self-hosted codebase, worth checking for explicitly any time a
new `parallel_map`/`thread_spawn` call site is added, or an existing one's
callee graph changes. Three distinct hazard shapes, each with its own fix
— don't reach for a lock/mutex for any of them, PatLang has none, and all
three have a lock-free fix that removes the shared mutable state instead:

**a) Shared uniqueness counters.** A `get("__vars", "X_counter")` /
increment / `set_var` triple used to generate a unique name/ID (label,
symbol, synthesized function name). Confirmed actually racing: `__x64_str_
counter`/`__x64_cv_counter` (`codegen_x64.patlang`), `xa_id_counter`
(`x64_asm.patlang`) -- both hit from inside `x64_compile_unit.patlang`'s
`x64_assemble_unit_batch`, the actual `parallel_map` worker for per-unit
codegen/assembly. This is the one confirmed-live instance; everything else
audited turned out NOT to be reachable from a real parallel phase (see
correction below), so this is the fix that actually matters for #197.
Several other same-shaped counters exist (`pr_id_counter`, `__iso_seq`,
`__isop_seq`, `__interp_run_seq`, `__interp_seq`, `__evloop_seq`,
`bm_synth_counter`, `zs_bfs_counter`) but are not currently reachable from
any `parallel_map`/`thread_spawn` call site -- safe today, same shape,
re-check if that ever changes.
  - **Fix**: derive uniqueness from something already unique per unit (the
    function's own name, a caller-supplied task ID) plus a LOCAL counter,
    instead of a shared global one. This removes the race by removing the
    shared mutable state, not by synchronizing access to it.
  - **Correction (2026-10-02)**: an earlier version of this section also
    named `lower.patlang`'s `__closure_seq`/`__budgeted_seq`/`__match_seq`/
    `__activate_seq`, claimed reachable via `tools/build_portfolio.patlang`'s
    `parallel_map` calls. Both halves of that claim were wrong, found while
    verifying the fix (since applied anyway, as a harmless, correct
    simplification -- see `next_closure_name` et al., now derived from
    `vec_len()` of an already-thread-local `vec_*` handle instead of
    `__vars`): (1) `build_portfolio.patlang`'s workers each shell out to a
    *separate OS process* (`patc1_compile` -> `exec_capture("./patc1.exe",
    ...)`), which has its own private memory -- nothing shared across
    workers there at all. (2) More fundamentally, lexing/parsing/lowering
    always runs once, sequentially, *before* `x64_compile_unit.patlang`
    splits the IR into units for parallel assembly -- `lower.patlang`'s
    counters are never invoked from inside any parallel phase in the
    current architecture, by either lowering pipeline (see next point).
    Also as of this session, `patc1_main.patlang`'s `--x64`/`--bm` compile
    path calls `bm_patc_lower` (Block Ownership Model lowering), not
    `lower.patlang`'s `lower_program`, at all -- `lower_program` remains
    live for the Rust/self-hosted parity tests, the WASM backend, and
    direct callers, just not the x64 CLI path. `block_model/lower.patlang`'s
    own equivalent counter (`bm_synth_counter`) has the same shape but the
    same non-reachability (sequential lowering only) -- listed above, not
    separately broken out.

**b) Shared resource-handle state.** A port/socket/file-handle claimed by
one thread, with its "have I already claimed one" check reading from
shared state another thread can also read.
  - **Correction (2026-10-02)**: an earlier version of this section claimed
    `build_progress.patlang`'s `x64_build_signal_claim` was a confirmed
    instance of this bug (reading another worker's claimed port and
    believing it holds a live listener it never bound). Direct tracing of
    its actual call sites found this is already a complete, correct fix,
    not a bug: `x64_build_signal_claim()` is only ever called from
    sequential/parent-thread code (`patc1_main.patlang`,
    `x64_compile_unit.patlang`'s own `build_native` setup) -- never from
    inside a `parallel_map` worker. `x64_assemble_unit_batch` (the real
    worker) only sets `__x64_build_port` to the sentinel `"-1"`
    (`x64_compile_unit.patlang:683`) so its own ticks no-op; it never reads
    or trusts another worker's claimed port. The fork-join nature of
    `parallel_map` guarantees no worker is still running when the parent
    restores the real port afterward. No fix needed here -- kept as a
    worked example of the *shape* in case a future port/socket/handle claim
    is added somewhere that genuinely IS called from inside a worker.

**c) Shared accumulators.** A `list_push`/`vec_push` onto a list/cache kept
in `__vars` rather than a local variable. One confirmed instance,
currently NOT reachable from a parallel call site (`report.patlang`'s
`report_log`, accumulated via string-concat, not even `list_push` -- also
worth a look under §4.5's string-building rule separately if ever called
in a hot loop), so not yet a live bug, but the shape to watch for.
  - **Fix**: accumulate per-worker (a local list each worker returns), merge
    the results AFTER `parallel_map` returns -- never write to a shared
    structure from inside a worker.

**The safe pattern already in use, worth copying deliberately**: `goap_
synthesis.patlang`'s and `synthesis_by_example.patlang`'s own worker
functions (`goap_eval_candidate_chunk_worker`, `sbe_eval_candidate_chunk_
worker`) only ever READ `__vars` keys that were set ONCE, before
`parallel_map` starts, and never written again during the parallel phase.
Read-only broadcast state is fine; the hazard is specifically a WRITE
(even an idempotent-looking one, per (b)) from inside a worker.

**Before adding, or extending the callee graph of, any `parallel_map`/
`thread_spawn` call site**: check whether anything it calls, transitively,
writes to `__vars` (`set_var`, or `get`+increment+`set_var`). A write there
is fine if it happens before the parallel phase starts or after it
finishes; a write reachable DURING the parallel phase needs one of the two
fixes above, not a mutex (there isn't one).

---

## 9. Dispatch-by-name primitives: a new one must be added to EVERY registry that enumerates them, not just the one you're touching

The instance below is in the old compiler's block-model backend; the rule is general.

Confirmed recurring, not a one-off (GitHub #224): `bm_nc_dispatches_by_name`
(`self_hosting/block_model/native_codegen.patlang`) is the list of host
primitives that resolve a callee by a RUNTIME STRING NAME rather than a
compile-time-visible `Call` target (`apply`, `fiber_new`, `parallel_map`,
`budgeted_run`). Any function ONLY ever referenced this way (never via an
ordinary call expression) needs this list to know it must still get its own
standalone, addressable FuncIR emitted and registered in the apply table --
otherwise it fails at runtime with `function '<name>' not found`, for every
program using that primitive, not just an edge case. Found with `parallel_map`
missing from this list entirely, **and** `fiber_new` ALSO missing despite
being named in the list's own header comment as something it was supposed to
cover -- the comment and the code had already drifted apart once before this
was even looked at.

- **Rule**: when adding a new host primitive whose first argument (or any
  argument) is a function looked up by name at runtime -- not a closure, not
  a compile-time-visible call -- add it to `bm_nc_dispatches_by_name`
  in the SAME change, and verify by grepping for every existing caller of
  `resolve_func_addr` (`self_hosting/lib/x64_runtime.patlang`) to confirm the
  list's membership still matches that caller set exactly, not from memory or
  the list's own comment.
- **Rule**: when fixing one entry found missing from a registry like this,
  don't stop at the one bug report named -- re-derive the FULL correct
  membership from first principles (grep the actual call sites of whatever
  mechanism the registry gates) and compare against the list's current
  contents, the same way this entry's own fix found a SECOND missing name
  nobody had reported yet.
- **Rule**: a registry's own header comment is a claim, not a guarantee --
  verify the code actually matches what the comment says it does before
  trusting either one, especially when debugging exactly this class of bug.
- **Broader pattern this is one instance of**: this project already has
  multiple "the full set of things with property X must be kept exhaustive"
  registries (§2's self_hosting/`rust-runtime` mirror-sync, §7's `__vars`-
  touching-from-parallel-workers audit, now this one). Treat "which other
  enumeration does this new thing also need to join" as a standing question
  for ANY new primitive, pass, or capability -- not just these three known
  instances -- since the failure mode (works for every existing caller,
  silently or loudly breaks for the next new one) is identical across all of
  them.
