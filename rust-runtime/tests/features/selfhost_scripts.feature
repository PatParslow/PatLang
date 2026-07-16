# Guards against: the self-hosted (Stage 1) test/selftest scripts under
# self_hosting/ existing only as scripts a human has to remember to run by
# hand (`pat --ir-run self_hosting/regex_dsl_selftest.patlang`). They were
# never invoked by `cargo test`, so a regression in any of them (including
# the multi-line-continuation parser gap documented in
# self_hosting/tools/patlang_cheatsheet.md, and the comment-scanning /
# spurious-semicolon bugs that broke the live IDE) could sit unnoticed
# indefinitely -- nothing in CI ever ran them. This feature wires each
# existing self-hosted suite into the automated run, and adds targeted
# regression cases for the specific parser gaps found this session.

Feature: Self-hosted (Stage 1) test suites run under cargo test
  As a maintainer of the self-hosted PatLang compiler
  I want the self-hosted test/selftest scripts to run automatically
  So that a regression in them is caught by `cargo test`, not by hand

  Scenario: the point-of-sale library's unit/integration/Gherkin suite passes
    Given the self-hosted test suite "pos"
    When I run it interpreted
    Then the self-hosted suite reports all tests passed

  Scenario: the self-hosted regex DSL selftest passes
    Given the self-hosted test suite "regex_dsl"
    When I run it interpreted
    Then the self-hosted suite reports zero parse errors and every expect/actual pair matches

  Scenario: the self-hosted syntax DSL selftest passes
    Given the self-hosted test suite "syntax_dsl"
    When I run it interpreted
    Then it exits successfully
    And stdout contains "parse errors: 0"
    And stdout contains "AST.RegisterRoute"

  # Covers reflection (source -> AST -> JSON, lib/reflect.patlang) and the
  # self-hosted Ruby transpiler (lib/transpile_ruby.patlang) -- see
  # optimized-zooming-snowglobe.md. Requires a `ruby` interpreter on PATH
  # for its integration check (shells out via exec_capture to actually run
  # the transpiled output); the unit-level AST/emission checks don't.
  Scenario: the reflection and ruby-transpiler selftest passes
    Given the self-hosted test suite "reflect_transpile"
    When I run it interpreted
    Then the self-hosted suite reports all tests passed

  # The inductive-synthesis engine's selftest suite
  # (self_hosting/synthesis_*_selftest.patlang, 11 suites covering
  # milestones 1-5 of the BDD-driven synthesis system -- see the plan
  # "wondering-about-extending-patlang-modular-shore") is deliberately NOT
  # wired into cargo test/cucumber: it's run via a PatLang-native runner
  # instead (`pat --ir-run self_hosting/tools/run_synthesis_selftests.
  # patlang`), so exercising it needs nothing Rust-side beyond the base
  # runtime that executes any PatLang program. See that tool and
  # patlang-inductive-synthesis.html on parslow.net for the full writeup.

  # Regression case for the documented self-hosted-parser gap: parse_add /
  # parse_mul don't skip newlines before checking for a continuation
  # operator, unlike the native Rust frontend, so a leading `+` on the next
  # line silently truncates the expression instead of continuing it. This
  # exercises the SELF-HOSTED frontend specifically (lexer/parser/lower
  # written in PatLang itself, run via run_ir), not the native Rust one.
  Scenario: self-hosted frontend correctly continues a multi-line addition
    Given a PatLang program:
      """
      include "lib/lexer.patlang"
      include "lib/parser.patlang"
      include "lib/lower.patlang"

      let src = "print(1
        + 2
        + 3)"
      let toks = tokenize(src)
      let ast = parse_program(toks)
      let ir = lower_program(ast)
      run_ir(ir)
      """
    When I run it interpreted
    Then it prints exactly "6"
