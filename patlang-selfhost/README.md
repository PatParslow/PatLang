# patlang-selfhost

A pure-patlang implementation of the patlang compiler and interpreter, designed for modularity, contract-based development, and advanced language features.

## Goals
- Fully self-hosted patlang: compiler, interpreter, and standard library written in patlang.
- Highly modular architecture: each component (lexer, parser, IR, etc.) is a separate module with clear contracts.
- Use patlang's contract-by-design and logic inference features for robust, maintainable code.
- Reference the Rust or Ruby runtime only via minimal, well-defined interfaces.

## Structure
- `src/` — core modules (lexer, parser, IR, compiler, interpreter, stdlib)
- `contracts/` — contract/interface definitions for each module
- `tests/` — test suites for each module

## Getting Started
- See `contracts/` for module APIs and invariants.
- See `tests/` for usage and validation examples.

---

This project is the foundation for a fully self-hosted, extensible, and robust patlang ecosystem.
