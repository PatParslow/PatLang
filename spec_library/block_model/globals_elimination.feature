Feature: globals threaded through every block's own pointer (Block Ownership Model, Fork B)

  Fork B (docs/plans/block-ownership-model.md, section 6) decided on full
  elimination: fold all ambient state into explicit pointers. This phase
  realizes that for real: set_global(name, value)/get_global(name) read,
  from the source's own point of view, exactly like today's ambient
  set_var/get -- but self_hosting/block_model/lower.patlang secretly
  appends a hidden "__globals" parameter to every block and forwards it on
  every jump, so a middle block that never mentions a global at all still
  carries it structurally to whoever needs it next. Runs entirely under
  the interpreter (set_global/get_global never touch Phase 1's native-only
  heap).

  Scenario: a global set in one block is visible several jumps later
    Given a block that sets a global, then jumps through a block that never mentions it
    When a much later block reads that global back
    Then it sees the value the first block set, unchanged in between
