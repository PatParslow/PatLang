# PaTLang Roadmap — August 2025

This roadmap converts current status into an actionable 90-day plan with milestones, risks, and success metrics.

## Snapshot

- Self-hosting: Phase 1 (Ruby bridge) validated; Phase 2 (transpiler) architecture ready; Phase 3 (native compilation) planned.
- Parser: Phase 1 core complete (AST, precedence, error recovery, lexer integration). Open: event/goal/template syntax, statement boundaries.
- Lexer: Roadmaps/design complete; self-hosting validation plan defined.
- Runtime: Rust crate present; evaluator scaffolding exists; need AST contract and execution parity path.
- Tests: Working features validated; broader infra ~38% passing; multiple harnesses exist.

## 90-day plan

### Phase A (Weeks 1–2): Grammar stabilization, unified tests, CI

- Parser statement boundaries
  - Finalize `rust-runtime/docs/parser_statement_boundaries.md` and implement in native parser.
  - Add tests for: implicit newline termination, semicolon inline statements, multi-line continuation via parens/blocks.
  - Done when: all boundary tests pass with no expression regressions.

- Test unification and oracle
  - Single entrypoint to run Ruby evaluator and native parser suites.
  - AST parity check: normalize ASTs from Ruby vs native for each `.patlang` sample.
  - Done when: CI emits an AST parity report and lists mismatches.

- CI scaffolding
  - Add GitHub Actions for Ruby and Rust (manual trigger initially).
  - Rust: fmt check, clippy (deny warnings), tests. Ruby: bundle install + rake.
  - Done when: both workflows run clean locally or in PR trial branches.

### Phase B (Weeks 3–6): Parser completion and runtime integration

- Parser phases 2–3
  - Implement statement-level grammar: blocks, if/elif/else, when/event, goal, template.
  - Integrate reasoning-based disambiguation rules.
  - Enhance error recovery for statement context.

- Runtime integration
  - Define versioned AST schema; add serde in Rust and JSON fixtures.
  - Implement evaluator subset: literals, ops, vars, assignment, if/else, calls.
  - Optional: bridge native AST into Ruby evaluator for semantic parity.

- Property-based tests
  - Mutate whitespace/boundaries to stress parsing; assert no crashes and stable AST.

### Phase C (Weeks 7–12): Self-hosting demo and performance

- Self-hosting demo
  - Target either native lexer/parser source or build-tool subset.
  - Path A: native lexer+parser tokenize/parse themselves; prove AST parity.
  - Path B: minimal transpiler (Patlang→Ruby/Rust subset) for selected modules.

- Performance harness
  - Bench on large `.patlang` files; budget: ≤1.1× Ruby baseline initially, aim to beat by end of phase.

- Hardening and docs
  - Finalize grammar docs with examples & edge cases.
  - Add parsing trace mode (debug builds) for diagnostics.

## Risks & Mitigations

- Ambiguous natural-language grammar → explicit precedence/associativity tables; targeted disambiguation tests.
- AST drift across implementations → versioned schema with normalization ahead of parity checks.
- Perf regressions → CI benches with budgets and alerts.
- Scope creep in self-hosting → start with demonstrator scope; iterate.

## Success criteria

- Phase A: CI scaffolds land; boundary tests added (≥25); AST parity report exists.
- Phase B: ≥95% AST parity on corpus; runtime evaluator subset executes with parity; property tests pass.
- Phase C: Self-hosting demo deterministic; parser meets ≤1.1× Ruby baseline; docs finalized.

## Pointers

- Parser docs: `rust-runtime/docs/parser_statement_boundaries.md`
- Rust AST: `rust-runtime/src/ast.rs` (now serde-enabled)
- Tests: `rust-runtime/tests/*`
- CI: `.github/workflows/ci-rust.yml`, `.github/workflows/ci-ruby.yml`
