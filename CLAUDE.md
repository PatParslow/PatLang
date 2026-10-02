# PatLang: conventions for working in this repo

## Use the self-hosted compiler for ordinary compiles, not the native pipeline

PatLang was deliberately pushed to self-host: the lexer, parser, lowerer, and code generator are all written in PatLang itself (`self_hosting/lib/ {lexer,parser,lower,codegen,runtime_rs}.patlang`), not just as a novelty but so that PatLang programs actually get compiled by a PatLang-authored compiler.

---

## 1. Compilers

* **`./patc1.exe`**: Everyday builds/verification. Must use explicit relative path `./` on Windows to avoid `CreateProcess` failures.


* Rebuild stale compiler: `rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang`.




* **`pat --patc`**: Testing native compiler/runtime (`codegen.rs`) only. Do not use for routine builds.


* **Goal**: Transition from `rustc` bootstrap to pure PatLang-to-native emission.



---

## 2. Mirror Sync (`codegen.rs` $\rightarrow$ `self_hosting/`)

* **Rule**: Update mirror before session end or explicitly report deferred gaps.


* **Workflow**:
1. Check parity: `cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity`

2. Update matching `emit_chunk_<name>` in `self_hosting/lib/runtime_rs.patlang` via `sb_push`.


3. Report precise un-mirrored chunk counts if deferring.





---

## 3. BDD Testing Workflow

1. **RED**: Write Given/When/Then first. Confirm scenario fails.


2. **GREEN**: Test exact scenario prose claims.


3. **Verify**: Match spec claims against real runtime output.


4. **Report**: State command, output, and exact spec alignment.

5. **Standing language-spec gate** (GitHub #49): `spec_library/language/*.feature` is executable, not prose — wired via `self_hosting/lib/spec_steps_language.patlang`'s `step()` registrations onto `self_hosting/lib/test.patlang`'s real Gherkin runner. Run it with:
   `rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/run_language_spec_suite.patlang`
   Any language-semantics change (new operator, control-flow form, numeric-tower/tagging behavior) needs a scenario added/updated here as part of the change, RED before / GREEN after — not deferred to a one-off investigation. For representation/type invariants (e.g. "this op's result stays `int`, doesn't silently misclassify as `bigint`" — the root pattern behind #24/#46/#48), use `And ensure <var> == <literal>` (`self_hosting/lib/gherkin_contracts.patlang`) against a var set from `numeric_kind(x)`/`type_of(x)`; unquoted literal, `==`/`!=` also compare as strings when non-numeric. `spec_library/language/` is fully wired (37 of 37 `.feature` files, including two-process/cross-backend specs via `spawn()`/`exec_capture` — see `self_hosting/tools/spec_fixtures/`). `patlang_stdlib/`, `patlang_stdlib_auto/`, `shell/` are explicitly OUT OF SCOPE (leftover auto-generated specs from a different project, per project owner) — do not wire these without being asked.



---

## 4. Control Flow Rules

* **No Nested `else if**`: Causes silent execution failures (exit `0`, no output, no parse error).


* **Use `elif**`:
```patlang
if cond1 then
  ...
elif cond2 then
  ...
end
```[cite: 1]

```


* **Early Returns**: Prefer `if cond then return val end`.


* **Refactor**: Convert legacy nested chains to `elif` or audit `end` stacks.



---

## 4.5 String Building: never `s = s + ...` in a loop — check BEFORE running, not after

PatLang strings are immutable, so `out = out + x` inside a `while`/`for`-style
loop copies the *entire accumulated string* on every single iteration,
turning an O(n) scan into O(n²). This is a real, previously-hit perf bug
(self_hosting/lib/syntax_dsl.patlang cost 30+ minutes on a ~700K-char file
before being fixed this way), not a theoretical one. Despite an earlier
version of this exact rule already being in this file, it has now been
reintroduced and caught, one file at a time, across MULTIPLE separate
sessions/edits: `glob_to_regex` and `parse_glob_pattern`
(self_hosting/lib/{regex,parser}.patlang, issue #44 match/case work), then
`dbg_value_to_json`/`dbg_paused_to_json`/`dbg_trace_json`
(self_hosting/lib/interp.patlang, issue #96 BigInt-literal work) — three
separate JSON-building loops in ONE file, found only because the user
had to point out the warning a second time. Relying on "the compiler will
warn me" as the actual enforcement mechanism has already failed
repeatedly; the warning is a safety net for what slips through, not the
primary control.

* **Rule**: Any code written or edited — in PatLang, self-hosted or
  otherwise — that accumulates a string across loop iterations MUST use
  `sb_new()`/`sb_push(b, ...)`/`sb_str(b)` instead of `out = out + ...`,
  decided at the moment the loop is WRITTEN, not caught afterward by
  build output. This applies even to loops that look short/bounded — the
  anti-pattern is invisible until the *input* happens to be large, often
  buried deep in the call graph by then.
* **Mandatory self-check**: before considering any edit to a `.patlang`
  file done, re-read every `while`/loop you touched or added and ask
  "does this reassign the same string variable to itself plus something,
  every iteration?" If yes, it's this bug — fix it before moving on, not
  after a build warns about it.
* **Opportunistic cleanup**: if you're already editing a file for an
  unrelated reason and notice this pattern elsewhere in the SAME file
  (as happened with interp.patlang's three separate JSON builders), fix
  those too in the same pass rather than leaving known-bad neighbors — a
  file already open for editing is the cheapest possible time to do this.
* If the runtime emits this warning during a build anyway, that means the
  self-check above was skipped — fix it immediately, and treat its
  recurrence as a signal to slow down on the next `.patlang` edit, not as
  routine background noise.

---

## 4.6 Top-level `let` bindings are NOT shared across functions — don't reach for them as a default

A top-level `let x = ...` is local to the synthesized top-level `main`
function's own scope. There is no automatic cross-function sharing of it —
referencing it from inside another function (passing it as a bare name
instead of a parameter, e.g. `action_bind("a", step_a)` where `step_a` was
declared via `make a function called step_a ...` at top level and then
used as a value) fails under the self-hosted x64 codegen with:

```
codegen_x64: undefined variable '__main__step_a' referenced (not a parameter or
local of the enclosing function -- PatLang has no automatic cross-function
sharing for top-level `let` bindings; pass it as a parameter instead)
```

This has recurred across multiple separate sessions (almost every session,
per the project owner) — it is not a one-off typo, it is a reflex toward
writing top-level `let`s and then using them as if PatLang had closures-
over-globals or hoisted function references, which it does not.

* **Rule**: Don't use a top-level `let` binding unless there's a specific,
  stated reason it needs to live at that scope (e.g. it's only ever used
  inside the same top-level sequence of statements that declared it, never
  passed into or referenced from a different function body). Default to
  passing values as parameters instead of reaching for a top-level `let`.
* **If a function needs to be passed around as a value** (e.g. into
  `action_bind`, `parallel_map`, `thread_spawn`, or stored in a list), bind
  it as a closure literal (`let step_a = |args| do ... end`) in the SAME
  scope that uses it, not as a `make a function called ...` declaration
  referenced by bare name from a different function — a top-level function
  declaration's name is not an in-scope local/parameter anywhere else,
  including other top-level statements executed as part of the same
  synthesized `main`.
* **Before writing a new top-level `let`**, ask: will anything other than
  the literal next top-level statement in this same file need this value?
  If yes, it needs to be threaded through as a parameter (or be a function
  declaration called normally, not referenced by name as a value) instead.

---

## 5. Output Rules

* Keep turn narration to lean, concise text.


* Summarize results; do not paste full stdout.


* Save detailed write-ups for major milestones.

* **Avoid `| head -N` / `| tail -N`**: they queue output up instead of letting it stream, truncate before you've actually seen what matters, and aren't usually needed. Prefer `wc -l`, `grep -c`, or targeted `grep` for counts/verification; only cap output when a command is genuinely unbounded (e.g. a live log tail) and even then prefer a real filter over a blind line count. A prior session miscounted a directory's file total this way — trust an explicit count command (`ls ... | wc -l`) over a truncated listing.

## 6. Long-Running Programs: Signals, Queue, and Budgeted Yields

Any program intended to run for more than a few seconds, or as a background
process, must be built with health/progress monitoring and resumability
from the start — not added afterward, and not left out because the request
that prompted the program didn't mention it explicitly.

- **Rule**: If a program's main work will take more than a few seconds, or
  runs as a daemon, it must include `status` and `quit` signal handlers at
  minimum, declared at the top level per `patlang-program-conventions`.
  Do not wait to be asked for this separately — treat it as an implicit
  requirement of "long-running," the same way error handling is an implicit
  requirement of "reads a file."

- **Rule**: A `status` handler that cannot actually respond promptly while
  the real workload is running is not compliant, even if it is present and
  correctly written. Any main work loop of meaningful size or duration must
  be wrapped in `budgeted(ms) { ... }` (or otherwise yield on a comparable
  schedule) specifically so the signal-polling loop gets a genuine, regular
  turn. An unyielding tight loop with a technically-correct `status` handler
  behind it is a known, previously-repeated failure mode — the API exists
  and does not deliver on its own claim.

  **Do not assume this is done. Verify it**: after writing the program, run
  it against a realistically-sized workload (not a toy case) and issue a
  real `signal_query(..., "status", "")` while it is genuinely still busy.
  If the reply is slow, or only arrives once the work has already finished,
  the yield is missing or too coarse — go back and add/shorten it. A short
  demo-sized run is not sufficient evidence that this works.

- **Rule**: For any unit of work whose loss would matter if the process
  crashed mid-task, use the message queue (`queue_publish`/`queue_consume`/
  `queue_ack`) for durable checkpointing, not signals — signals are live,
  in-memory, and gone the instant either side stops running. Only call
  `queue_ack` once the corresponding work is genuinely, verifiably complete;
  acking early defeats the entire mechanism.

- **Rule**: If another PatLang program might reasonably need to find this
  one without being told a port number in advance, call `signal_announce`
  right after claiming the port, with an action list that accurately
  reflects the `when` handlers actually implemented — an announced
  capability the program doesn't really have is worse than no announcement.

- **Report explicitly, either way**: when a long-running program is
  delivered, state plainly whether status/progress reporting and
  crash-safe resumability were included, and if either was scoped out,
  say so — the same standard applied elsewhere in this file to deferred
  mirror-sync work and known-gap test coverage. "It runs and produces the
  right output eventually" is not the same claim as "it can be checked on
  and safely interrupted," and the two should never be conflated in a
  summary.

---

## 7. Thread safety: `__vars` is one shared namespace across `parallel_map`/`thread_spawn` workers

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
