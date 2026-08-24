Specification: PatLang friendly_cli Terminal Evolution
1. Objective
Transform the friendly_cli module into a fully functional, self-healing interactive terminal and command execution wrapper. The goal is to provide a unified REPL interface that completely abstracts away Windows shell fragmentation (cmd, PowerShell, Git Bash) and offers intelligent error recovery ("self-healing") for both human users and AI coding agents.

2. Core Requirements & Architecture
A. The Unified REPL Loop
Interactive Prompt: Implement a clean, persistent command-line loop supporting line history, basic editing, and command completion.

OS Agnosticism: The terminal must execute system actions via direct language bindings/subprocesses (e.g., executing binaries with structured arguments, avoiding shell=True on Windows where possible) to prevent quote-escaping hell.

Dual Mode Support:

Interactive Mode: Human-facing REPL with clear formatting and helpful diagnostics.

Programmatic/Agent Mode: JSON-in, JSON-out or structured stdout streams designed for LLM tool-use, returning explicit error payloads instead of raw unparsed stack traces.

B. The Self-Healing Error Pipeline
When a command fails (non-zero exit code, missing dependency, syntax error, or path resolution failure), the CLI must not simply dump raw stderr and exit. It must:

Intercept: Capture the exact exit code, stdout, and stderr.

Classify: Categorize the failure type (e.g., CommandNotFound, PermissionDenied, SyntaxError, PathResolutionError, ArgumentMismatch).

Diagnose & Suggest: Generate actionable correction hints based on known Windows/cross-platform failure modes (e.g., suggesting a path fix, escaping correction, or alternative executable).

Feedback Loop: Present the diagnostic payload back to the user/agent in a structured format to enable an immediate automated retry.

C. DSL / Command Mapping Layer
Provide a lightweight command syntax layer that translates clean, predictable commands into safe system calls.

Support custom built-in meta-commands (e.g., help, status, history, heal-config) alongside standard system command execution.

3. Implementation Roadmap for the Agent
Phase 1: Reconnaissance & Integration
Step 1.1: Inspect the existing files under /friendly_cli in the repository to map current modules, entry points, and dependencies.

Step 1.2: Establish a clean test harness (unit tests for command parsing, execution, and error classification).

Phase 2: Core REPL and Process Execution
Step 2.1: Build the core input/output loop ensuring cross-platform character handling (especially handling Windows terminal carriage returns and encodings gracefully).

Step 2.2: Implement secure subprocess execution that bypasses the need to manually invoke cmd.exe or powershell.exe for basic file and system operations.

Phase 3: Self-Healing Diagnostics Engine
Step 3.1: Implement error interception hooks around command execution.

Step 3.2: Build a pattern-matching dictionary for common CLI/OS errors (especially Windows-specific quirks like missing extensions, locked files, or bad slash directions).

Step 3.3: Format error outputs into structured, machine-readable JSON or human-readable friendly advice depending on the execution context.

Phase 4: Verification & Usability
Step 4.1: Write integration tests simulating typical AI agent failure scenarios (e.g., malformed paths, missing tools) to verify that the self-healing feedback loop triggers correctly.

Step 4.2: Document the CLI usage spec so AI tool definitions can easily hook into it.

4. Acceptance Criteria
[ ] The CLI runs as a stable interactive REPL session without crashing on malformed user inputs.

[ ] System commands can be executed cross-platform without triggering Windows shell quote-escaping errors.

[ ] Common execution failures return a diagnostic hint rather than an unhandled stack trace.

[ ] The interface is clean enough to be adopted as a primary development terminal utility for day-to-day coding work.
