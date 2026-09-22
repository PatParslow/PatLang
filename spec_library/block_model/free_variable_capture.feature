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
