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

  Scenario: a genuine host function called as a bare statement also gets the generic fallback
    Given a program that calls sb_push as a bare statement, its own return value never consumed
    When it runs through bm_lower_program/bi_run
    Then it produces exactly what pat --ir-run produces for the identical source

  A real, previously-missing case, found while re-attempting Phase 18's
  own zs_schema.patlang checkpoint (self_hosting/lib/zs_schema.patlang's
  own `zs_lines()` calls `sb_push(buf, sc_char(h, i))` exactly this way):
  `bm_lower_expr`'s own generic CallHost fallback only ever covered
  VALUE-context calls; `bm_lower_stmt`'s own separate bare-statement
  dispatch chain (used for a call that's a whole statement on its own,
  not part of a larger expression) never got the analogous fallback at
  all, still ending in "a call to anything other than print, a box_*/
  global/handler builtin, or a declared block" for any host function not
  individually named. Fixed the same way as the value-context case, at
  the SAME shared dispatch point, discarding the (real Call's own,
  always-present) return value via the identical `Store "__bm_discard"`
  convention this file's own other bare-statement builtins (Fact,
  box_set, etc.) already use.

  With both this and the nested-while fix (spec_library/block_model/
  loop_blocks.feature), self_hosting/lib/zs_schema.patlang -- the exact
  file Phase 18's own checkpoint named -- now lowers COMPLETELY under
  bm_lower_program, confirmed directly by lowering the real, unmodified
  file end to end, not a synthetic excerpt.

  Scenario: self_hosting/lib/zs_schema.patlang lowers completely
    Given self_hosting/lib/zs_schema.patlang, real and unmodified
    When it is lowered through bm_lower_program
    Then it lowers completely, with no unsupported construct left anywhere in it

  A second, deeper finding turned up while re-verifying self_hosting/lib/
  schema_bdd_selftest.patlang with real `include` expansion applied (see
  this project's own plan doc, Phase 22): `bm_lower_expr`'s own "Member"
  case (`obj.prop`) unconditionally assumed the receiver is a Box-wrapped
  Handler-shaped object (Phase 13's own class-field-access
  representation), routing EVERY `.prop` -- including the extremely
  common `.length` idiom on an ordinary String or List -- through
  `BoxGet`+`HandlerLookup`. This is doubly wrong for a primitive value:
  semantically (a raw String/List is not a Handler-shaped assoc-list) and
  mechanically (`BoxGet` is native-x64-only, since `heap.patlang`'s own
  `bm_box_read` calls `mem_peek_qword` directly, which neither the
  interpreter nor `rust-runtime/src/ir/hosts.rs` implement). Confirmed via
  a minimal, standalone repro (`let s = "hello"; print(s.length)`,
  independent of either schema file) crashing with "host fn
  'mem_peek_qword' not found" before this fix. Fixed by mirroring the REAL
  self-hosted `lower.patlang`'s own Member case exactly (that file's own
  `lower_expr`, `ty == "Member"` arm): `.length`/`.len` now lowers
  straight to `CallHost "len"` -- a genuine, already-"feature complete"
  host function that works correctly under BOTH backends -- with
  `BoxGet`+`HandlerLookup` reserved for every OTHER property name
  (genuine object field access, unchanged, still native-x64-only as
  before). A real, incidental capability gain, not just a bug fix:
  `.length` now works under the INTERPRETER for the first time, where
  genuine `obj.field` access still correctly requires native compilation.

  Scenario: .length/.len on an ordinary String or List works under the interpreter, distinct from Box+Handler object-field access
    Given a program that takes the .length of a String and of a List, never a Box-wrapped object
    When it runs through bm_lower_program/bi_run under the interpreter
    Then both lengths match exactly what pat --ir-run produces for the identical source

  A sixth finding, from the same re-attempt: `and`/`or` were being
  lowered like every other `Bin` op -- eagerly evaluating BOTH sides,
  then a plain `Bin` instruction, which `interp.patlang`'s own
  `bm_apply_bin` has no case for at all ("unknown Bin op hash"). Doubly
  wrong regardless of the missing-op error: real PatLang short-circuits
  (`self_hosting/lib/lower.patlang`'s own `"and"`/`"or"` arms), so
  eagerly evaluating the right-hand side can run code that should never
  run at all. Found via `self_hosting/lib/test.patlang`'s own
  `run_feature` (`(c == 10) or (c == -1)`). Fixed by mirroring
  `lower.patlang`'s own short-circuit lowering exactly, using this
  engine's own existing `JumpIfFalse`/`Jump`/`Un`/`Const` instructions --
  no new bytecode needed.

  Scenario: and/or genuinely short-circuit under block-model, not just avoid the missing-op error
    Given an or whose left side alone determines the result, with a right side that would crash if evaluated
    When it runs through bm_lower_program/bi_run
    Then the right side never runs, matching exactly what pat --ir-run produces for the identical source

  A seventh finding, one level deeper in the same checkpoint:
  `bm_fv_expr` (`self_hosting/block_model/free_vars.patlang`), the
  free-variable analysis `bm_lower_while` relies on, had no case at all
  for `"Index"` (`obj[idx]`) or `"List"` (`[a, b, c]`) AST nodes -- both
  silently fell through to "no free references", so a loop-body variable
  referenced ONLY via indexing or ONLY inside a list literal was
  invisibly missing from every caller's own captured set. Found chained
  through this same checkpoint: `self_hosting/lib/list_copy.patlang`'s
  own `list_copy` (`l[i]`, `l` never referenced any other way in the
  loop body) and `self_hosting/lib/pmap.patlang`'s own `pmap_put`
  (`list_push(out, [key, value])`, `value` never referenced any other
  way). Fixed by adding `"Index"`/`"List"` cases to `bm_fv_expr`
  (recursing into the object+index sub-expressions, and into every list
  item, respectively) -- plus `"Member"` (`obj.prop`), the same class of
  gap, fixed opportunistically in the same pass since it shares the
  exact same root cause, though not independently exercised here (real
  object field access is native-x64-only, so this specific combination
  --  a variable captured only via `.field` access inside an
  interpreted loop -- has no way to be driven under the interpreter
  alone).

  Scenario: a loop-body variable referenced only via indexing, or only inside a list literal, is still captured
    Given a function using list_copy's own l[i] idiom and pmap_put's own [key, value] idiom, each inside its own while loop
    When it runs through bm_lower_program/bi_run
    Then every value matches exactly what pat --ir-run produces for the identical source

  An eighth finding (GitHub issue #154), surfaced the moment the real
  `schema_bdd_selftest.patlang` first ran end to end: `interp.patlang`'s
  `JumpIfFalse` tested `== false` strictly, so `""`, `0` and `[]` used as an
  `if`/`while` condition counted as TRUE where the real engine treats them
  as false (`Un "not"` already used the host's own truthiness, so `if x` and
  `not x` disagreed with each other). `self_hosting/lib/test.patlang`'s own
  `if filter then` (filter == "") took the wrong branch, printing
  `Scenario: X  []` under block-model where `pat --ir-run` prints
  `Scenario: X`. Fixed by using the host's own truthiness in `JumpIfFalse`.

  Scenario: a non-boolean value used as an if or while condition has the same truthiness as the real engine
    Given a program using "", 0, [], non-empty values, true and false directly as if conditions, and an empty list as a while condition
    When it runs through bm_lower_program/bi_run
    Then every branch taken matches exactly what pat --ir-run produces for the identical source

  Phase 18's own checkpoint, finally met: the real, unmodified
  `self_hosting/schema_bdd_selftest.patlang` (the LibraryLoans/BorrowBook
  worked example, driven through the real Gherkin runner and the
  `zs_schema`/`schema_bdd` libraries) is lowered through `bm_lower_program`
  with real `include` expansion applied and run to completion via
  `bi_run_from`. Its pass and fail counts are read out of the RETURNED
  `__globals` (not via `get_global` from the driver's own scope, which is a
  separate store and produced an earlier vacuous 0/0), so 5 passed / 0
  failed is a real result and not the absence of one.

  Scenario: the real schema_bdd_selftest.patlang runs end to end under block-model with the same results as the real engine
    Given self_hosting/schema_bdd_selftest.patlang, real and unmodified, with its includes expanded
    When it is lowered through bm_lower_program and run to completion
    Then all five of its checks pass, its Gherkin output has no stray tag suffix, and its counts are read from the run's own final globals

  A ninth finding (GitHub issue #159), from running the real `step_match` and
  `zs_schema` selftests: `CallHost` dispatches through
  `self_hosting/lib/interp.patlang`'s `interp_call_host`, which has
  `sc_len`/`sc_code`/`sc_char` but not `sc_substr`, though the real runtime
  does and `step_match.patlang`'s `sm_match` calls it. That file is one of the
  four this plan protects until the cutover is authorized, so rather than
  edit it, this engine now has its own extension table
  (`bi_call_host_extension`, in `self_hosting/block_model/interp.patlang`),
  consulted only AFTER the shared table returns an error so the success path
  pays nothing. The table grows only on evidence. Both an ASCII and a
  non-ASCII string are checked, since the real host takes a different path
  for each.

  Scenario: a host function the shared dispatcher lacks is served by this engine's own extension table
    Given a program calling sc_substr on an ASCII and on a non-ASCII interned string, and then a host function that exists nowhere
    When it runs through bm_lower_program/bi_run
    Then the substrings match pat --ir-run exactly and the unknown host function still fails with the unchanged message

  A correction to an earlier scenario in this same file, found while running
  the full suite against top-level statement support (GitHub issue #155):
  "self_hosting/lib/zs_schema.patlang lowers completely" had been lowering the
  RAW file, whose `include "..."` lines the self-hosted parser turns into a
  bare `include` expression plus a stray string and `bm_lower_program`
  silently dropped. So the claim was true of the file's own text and nothing
  more -- it never exercised a line of `zs_expr`, `pset`, `pmap`, `list_copy`
  or `block_model_compat`. Top-level statement support made that silence loud,
  which is how it surfaced. The fixture now expands the includes first, so the
  scenario's claim ("with no unsupported construct left anywhere in it")
  covers the whole include closure. Checked every other fixture that reads a
  file: the remaining two use `read_file` as the host operation under test,
  not to lower a file, so none has the same flaw.
