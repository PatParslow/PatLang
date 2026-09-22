Feature: minimal block/jump execution skeleton (Block Ownership Model, Fork A)

  Fork A (docs/plans/block-ownership-model.md, section 6) decided the
  block/pointer structure is the literal runtime execution mechanism, not a
  reasoning layer lowered to today's bytecode. This phase proves the
  smallest possible version: two blocks joined by a jump that carries a
  pointer, with no call stack anywhere in the engine (see
  self_hosting/block_model/interp.patlang's own header) and no block able
  to see anything beyond what its own jump explicitly handed it (section
  3.2). Scenarios run via exec_capture on dedicated driver fixtures
  (self_hosting/block_model/spec_fixtures/), matching require_ensure_assert
  .feature's own established pattern, since one of them is a genuine
  guaranteed-fail contract violation (fatal, out of process).

  Scenario: values pass correctly through a jump between two blocks
    Given a program with two blocks joined by one jump carrying two values
    When the program runs
    Then the second block computes the correct result using only what the jump handed it

  Scenario: a block cannot see a variable it was not explicitly handed
    Given a program where the second block references a name only the first block has
    When the program runs
    Then it fails with a guaranteed unbound-variable error naming that variable
