Feature: real native codegen for the block-model IR (Block Ownership Model, Fork A, Phase 9)

  Phase 9 (docs/plans/block-ownership-model-implementation-plan.md): the
  native half of Fork A's "front to back" -- self_hosting/block_model/
  native_codegen.patlang translates a BlockProgramIR into a single, real,
  flat FuncIR (blocks concatenated, JumpBlock expanded into ordinary
  Store instructions plus a real Jump), then reuses self_hosting/lib/
  codegen_x64.patlang's own, already-proven emit_program_x64 for
  everything else -- no new x64 emission code, no interpretation of the
  block-model IR at runtime at all. A real two-chunk build (mirroring
  self_hosting/build_x64_runtime.patlang's own established convention),
  linking against the already-built self_hosting/build/x64_runtime.obj,
  not a single bundled-source chunk (tried first, abandoned after
  codegen_x64.patlang's own hardcoded runtime-call asm text for
  overflow-checked arithmetic made textual renaming unsafe).

  A real bug was found and fixed building this, not just designed
  around in advance: JumpBlock expands into MULTIPLE instructions (a
  Store per forwarded value, plus a Jump), so a JumpIfFalse/Jump target
  computed against the original, one-JumpBlock-is-one-instruction
  numbering does not equal its own position in the expanded output --
  a loop's own JumpIfFalse landed mid-way through its own back edge's
  Store sequence instead of at the exit block's own, producing a
  genuine infinite loop. Fixed with a per-block index map from original
  instruction position to its own expanded position.

  Scenario: a loop-free, two-block program runs correctly through real native codegen
    Given a program that jumps from one block to another, forwarding two values
    When it is built and run as a real, fully native executable
    Then it prints the correct result

  Scenario: a small loop runs correctly and terminates
    Given a loop of a known, small iteration count
    When it is built and run as a real, fully native executable
    Then it prints the correct sum and the process exits cleanly, not hanging

  Scenario: the same loop shape at a much larger scale still matches the interpreted result
    Given the same benchmark loop used for the engine's own speed comparison, at N=800000
    When it is built and run as a real, fully native executable
    Then it prints the exact value every other execution path (interpreted, bi_run-compiled) already agreed on

  Scenario: block-to-block control flow compiles to real jumps, never calls
    Given the assembly emitted for the small loop above
    When the instructions between block labels are inspected directly
    Then every transfer of control between blocks is an ordinary jmp, with no call/ret introducing a call stack that was never there in the design
