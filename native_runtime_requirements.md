# Patlang-Native Runtime Requirements & Native Bridge Specification

## Overview

This document summarizes the requirements, constraints, and bootstrap/loader strategy for the patlang-native runtime. The goal is to enable a fully self-hosted, Ruby-independent execution environment for PaTLang, leveraging a minimal C native bridge for system integration.

---

## Requirements

- **Self-Hosting**: The runtime must execute PaTLang code natively, without Ruby dependencies.
- **Multi-Paradigm Support**: Must enable goal-oriented, logic, and reasoning-driven execution as described in [`NATIVE_PATLANG_LEXER_DESIGN.md`](NATIVE_PATLANG_LEXER_DESIGN.md) and [`NATIVE_PATLANG_PARSER_DESIGN.md`](NATIVE_PATLANG_PARSER_DESIGN.md).
- **Native Bridge**: Provide a C-based bridge for:
  - Memory management (allocation, deallocation, GC hooks)
  - System operations (I/O, environment access, process control)
  - Minimal, portable interface for integration with the patlang VM
- **Portability**: The bridge and runtime must be portable across major platforms (Linux, macOS, Windows).
- **Extensibility**: The bridge must allow future expansion for additional system features.
- **Isolation**: No Ruby code or dependencies at any layer.

---

## Constraints

- **No Ruby**: All runtime and bridge code must be implemented in C (or compatible native language) and PaTLang.
- **Minimalism**: The bridge must expose only essential primitives required for bootstrapping and core runtime operation.
- **Security**: System operations must be sandboxed or controlled to prevent unsafe access.
- **Determinism**: Memory and system operations must be predictable and testable.

---

## Bootstrap/Loader Strategy

1. **Initialization**: The native bridge is loaded by the host process (e.g., CLI or embedding application).
2. **Runtime Setup**: The bridge initializes memory management and system operation stubs, exposing C functions to the patlang VM.
3. **Module Loading**: Core patlang modules are loaded via the bridge, enabling self-hosted execution.
4. **Execution**: The patlang VM invokes bridge functions for memory and system operations as needed.
5. **Extensibility**: Additional system features can be exposed by extending the bridge and updating the loader logic.

---

## File Locations

- Native bridge source: [`native_evaluator/native_bridge.c`](native_evaluator/native_bridge.c)
- Native bridge header: [`native_evaluator/native_bridge.h`](native_evaluator/native_bridge.h)
