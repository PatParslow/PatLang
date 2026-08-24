# friendly_cli Implementation Plan

Plan only — no implementation in this pass. Written 2026-08-23, informed by a full read of `routemap.md`, a direct inspection of what already exists in `friendly_cli/lib/`, and a same-day cross-project retrospective that found several of routemap.md's required pieces duplicated from scratch elsewhere in this user's projects.

## Phase 1 — What already exists (reconnaissance)

`friendly_cli/lib/` is not empty — it already holds real, working infrastructure, and (correcting an earlier draft of this plan) it's closer to routemap.md's vision than it first looks:

- **`self_healing_engine.patlang`** — a RED-GREEN-REFACTOR system for synthesizing a *missing host function* at the point PatLang code tries to call one that doesn't exist. It tries a known pure-PatLang solution, then a known verified shell-command pattern, then an LLM as a last resort — every candidate gets empirically probed against real test data before anything is compiled and registered. **This is the capability-synthesis layer of the same self-healing system routemap.md describes, not a separate or unrelated mechanism** — it was built specifically to be part of a CLI's self-healing behavior when functionality turns out to be missing. The distinction that matters for scoping is which *sub-problem* each piece solves: this engine answers "this capability doesn't exist yet, synthesize it"; the still-unbuilt error-classification pipeline (below) answers "this command just failed, why, and can it be fixed or retried without synthesis." They're two layers of one system, and they need a real hand-off point between them (see "Where self-healing synthesis fits in," below) — not two competing implementations.
- **`command_safety.patlang`** — pre-execution risk classification for command *names* into four tiers (`no_workaround` / `safe_alias` / `human_confirm` / `unclassified`), with real safe alternatives already implemented (quarantine-rename instead of delete, a read-only `tasklist` report instead of running `taskkill`). This is directly relevant and should be wired into friendly_cli's real command-execution path as a mandatory pre-check, not reimplemented.
- The rest of `friendly_cli/lib/` (`ai_engine.patlang`, `goal_preprocessor.patlang`, `adaptive_predictor.patlang`, `curriculum_engine.patlang`, etc.) is a different AI-agent-assistance subsystem, not directly relevant to the REPL/self-healing-error-pipeline work here.
- `friendly_cli/dsl/` (`ai_ops.patlang`, `file_ops.patlang`, `goal_ops.patlang`, `imggen_ops.patlang`) already establishes a command-mapping-layer *pattern* (grouping related operations by file) that the DSL layer below (Phase 2, Part C) should follow rather than inventing a new structure.
- The rest of the directory is loose experiment/demo/curriculum scripts with no relationship to friendly_cli's actual REPL/error-pipeline work; ignore them for this build.

**Conclusion**: the error-*classification* half of routemap.md §2.B (intercept → classify → diagnose → structured feedback) doesn't exist yet and needs to be built. The capability-*synthesis* half already exists in `self_healing_engine.patlang` and should be integrated, not rebuilt. Both halves, and the goal below, point the same direction: build this as real, standalone, embeddable stdlib modules — not friendly_cli-only inline code.

## The actual goal: an embeddable console core, not just a standalone terminal

Direct user correction to an earlier draft of this plan, worth stating plainly since it reshapes the architecture: the point of this work is **"a terminal style CLI we can use for everyday tasks, as a programmers console and which can be embedded in other programs as needed."** Three distinct requirements follow from that, and none of them are satisfied by "friendly_cli is a standalone binary that happens to call some shared utility functions":

1. **Everyday-use terminal** — it has to be good enough to actually reach for daily, not just as an AI-agent scaffold.
2. **Programmer's console** — implies real interactive/introspective use, not just command dispatch.
3. **Embeddable in other programs** — this is the architecturally significant one. It means the REPL/dispatch/self-healing *engine itself* — not just the small supporting primitives (`proc`/`output`/`cli` below) — needs a clean, embeddable API that another PatLang program can drive from its own event loop, not just a blocking `main`-style stdin loop that only works as a standalone process.

This means a fourth module, more central than the other three: **`self_hosting/lib/console.patlang`** — the actual embeddable console core. It owns the REPL step (read one input, dispatch it, run it via `proc.patlang`, classify failure, hand off to synthesis or emit a diagnostic via `output.patlang`) as a single callable unit (e.g. `console_step(state, input_line) -> (new_state, output_event)`), so a standalone terminal's `main` loop and an embedding host's own event loop can both drive it identically. friendly_cli's own top-level binary becomes a thin consumer of this module: it supplies the specific dispatch table (the DSL layer + meta-commands) and runs a blocking stdin loop calling `console_step` — but any other PatLang program gets the same console for free by embedding `console.patlang` directly and driving `console_step` from wherever its own loop already is.

### Where self-healing synthesis fits in

The natural hand-off point: when `proc.patlang`'s `classify_failure` (below) determines a failure is specifically "the command/capability doesn't exist" rather than, say, a bad path or a permissions issue, `console.patlang` hands off to `self_healing_engine.patlang`'s `heal_missing_function` rather than just surfacing a diagnostic hint to the user. This needs one real distinction `classify_failure` doesn't currently need to make on its own: a missing *shell command* (nothing to synthesize — suggest an alternative or ask the human) is different from a missing *PatLang host-function capability* (exactly what `heal_missing_function` exists to fill). The plan below's `classify_failure` signature should return enough information to tell these apart, not collapse them into one "CommandNotFound" bucket.

## Why these four modules, and why they go in `self_hosting/lib/`, not `friendly_cli/lib/`

A same-session retrospective across 13 of this user's projects found the same patterns friendly_cli needs, reimplemented from scratch, independently, multiple times:

- **Run-a-command-and-classify-the-result**, the exact shape of routemap.md's self-healing pipeline, already exists as three separate one-off implementations elsewhere: a Python site-builder's `subprocess.run` + try/except wrapper, a PatLang webapp's `exec_capture` + ad hoc error handling, and Windows batch scripts checking `%ERRORLEVEL%`.
- **Structured vs. human-readable output**, the exact shape of routemap.md's "Dual Mode Support," already exists as scattered, mutually inconsistent conventions: numbered build-stage logging, ANSI-banner console output, and — inside PatLang's own codebase specifically — two different, competing logging idioms (`log_line` in one demo, `log_event` in another) that don't share an implementation.
- **Argument/usage handling**, needed by friendly_cli's built-in meta-commands (`help`, `status`, `history`, `heal-config`), is duplicated ad hoc across 10+ files under `self_hosting/tools/*_main.patlang` (confirmed directly: `coverage_main.patlang` line 91-95 is a representative example — `let args = argv()`, a bare `if args.length < N` check, a hand-written `"usage: ..."` string, repeated near-identically in every tool file with no shared helper).

Building friendly_cli's needs as inline, friendly_cli-only code would be another instance of the same mistake — and would directly contradict the embeddability goal above, since inline code can't be embedded by another program. Building them instead as real modules under **`F:\PatLang\self_hosting\lib\`** — the actual canonical PatLang stdlib location, which already holds `json.patlang`, `math.patlang`, `regex.patlang`, `test.patlang`, `ollama.patlang`, and the rest of the real standard library — means friendly_cli gets what it needs *and* every `self_hosting/tools/*_main.patlang` file, and any future PatLang program (including ones that just want to embed the console, not use friendly_cli's own DSL layer at all), gets it too. `self_healing_engine.patlang` stays in `friendly_cli/lib/` (nothing about it needs to move — `console.patlang` calls into it, it doesn't need to be relocated to be called), but the four modules below belong in the shared stdlib location, not `friendly_cli/lib/`.

## The four new stdlib modules

### `self_hosting/lib/console.patlang` — the embeddable core

The central piece per the embeddability goal above. Owns one thing: a single, drivable REPL step, so both a standalone blocking loop and an embedding host's own event loop can use it identically.

```
make a function called console_step takes state, input_line, dispatch_table returns step_result
  # dispatch_table maps command names to handler functions -- supplied
  # by the caller (friendly_cli's own DSL layer, or a different
  # embedding program's own commands), not hardcoded here. Looks up the
  # command, runs it via proc.patlang's run_classified, and on failure
  # branches per classify_failure's tier: hand off to
  # self_healing_engine.patlang's heal_missing_function for a missing
  # PatLang capability, or emit a diagnostic hint (via output.patlang)
  # for anything else. step_result carries the new state plus an
  # output_event for the caller to render/display however it wants.

make a function called console_new_state takes mode returns state
  # mode is "interactive" or "agent" -- initial state for a fresh
  # session, threaded through every console_step call.
```

friendly_cli's own standalone binary is then genuinely thin: a blocking stdin loop that calls `console_step` once per line and prints the result. Any other PatLang program gets the same console by embedding `console.patlang` and calling `console_step` from wherever its own loop already lives — no dependency on friendly_cli's own binary or DSL layer at all.

### `self_hosting/lib/proc.patlang`

Directly implements routemap.md §2.B's pipeline: run a command, capture exit code + stdout + stderr, classify the failure, return a structured result.

```
make a function called run_classified takes program, args returns result
  # result is a structured value: exit_code, stdout, stderr, classification,
  # diagnostic_hint. Wraps exec_capture (already a host function used
  # throughout this codebase) and adds the missing piece: real exit-code
  # capture and classification, not just captured stdout text.

make a function called classify_failure takes exit_code, stderr_text, was_patlang_call returns tier
  # returns one of: "MissingCapability" (a PatLang host-function call
  # that doesn't exist -- console.patlang hands this to
  # self_healing_engine.patlang's heal_missing_function), "CommandNotFound"
  # (an external shell command that doesn't exist -- nothing to
  # synthesize, suggest an alternative or ask the human), "PermissionDenied",
  # "SyntaxError", "PathResolutionError", "ArgumentMismatch", "Unknown" --
  # per routemap.md's own §2.B list, split into the two "not found" cases
  # console.patlang's hand-off logic needs to tell apart. was_patlang_call
  # is what lets classify_failure distinguish MissingCapability from
  # CommandNotFound rather than collapsing both into one bucket.
  # Pattern-match stderr_text against known Windows/cross-platform error
  # signatures (e.g. "is not recognized as an internal or external
  # command" -> CommandNotFound; "Access is denied" -> PermissionDenied;
  # "cannot find the path" -> PathResolutionError), same spirit as
  # command_safety.patlang's classify_command but classifying a FAILURE,
  # not a command name.

make a function called suggest_fix takes tier, program, args returns hint
  # a short, actionable string per classification tier -- routemap.md
  # §2.B "Diagnose & Suggest": a path fix, an escaping correction, or an
  # alternative executable, depending on tier.
```

Note the real gap this needs to check for first: PatLang's actual `exec_capture` host function needs to be confirmed to expose the real exit code separately from stdout (not just concatenated text) — this is Phase 1 work for whoever implements this module, not assumed here.

### `self_hosting/lib/output.patlang`

Directly implements routemap.md §2.A's "Dual Mode Support" and unifies the two competing logging conventions already found duplicated inside PatLang's own codebase.

```
make a function called render_human takes event_kind, message, detail returns text
  # the human-facing formatted line -- can absorb the existing log_line/
  # log_event conventions' actual visual style rather than inventing a
  # third one from scratch.

make a function called render_json takes event_kind, message, detail returns json_text
  # the same underlying event, as a structured payload for agent/
  # programmatic mode -- reuses self_hosting/lib/json.patlang for
  # serialization rather than hand-building JSON strings (a real,
  # separate bug class avoided by not doing that).

make a function called emit takes mode, event_kind, message, detail returns done
  # mode is "interactive" or "agent" -- picks render_human or render_json
  # and prints it. This is the single call site every part of friendly_cli
  # (and eventually other PatLang tools) should route output through.
```

### `self_hosting/lib/cli.patlang`

Fixes the argv-boilerplate duplication directly. Minimal, matching the actual style already used in `self_hosting/tools/*_main.patlang` rather than inventing a heavier flag-parsing framework those files don't need:

```
make a function called require_args takes args, min_count, usage_text returns ok
  # replaces the "if args.length < N then print(usage) return false end"
  # pattern duplicated in every *_main.patlang file -- same behavior,
  # one implementation.

make a function called arg_or_default takes args, index, default_val returns value
  # replaces the "if args.length >= 2 then let x = args[1] end" pattern
  # for optional positional args, also duplicated per-file.
```

friendly_cli's own meta-command dispatch (`help`, `status`, `history`, `heal-config`) needs slightly more than pure positional args — a command-name lookup, not just an index — so its dispatch table is friendly_cli-specific logic built on top of `lib/cli.patlang`'s primitives, not inside the shared module itself.

## Phase 2 — friendly_cli built as a thin consumer of `console.patlang`

- **Part A (Unified REPL loop)**: NOT friendly_cli-specific logic anymore, per the embeddability goal above — this is `console.patlang`'s `console_step`. friendly_cli's own binary is just a blocking stdin loop (line history/editing/completion live here, as terminal-IO concerns genuinely specific to a standalone process) that reads a line, calls `console_step`, and prints the result. An embedding host program skips this loop entirely and calls `console_step` from its own.
- **Part B (Self-Healing Error Pipeline)**: `console.patlang`'s failure-handling branch, built on `proc.patlang`'s `run_classified`/`classify_failure` for diagnosis and `self_healing_engine.patlang`'s `heal_missing_function` for capability synthesis — not friendly_cli's own code, and not a new implementation; `console.patlang` is the integration point between the two existing/planned pieces, per "Where self-healing synthesis fits in" above.
- **Part C (DSL / command-mapping layer)**: friendly_cli-specific after all — this is the actual `dispatch_table` passed into `console_step`. Meta-commands (`help`/`status`/`history`/`heal-config`) plus real command dispatch, following the existing `dsl/{ai,file,goal,imggen}_ops.patlang` grouping-by-concern pattern. Every command handler here checks `command_safety.patlang`'s `classify_command` before constructing any real invocation — reuse as-is, this was already correctly identified as mandatory-first in that file's own header comment.

## Phase 3 — Verification & usability (routemap.md §Phase 4)

Once the above exists: integration tests simulating the specific failure scenarios routemap.md names (malformed paths, missing tools) against the real `run_classified`/`classify_failure` pair, not mocked — matching this codebase's existing preference for empirical verification (`self_healing_engine.patlang`'s `probe_shell_command` is the precedent: nothing gets trusted without actually running it). Also verify the embeddability goal specifically, not just friendly_cli's own standalone use: write one small, separate PatLang program that embeds `console.patlang` directly (its own loop calling `console_step` with its own dispatch table, no dependency on friendly_cli's binary) as a real proof that the core is genuinely embeddable and not just structured to look that way.

## Adjacent, not in scope for this plan

Two more real gaps surfaced by the same retrospective, both inside `self_hosting/lib/` already, neither friendly_cli's responsibility to fix, worth a future session's attention:

- **RNG duplication**: the same LCG (linear congruential generator) implementation exists independently in `maze.patlang`, `report.patlang` (whose own comment admits the duplication was deliberate rather than accidental), and `stochastic_bdd_selftest.patlang`. Should eventually become `self_hosting/lib/rand.patlang`.
- **Test-framework bypass**: several `*_selftest.patlang` files hand-roll their own pass/fail counters instead of using the `check`/`t_report` framework `self_hosting/lib/test.patlang` already provides (the same framework `self_healing_engine.patlang` itself correctly uses).

Also explicitly out of scope, per direct user steering this session: a geometric-algebra primitives library, and redirecting `lib/ollama.patlang` to an OpenAI-compatible endpoint instead of Ollama's native API. Both are real, separate pieces of future work, not part of friendly_cli.
