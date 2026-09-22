Feature: a static flight check demotes the runtime check to a fallback (Block Ownership Model, Fork C)

  Fork C (docs/plans/block-ownership-model.md, section 6) decided a
  hybrid: prove exclusivity statically wherever the flight check can, and
  fall back to Phase 3's runtime refcount check for whatever it genuinely
  can't determine -- never rejecting a program outright, never claiming
  more than what's actually checked. self_hosting/block_model/
  flight_check.patlang is that analysis, deliberately narrow (see its own
  header): it proves the common, straight-line case (a box created and
  mutated a few times in the same block, before anything else happens)
  and honestly defers everything else, including anything arriving as a
  parameter, to the runtime check. Native x64 only, like Phase 3 --
  Box operations are inherently native-only in this engine.

  Note on scope: this engine has no equivalent of `run_ir` (compiling and
  running a fragment mid-execution), so there is nothing to re-fire this
  check against at such a point -- named here as a real absence, not a
  skipped requirement. A "genuinely unsafe program rejected before it
  runs" scenario also does not apply to aliasing specifically in this
  hybrid design: an aliased mutation is always handled SAFELY, by
  cloning, never rejected -- rejection (ContractFail) is Phase 3's own,
  separate mut/immut-parameter check, not this phase's job.

  Scenario: a provably-safe sequence of mutations skips the runtime check entirely
    Given a box created and mutated twice in the same straight-line block
    When the program runs
    Then the runtime-check counter stays at exactly zero and both mutations still produce the correct value

  Scenario: a mutation through a parameter falls back to the runtime check
    Given a box mutated through a parameter reference
    When the program runs
    Then the runtime-check counter is greater than zero and the mutation still produces the correct value
