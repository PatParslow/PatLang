Feature: numeric tower completeness (Phase 16 of the full-language expansion)

  Checked directly (a probe run under --ir-run) before writing any new
  mechanism: this needed none. The self-hosted parser.patlang produces a
  single "Num" AST tag for every numeric literal -- no separate BigNumber/
  Float shape exists at all -- carrying only the raw decimal text, which
  bm_lower_expr already passes straight through to a Const instruction,
  evaluated via the REAL `to_num` at runtime. bm_apply_bin's own `l + r`
  etc. are genuine PatLang operators too. Both already perform the real
  language's full int/bigint/rational/float auto-promotion for free --
  this phase adds only `type_of(x)` so that claim is independently
  checkable from a block-model program's own output, not left as an
  unverified inference.

  Scenario: integer overflow auto-promotes to bigint
    Given an addition whose result overflows a plain integer
    When it runs
    Then the result's own type is bigint, not a silently wrapped or truncated integer

  Scenario: integer division that doesn't divide evenly auto-promotes to rational
    Given a division whose result isn't a whole number
    When it runs
    Then the result's own type is rational

  Scenario: an ordinary integer operation stays a plain int
    Given an addition that neither overflows nor divides
    When it runs
    Then the result's own type is int, not silently promoted to bigint

  Scenario: mixing a float into an operation produces a float
    Given an addition between a float and an int
    When it runs
    Then the result's own type is float
