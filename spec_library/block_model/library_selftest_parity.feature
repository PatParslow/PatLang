Feature: real library selftests run under block-model with the real engine's own results (Phase 18's checkpoint, generalized)

  Phase 18's checkpoint is that real, unmodified PatLang library code runs
  correctly through the block-model engine instead of `pat --ir-run`. The
  first instance was `schema_bdd_selftest.patlang`; this feature makes it a
  standing gate over every ported library that has a selftest, each driven
  through the SAME generic driver
  (spec_fixtures/selftest_under_block_model.patlang): real `include`
  expansion, `bm_lower_program`, `bi_run_from`, and the pass/fail counts
  read out of the run's own returned `__globals` -- never a vacuous 0/0.

  "Passes" here is a strong claim, checked three ways per selftest: every
  line the real engine prints (each `ok:`, the totals) appears identically,
  in order, at the start of block-model's own output; the run's own
  `t_fail` is 0; and its `t_pass` equals the real engine's own count.

  Each selftest is a script-style program (top-level `t_init()`, `let`,
  `check(...)`), so this gate is what proves top-level statement support
  (issue #155) on real programs rather than synthetic ones. Getting them
  here found, and each was fixed under its own issue: #153 (`apply` with
  arguments), #154 (condition truthiness), #155 (top-level statements),
  #157 (a bare tail call returned the wrong shape), #158 (free-variable
  analysis ignored `while`/`assert`/`match`/member-assign statements) and
  #159 (`sc_substr` missing from the host table), plus a mechanical port of
  three selftests' own ambient `set_var`/`get` calls to
  `set_global`/`get_global`.

  Not in this gate, deliberately: `zs_refine_selftest`, `zs_explore`'s
  breadth-first search keeps its visited set in an ambient hash-backed
  Dict and its abort/progress flags in ambient state, and replacing the
  Dict with an assoc-list Handler would make exploration quadratic in the
  REAL engine too -- a design and benchmark question tracked in its own
  issue, not a rename.

  Scenario: pset_selftest runs under block-model
    Given self_hosting/pset_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of pset_selftest match what pat --ir-run produces

  Scenario: pmap_selftest runs under block-model
    Given self_hosting/pmap_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of pmap_selftest match what pat --ir-run produces

  Scenario: step_match_selftest runs under block-model
    Given self_hosting/step_match_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of step_match_selftest match what pat --ir-run produces

  Scenario: zs_expr_selftest runs under block-model
    Given self_hosting/zs_expr_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of zs_expr_selftest match what pat --ir-run produces

  Scenario: zs_schema_selftest runs under block-model
    Given self_hosting/zs_schema_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of zs_schema_selftest match what pat --ir-run produces

  Scenario: schema_bdd_selftest runs under block-model
    Given self_hosting/schema_bdd_selftest.patlang, real and unmodified
    When it runs under block-model with real include expansion
    Then the output and counts of schema_bdd_selftest match what pat --ir-run produces
