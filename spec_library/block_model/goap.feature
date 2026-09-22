Feature: logic programming facts (Phase 15 of the full-language expansion)

  `fact(pred, a, b)`/`query(pred, a, b)`, checked directly against
  rust-runtime/src/ir/hosts.rs before writing any lowering code: both take
  exactly three scalar arguments, not a list, so neither one needs this
  engine's missing list-literal support at all. `rule`/`goal` declarative
  sugar (RuleDecl/GoalDecl) DO build compound lists and are explicitly
  deferred alongside Phase 17's own generic host-call/list-literal work,
  not attempted here with half the needed machinery.

  A real finding worth recording, not assumed uniform with Fork B: fact's
  own backing store is a `thread_local!` HashMap in the host runtime,
  entirely outside PatLang's `__vars`/`set_var`/`get` mechanism and
  therefore outside this engine's own `__globals` threading (Phase 4) too.
  A fact asserted in one block is visible from any other block not
  because `__globals` carried it there, but because it was never scoped
  by this design's own mechanism in the first place -- a real gap in the
  design doc's own Fork B coverage (which only names `set_var`/`get` and
  `new`/`send`), recorded here rather than silently treated as handled.

  Scenario: a fact asserted in one block is queryable from a different block, reached via a jump
    Given a block that asserts a fact, then jumps to a different block
    When that different block queries for the same fact
    Then it finds it, with no globals-view section involved at all

  Scenario: querying for a fact that was never asserted finds nothing
    Given a block that queries a predicate no fact was ever asserted under
    When it runs
    Then the query reports zero matches
