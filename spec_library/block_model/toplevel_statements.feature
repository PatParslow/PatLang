Feature: top-level statements, script-style programs (GitHub issue #155)

  `bm_lower_program` used to lower only top-level `Func` and `When` (and
  register `ClassDecl`); every other top-level statement -- `let`, a bare
  call, `if`, `while` -- was silently ignored, and the program entered at
  its first declared function. Most of this repo's real programs are
  script-style (`t_init()`, `let x = ...`, `check(...)` at the top level),
  including the selftests of every library Phase 18 ported, so under
  block-model they ran nothing at all and exited cleanly with no output:
  a silent false pass, the same failure mode as the vacuous
  `t_pass=0, t_fail=0` found earlier.

  Every top-level statement that is not a declaration is now collected, in
  source order, into a synthesized zero-parameter `__main` function and
  lowered exactly like a function body, so `let`, bare calls, `if`, `while`
  and their nesting all reuse the existing machinery. When at least one
  such statement exists `__main` is the entry; otherwise entry selection is
  unchanged (the first declared function).

  Scenario: a script-style program's own top-level body runs, calling its declared functions
    Given a program whose main body is top-level let, calls, an if and a while, with its only function declared first
    When it runs through bm_lower_program/bi_run
    Then every printed value of the script matches exactly what pat --ir-run produces for the identical source

  Scenario: a program with only function declarations still enters at its first function
    Given a program with three functions and no top-level statements
    When it runs through bm_lower_program/bi_run
    Then only the first function and what it calls run, exactly as before

  Anything at top level the lowerer does not support must be loud. The real
  case is an un-expanded `include "x.patlang"` line: the self-hosted parser
  has no include handling, so it becomes a bare `include` expression plus a
  stray string literal, which used to vanish -- the root of an earlier
  methodology gap where "X lowers completely" claims never exercised X's
  own includes.

  Scenario: an un-expanded include directive at top level fails loudly instead of vanishing
    Given a program whose first line is an include directive that was never expanded
    When it is lowered through bm_lower_program
    Then it fails with a contract violation saying the include was never expanded, before anything runs
