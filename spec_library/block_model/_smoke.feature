Feature: block-model harness smoke test (Phase 0 scaffolding only)

  This file exists only to prove run_block_model_spec_suite.patlang's own
  wiring works -- the Gherkin runner, step registration, and t_report() all
  execute correctly on the block-model suite's own files, independent of
  spec_library/language's existing suite. Delete this file once Phase 1
  (spec_library/block_model/refcounted_heap.feature) has a real scenario.

  Scenario: the harness itself runs
    Given the block-model spec harness
    When a trivial step is dispatched
    Then it reports a pass
