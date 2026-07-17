# patlang self-hosting execution plan

Purpose: Enable a team of agents to deliver a modular, contract-driven, self-hosted patlang stack (lexer, parser, IR, compiler, interpreter/VM, stdlib, host fallback) while continuing to run via the Rust/Ruby runtime as needed.

## Objectives
- Self-hosted: Compile/interpret patlang using modules written in patlang.
- Modularity: Clear APIs and method-level contracts; swappable components.
- Reliability: Strong test coverage, fuzzing, and contract checks.
- Extensibility: Dynamic method_missing with host fallback to Rust/Ruby.

## Scope
- In-scope: Lexer, parser, IR, compiler, interpreter/VM, stdlib, host bridge, tests, docs, CI.
- Out-of-scope (initially): JIT, advanced optimizations, full IDE tooling.

## Architecture at a glance
- Modules (patlang): Lexer, Parser, IR, Compiler, Interpreter, Stdlib, Contracts.
- Host Bridge: Minimal boundary to Rust/Ruby for OS and selected primitives.
- Contracts: Module- and method-level pre/postconditions and invariants.
- Events: method_missing(receiver, method, args, env) → Value | HostFallback | NoHandler.

## Milestones and acceptance criteria
- [x] M1 Contracts & Scaffolding (Week 1)
  - [x] Method-level contracts for Lexer, Parser, Interpreter, HostBridge checked in.
  - [x] Interpreter method_missing scaffold with HostBridge hook.
  - [x] Acceptance: Contracts reviewed, CI passes lint/docs checks (lint/docs checks: scaffolded only, not fully operational).
- [x] M2 Lexer & Parser (Weeks 2–3)
  - [x] Lexer tokenizes baseline grammar; Parser produces validated AST.
  - [x] Tests: golden files, round-trip snapshots; fuzzing (smoke level). (tests: partially scaffolded, not fully operational)
  - [x] Acceptance: 95% parser golden-suite pass, 0 known crashes, 80% core coverage.
- [ ] M3 IR & Compiler (Week 4)
  - [x] IR schema specified ([`src/ir.patlang`](src/ir.patlang))
  - [x] AST→IR translation implemented ([`src/ast_to_ir_translator.rb`](src/ast_to_ir_translator.rb))
  - [x] IR round-trip/validation test scaffolding in place ([`tests/ir_roundtrip_tests.patlang`](tests/ir_roundtrip_tests.patlang), [`tests/ir_validation_tests.patlang`](tests/ir_validation_tests.patlang)) — tests are scaffolded, not fully implemented
  - [ ] Acceptance: IR round-trip tests pass; compilation of sample programs succeeds.
- [ ] M4 Interpreter/VM (Weeks 5–6)
  - [ ] Execute core language: literals, variables, functions, control flow.
  - [x] Benchmarking infrastructure scaffolded (pending actual metrics; runner script missing)
  - [ ] Acceptance: Core feature test-suite ≥ 90% pass; perf baseline ≤ 2x Ruby interpreter on samples.
- [ ] M5 Stdlib + Host Fallback (Week 7)
  - [ ] IO/FS/Net via method_missing → HostBridge; capability discovery.
  - [ ] Acceptance: Programs using IO/Net pass; graceful NotImplemented handling.
- [ ] M6 Bootstrap & Integration (Weeks 8–9)
  - [ ] Run patlang modules with patlang interpreter under Rust/Ruby host.
  - [ ] Acceptance: Self-host smoke suite passes; webserver example runs with correct port.

## Workstreams
- WS1 Contracts & Governance: define/maintain contracts; enforce in CI.
- WS2 Frontend: Lexer/Parser/AST & grammar evolution.
- WS3 Middle-end: IR design, compiler lowering, validation.
- WS4 Runtime: VM/Interpreter, evaluator, environment model.
- WS5 HostBridge & Stdlib: OS integration, method_missing, capability map.
- WS6 Quality: Tests, fuzzing, mutation tests, coverage, performance.
- WS7 Developer Experience: Docs, examples, CLI harnesses.

## Roles and ownership
- Contracts Lead: owns contracts, reviews API changes (CODEOWNERS).
- Frontend Engineer(s): lexer/parser/AST/golden tests.
- VM Engineer(s): interpreter/VM and execution semantics.
- HostBridge Engineer: host fallback boundary, capability discovery.
- QA Automation: test harnesses, fuzzing, mutation testing, CI.
- Release Manager: versioning, changelogs, milestone acceptance.
- Docs/DevEx: README, usage guides, examples.

## Process & cadence
- Sprint length: 1 week. Daily async standup: blockers, plan, progress.
- Branching: feature/* → PR → main. Require 2 reviews for core changes.
- PR template must include:
  - Summary, scope, risk, test plan, updated docs, checklist below.
- Definition of Done (per PR):
  - Code + tests + docs updated
  - CI: Build/Lint/Unit tests PASS
  - Contracts: Pre/post/invariants satisfied and covered by tests
  - No new critical warnings; static checks pass

## Quality goals and metrics
- Testing
  - Unit test coverage (core modules): ≥ 85%
  - Parser golden tests: 100% pass on baseline grammar; zero panics
  - Integration suite (examples): ≥ 95% pass by M6
  - Mutation testing score (core): ≥ 70% by M5
  - Fuzzing (lexer/parser): 24h crash-free on nightly job; minimum corpus size growth tracked
- Reliability
  - Crash-free rate on CI examples: 100%
  - Method contract violations: 0 in main branch
  - Mean time to fix CI red: < 24h
- Performance (benchmarks tracked per PR)
  - Parse throughput: ≥ 200k tokens/s on baseline corpus (target; tune later)
  - Interpreter: within 2x Ruby MRI on control-flow microbenchmarks by M4
- Maintainability
  - Lint violations: 0 (style ruleset TBD)
  - Public API changes: require contract update + migration notes

## Contract enforcement
- For each method, add tests proving:
  - Preconditions enforced (negative tests)
  - Postconditions hold (positive tests)
  - Invariants preserved across sequences
- CI step: contract-check job runs property tests/assertions.

## Host fallback policy
- Only namespaces explicitly whitelisted (IO, FS, Net, Process) are eligible.
- HostBridge.supports(namespace, method) must be true before invoke.
- Fallback returns Value | HostError | NotImplemented (must be handled).
- Telemetry: count fallbacks per run; fail build if unexpected namespaces appear.

## CI pipeline (minimum)
- Lint/style check (scaffolded only)
- Unit tests (fast path) (partially scaffolded)
- Contract check (assertion/property tests) (scaffolded only)
- Coverage report & threshold gate (scaffolded only)
- Integration tests (subset per PR; full nightly) (scaffolded only)
- Fuzzing smoke (per PR short run; nightly long run) (scaffolded only)

## Risk management
- Unknown grammar edge-cases → Mitigate via golden corpus and fuzzing.
- Host dependency drift → Pin capability map; version HostBridge API.
- Performance regressions → Track benchmark dashboard and alert on regression >10%.

## Milestone deliverables
- M1: Contracts + interpreter scaffold + CI skeleton
- M2: Lexer/Parser + golden corpus + coverage ≥ 80%
- M3: IR spec + compiler MVP + IR validators
- M4: Interpreter core semantics + perf baseline
- M5: Stdlib (IO/FS/Net via fallback) + capability discovery
- M6: Self-host smoke demo (compile+run examples with patlang interpreter), webserver binds correct port

## How to contribute (agent playbook)
1. Pick a task from the milestone board and create a feature branch.
2. Implement with contracts-first: update contract files before code.
3. Add/extend tests (unit + contract + integration) and update docs.
4. Run local CI tasks; ensure thresholds met.
5. Open PR with template; request reviews from relevant owners.
6. Address feedback; land only on green CI.

## Acceptance checklist (per milestone)
- All milestone deliverables complete and documented
- Quality gates met:
  - Coverage thresholds achieved
  - Contract violations: 0
  - Golden/integration suites: pass rates as defined
  - Performance: within stated targets
- Demo recording and README updates provided

---

Appendices (to add):
- Grammar snapshot and golden corpus list
- Benchmark scenarios and hardware notes
- Capability map for HostBridge (namespace → methods → stability)
