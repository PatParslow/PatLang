Feature: real free-variable analysis replaces wholesale loop capture (Block Ownership Model, Fork E)

  Fork E (docs/plans/block-ownership-model.md, section 6) decided on real
  free-variable analysis over wholesale capture, despite the added
  engineering cost. self_hosting/block_model/free_vars.patlang is that
  analysis, wired into bm_lower_while (section 4.1) to replace Phase 5's
  own wholesale placeholder. Runs entirely under the interpreter.

  Note on scope, stated plainly rather than glossed over: this engine
  never built closures as a feature, so free_vars.patlang has exactly one
  real consumer here (loop bodies) -- the design doc's own Fork E table
  compares four axes (implementation cost, memory retention, exclusivity
  cost, contract clarity); this engine can only demonstrate the first and
  last directly. The memory-retention and exclusivity-cost axes are about
  automatic refcount increments on every value copy, which this engine's
  own lower.patlang deliberately never implemented (box_share is the one
  explicit "make another reference" op it supports, per that file's own
  header) -- there is no automatic-capture-bumps-refcount behavior here to
  show improving, so this feature does not claim to.

  Scenario: an inherited section contains only variables the loop body actually references
    Given a loop preceded by an outer local the loop body never reads
    When the loop is lowered
    Then the loop head block's own declared params do not include that unreferenced local

  Scenario: the precise set is a real, measured subset of the wholesale set, not just "still works"
    Given the same loop body analyzed both ways on purpose
    When the wholesale set and the free-variable-analyzed set are compared directly
    Then the free-variable set is strictly smaller and excludes exactly the unreferenced local

  A gap in the ANALYSIS ITSELF (GitHub issue #158), found running the real
  `zs_expr_selftest.patlang` under block-model: `bm_fv_stmt`, the
  statement-level half of the analysis, handled only `Let`, `If`, `Expr` and
  `Return`. Comparing it against every statement kind the lowerer itself
  handles showed four that silently contributed no free variables at all:
  `While`, `Assert`, `Match` and `MemberAssign`. So both "everything after
  this loop" and "this loop's own body" skipped over any following or inner
  `while` entirely -- a variable used only inside one was never captured by
  the loops around it. The real instance was `ze_msort`'s merge, three
  loops in a row where `b` and `rn` are used only by the third
  (`while (a < ln) and (b < rn)`, `while a < ln`, `while b < rn`).

  The precision guarantee above is unchanged: an unreferenced local is
  still NOT captured. `Match` deliberately over-approximates (names a
  pattern binds are not removed from the free set), which can only capture
  something unnecessary, never miss something needed.

  Scenario: a variable used only inside a later or an inner while is still captured by the loops around it
    Given two loops in a row where the second alone uses some variables, and an outer loop whose inner loop alone uses another
    When it runs through bm_lower_program/bi_run
    Then every printed value of both loop shapes matches exactly what pat --ir-run produces for the identical source
