# Plan: sandboxing effectful primitives during synthesis-engine probing

**Status: Part 1 (PatLang-level effect gate) implemented and verified
(2026-09-06). Part 2 (OS-level sandboxing) is deferred design, not
scheduled — written down now because the user flagged it as needed before
anyone other than the project owner runs this.**

## Context

The enumerative synthesizer (`self_hosting/lib/synthesis_by_example.patlang`'s
`synthesize_from_examples`, and its GOAP-driven twin in `goap_synthesis.patlang`)
doesn't just reason about candidate primitive calls abstractly — during
search it actually CALLS the real `try_` wrapper for every type-correct
candidate it builds, against real sample-binding values, to see whether the
result matches the user's examples (`sbe_eval`'s `Call` dispatch ->
`sbe_call_prim`). For a pure primitive (`add`, `substr`, ...) that's free:
wrong candidates just produce a wrong value, discarded. For an EFFECTFUL
primitive it's not free: a candidate the search built purely because its
argument types happened to line up, with no relation to what the user
actually wants, still really runs. This was found empirically while
building `docs/plans/synthesis_tagging_design.md`'s demo: including
`tcp_connect`/`tcp_listen` unfiltered in a broad candidate pool made the
search genuinely attempt `tcp_connect(<sample string>, <sample int>)`
mid-search, raising a live "No such host is known" OS error — and PatLang
has no try/catch, so that's fatal, not recoverable.

Today's registry only wraps two effectful primitives (`tcp_connect`,
`tcp_listen`, both tagged `"effectful"` per the tagging design). But
`rust-runtime/src/ir/hosts.rs` already implements several more real
effects that nothing stops a future session from wrapping into the
registry the same way: `write_file`/`write_file_bytes` (arbitrary path
overwrite), `exec_capture`/`exec_capture_io` (arbitrary external process
execution), `read_file`/`read_file_bytes` (arbitrary path read). Any of
these, wrapped and registered without care, would be just as reachable
from a broad, uncurated candidate pool as `tcp_connect` was.

## Part 1 (implemented): a PatLang-level effect gate in the evaluator

Structural, not advisory — the search itself refuses to invoke an
effectful primitive it wasn't explicitly told it may, regardless of what
ended up in a caller's `primitive_names` pool.

- `self_hosting/lib/primitive_registry.patlang`: `pr_is_effectful(entry)`
  (reads the existing `"effectful"` free tag — see `synthesis_tagging_design.md`
  §2 — through `pr_tags`, so effect-marking reuses the tagging
  infrastructure rather than inventing a second metadata channel);
  `pr_set_effects_allowed(registry, names)` / `pr_effects_allowed(registry)`,
  storing the allowlist as `__effects_allowed__` directly on the registry
  Dict, the same pattern `__by_ret_type__`/`__by_tag__` already use — so
  `sbe_eval`'s signature never has to change to thread a new parameter
  through its ~15 existing call sites, and the allowlist automatically
  travels wherever the registry object itself is passed (including into
  `goap_synthesize_from_examples`'s parallel-map workers, which already
  receive the registry via `set_var`/`get("__vars", ...)`).
- `self_hosting/lib/synthesis_by_example.patlang`: `sbe_eval`'s `"Call"`
  dispatch checks `pr_is_effectful(entry)` immediately after the registry
  lookup — before evaluating the call's own arguments, before calling
  `sbe_call_prim` — and returns `[false, ""]` (an ordinary non-match, not
  a special error a caller has to handle) unless `prim` is present in
  `pr_effects_allowed(registry)`. A fresh registry's allowlist is `[]`:
  no effects run during search unless a caller explicitly opts one in.
  A composite never needs its own check: replaying its `inner_ast`
  re-enters `sbe_eval`, which re-applies the same gate wherever the
  effect actually lives inside it.
- Verified in `self_hosting/synthesis_effect_sandbox_selftest.patlang`
  (9 checks): deny-by-default (including inside a nested `If` condition,
  and confirming a bad `tcp_connect` port — which would otherwise raise a
  FATAL, uncatchable error — never gets attempted); pure primitives
  completely unaffected; explicit opt-in via `pr_set_effects_allowed`
  genuinely flips it (checked against `tcp_listen(0)`, an OS-assigned
  loopback bind — no external network dependency, safe to run anywhere);
  the allowlist is per-name, not blanket. Also re-verified end to end in
  `self_hosting/examples/synth_demo_tag_narrowed_search.patlang`, which
  now feeds `tcp_connect`/`tcp_listen` directly into an unfiltered
  20-name broad-pool search and derives the correct answer without ever
  touching the network.

## Part 2 (planned): OS-level sandboxing

What Part 1 does NOT cover, worth being explicit about before anyone
other than the project owner runs this:

1. **Depends on correct labeling.** `pr_is_effectful` only sees what a
   human tagged `"effectful"` when wrapping a new host primitive into the
   registry. PatLang has no static effect inference — a forgotten tag on
   a newly-wrapped `write_file` primitive is a real, silent gap, not a
   hypothetical one.
2. **Only covers the registry-mediated path.** The gate lives inside
   `sbe_eval`'s `Call` dispatch — it protects the SYNTHESIZER's own
   candidate evaluation. It does nothing for arbitrary PatLang code that
   calls a host primitive directly (`write_file(...)` as ordinary source,
   not through the registry/`sbe_eval` at all), which is a different
   trust boundary: "can the search accidentally misuse an effect" vs.
   "can untrusted PatLang source do anything at all."
3. **No resource ceiling beyond memory.** The interpreter already has a
   process memory safety cap (`PATLANG_MAX_MEM_MB`, hit directly while
   building the tagging demo), but nothing bounds CPU time or wall clock
   for a runaway search.

None of this matters while only the project owner runs searches locally.
It starts mattering the moment someone else's goal/examples drive this
engine — a hosted synthesis service, a shared CI job, anything where the
`primitive_names` pool or the examples themselves come from outside.

### Candidate designs, layered rather than either/or

- **A. Runtime-level defense in depth (cheapest, closes gap #2 above).**
  `rust-runtime/src/ir/interpreter.rs`'s host-call dispatch has exactly
  two chokepoints (`self.host.get(name)...` at lines 311 and 425) where
  every host function call already passes through uniformly. A
  `PATLANG_SANDBOX`-style runtime flag, consulted right there against a
  small hardcoded effect classification (the same primitive names Part 1
  already treats as effectful, plus any host function Part 1 doesn't
  even know about, like `write_file`/`exec_capture` today), would refuse
  an effect for ANY PatLang code path, not just ones that go through the
  registry/synthesizer. This is the natural next layer, independent of
  whether Part 1 exists, and doesn't require a new process or IPC.
- **B. OS-level process restriction for "run someone else's search."**
  On Windows (the project's primary target): launch the search under a
  restricted token / Job Object (or an AppContainer) that denies network
  and filesystem access outside a designated scratch directory and caps
  CPU/memory/wall-clock — coarse-grained (the whole process), but simple
  to reason about and requires no interpreter-internal changes. The
  interpreter's OWN necessary I/O (reading the `.patlang` source, writing
  output) has to be carved out of the restriction, which is the main
  design work here: deciding the shape of that scratch/allowed-paths
  boundary.
  A Linux equivalent (namespaces/seccomp/cgroups) is a real non-goal for
  now — the project targets Windows first; revisit only if/when this
  actually needs to run there.
- **C. Privilege-separated worker process.** A small dedicated
  "evaluator" binary, spawned per search with OS-level restrictions
  already applied, that does nothing but receive candidate calls over a
  pipe and return results — the main interpreter (parsing, output,
  everything else) stays unrestricted. Strictly more engineering than B
  (a new IPC protocol) for a benefit B mostly already gets (the search
  itself is what needs restricting, and it's already a bounded,
  identifiable phase of the program); worth it only if B's "carve out the
  interpreter's own I/O" boundary turns out to be awkward in practice.

**Recommendation when this gets picked up**: build A first — it's a small,
self-contained change to two call sites, closes the "bypasses the
registry" gap Part 1 structurally cannot close, and is useful on its own
regardless of what happens with B. Reach for B only once there's an actual
scenario (a hosted service, a shared job) where someone else's
goal/examples drive a search — don't build process-level isolation
speculatively ahead of that need.

## Files to touch (Part 2, when scheduled)

- `rust-runtime/src/ir/interpreter.rs` — the sandbox check at the two
  `self.host.get(name)` call sites (design A).
- `rust-runtime/src/ir/hosts.rs` — wherever a new sandbox-flag/effect
  classification table lives.
- A new CLI flag or environment variable (`PATLANG_SANDBOX` or similar)
  threaded through `pat`'s entry point, analogous to the existing
  `PATLANG_MAX_MEM_MB`.
- Process-level restriction (design B) is native Windows API work
  (Job Objects / restricted tokens), not PatLang — a separate, larger
  session when actually scheduled.

## Verification (Part 2, when implemented)

- A RED/GREEN selftest analogous to `synthesis_effect_sandbox_selftest.patlang`,
  but proving the runtime-level gate blocks a DIRECT host-primitive call
  written as ordinary PatLang source (not routed through the registry at
  all) — the exact case Part 1 cannot cover.
- Confirm `self_hosting/synthesis_effect_sandbox_selftest.patlang` and
  `synth_demo_tag_narrowed_search.patlang` still pass unchanged (Part 2 is
  additive defense-in-depth, not a replacement for Part 1).
