Feature: library-level parity, generic host calls and list literals (Phase 18 of the full-language expansion)

  Phase 18's own checkpoint (docs/plans/block-ownership-model-full-
  language-plan.md) is confirmation that real, unmodified PatLang library
  code runs correctly through the block-model engine instead of
  `pat --ir-run`. A first attempt (2026-09-22) ran self_hosting/lib/
  zs_schema.patlang itself through bm_lower_program and failed
  immediately with "does not support: expression shape 'Call'" -- traced
  to two already-named, separately-scoped Phase 17 follow-ups this engine
  never built: a literal `[a, b, c]` had no lowering at all (no
  `BuildList` instruction existed in this engine's own bytecode), and
  every recognized host function needed its own individually-named `Call`
  case in lower.patlang -- there was no GENERIC fallback for a host
  function this engine had simply never seen the name of before.

  Both are filled in here, mirroring the REAL self-hosted lower.patlang's
  own equivalent cases exactly (its own `lower_expr`'s "List"/"Index"/
  "Call" arms), not invented from scratch: `["BuildList", n]` pops n
  values (pushed in written order) and pushes a fresh List; `lst[i]`
  lowers to an ordinary `["CallHost", "list_get", 2]` through the SAME
  new generic mechanism; and any Call whose callee isn't one of this
  engine's own individually-recognized builtins, and isn't a declared
  block-model function either, falls back to `["CallHost", name, argc]`,
  dispatched at runtime via self_hosting/lib/interp.patlang's own
  `interp_call_host` (reused as-is -- already "feature complete" for
  every stateless utility chunk: core, strings_ext, collections_handles,
  files, io_misc, math).

  Scenario: a List literal, indexing, and a genuine generic host call all run through the block-model engine
    Given a program that builds a List literal, indexes into it, calls list_len/list_push (never individually recognized by name in lower.patlang), and calls hash_string (a genuine stateless-chunk host function)
    When it runs through bm_lower_program/bi_run
    Then every value matches exactly what the real interpreter (pat --ir-run) produces for the identical source

  Re-attempting Phase 18's own original checkpoint with this new support
  in place (2026-09-23) finds the REAL next blocker, empirically, not
  assumed: lowering self_hosting/lib/zs_schema.patlang now gets further
  (past the original "expression shape 'Call'" failure) before hitting a
  DIFFERENT, deeper, PRE-EXISTING restriction from Phase 2 itself, not
  either of this phase's two named gaps -- "`return EXPR` where EXPR
  isn't a call to a declared block (no call stack to return a value up
  through yet)". A block-model function can only ever "return" via a
  TAIL call to another declared block (JumpBlock); it has no mechanism
  at all for returning a plain computed value (`return 5`, `return x +
  1`, `return some_helper_call_used_as_a_value`) -- which real library
  code needs constantly. This is Fork A's own foundational "no call
  stack" design choice (docs/plans/block-ownership-model.md section
  3.1), not an oversight this phase's own scope covers: fixing it would
  mean designing a genuine call-with-return mechanism for ORDINARY
  functions (this engine has exactly one such mechanism today, Emit,
  deliberately narrow and reserved for event handlers specifically -- see
  block_ir.patlang's own Phase 10 header) -- a separate, materially
  larger architectural decision, not attempted here.

  This phase's own checkpoint therefore still does not FULLY pass (real,
  unmodified library code still cannot run end to end), but the two gaps
  it was explicitly scoped to fill are done, verified, and the actual
  remaining blocker is now precisely diagnosed rather than bundled under
  a vague "closures/classes-with-methods, probably" guess.

  Scenario: the generic CallHost fallback rejects genuine ambient-state host functions
    Given a program that calls set_var/get in value context
    When it is lowered
    Then it fails with a guaranteed contract violation naming the ambient-state rationale, not a silent CallHost dispatch

  A real, previously-undisclosed bug in this same generic fallback was
  found and fixed while porting self_hosting/lib/zs_schema.patlang off
  `new("Dict", ...)` (Phase 21/22's own investigation of Phase 18's
  original checkpoint): `set_var`/`get`/`send` are genuine, real host
  functions (`interp_call_host` already supports all three), so the
  generic fallback would otherwise dispatch them straight through to the
  REAL, process-wide ambient `__vars`/`OBJECTS` store -- completely
  bypassing Fork B's own stated "full elimination of ambient globals"
  guarantee for any block-model program calling them directly instead of
  the blessed `set_global`/`get_global`/`handler_*` sugar. Confirmed
  exploitable via a direct repro (`let x = set_var("key", 42)` then
  reading it back through `get`) before fixing it, not assumed from
  reasoning alone. `new` was already blocked separately (Phase 13's own
  class-registry interception); `get`/`send`/`set_var` (in value
  context) were not, until now.
