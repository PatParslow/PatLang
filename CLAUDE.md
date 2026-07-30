# PatLang: conventions for working in this repo

## Use the self-hosted compiler for ordinary compiles, not the native pipeline

PatLang was deliberately pushed to self-host: the lexer, parser, lowerer,
and code generator are all written in PatLang itself (`self_hosting/lib/
{lexer,parser,lower,codegen,runtime_rs}.patlang`), not just as a novelty
but so that PatLang programs actually get compiled by a PatLang-authored
compiler.

**For ordinary compilation of PatLang programs** (portfolio builds, ad hoc
verification, dev tooling) — use `patc1.exe` (repo root), the self-hosted
compiler already compiled to a real native binary:

```
./patc1.exe <input.patlang> <output-exe> [target-triple]
```

**Use `./patc1.exe`, not bare `patc1.exe`**, when invoking it via
`exec_capture` (or any `std::process::Command`-based host call) from a
PatLang script running on Windows: `CreateProcess` excludes the current
directory from its search for a bare filename with no path separator
(SafeProcessSearchMode), so `exec_capture("patc1.exe", ...)` fails with a
misleading "program not found" even though `file_exists("patc1.exe")`
returns true and the file runs fine from a shell. Any path containing a
separator (`./patc1.exe`, `portfolio/build/foo.exe`) is unaffected.

`patc1.exe` may be stale relative to `self_hosting/lib/*.patlang`; rebuild
it first if unsure:

```
rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang
```

That rebuild is cheap when nothing changed — it fingerprints the compiler
source and skips the actual `rustc` invocation if the fingerprint file
(`self_hosting/build/patc1.fingerprint`) already matches. `self_hosting/
tools/build_portfolio.patlang` runs this rebuild step unconditionally at
its own start, so it's always working from a fresh `patc1.exe`.

**`pat --patc`** (the native Rust-implemented pipeline,
`rust-runtime/src/ir/codegen.rs`'s `RustCodegen`) remains the *right* tool
specifically when testing or debugging the native runtime/compiler
implementation itself — e.g. verifying a change to `codegen.rs` before it's
mirrored into `self_hosting/lib/codegen.patlang` (see
`selfhost_runtime_text_parity` in `rust-runtime/tests/selfhost_pipeline.
rs`), or the interpreted-vs-compiled-vs-`run_ir` parity checks the BDD
suite (`rust-runtime/tests/features/*.feature`) already does. That's the
"adding a new language feature or diagnosing a flaw in the runtime itself"
carve-out — not a license to reach for it for everyday compiles.

`rustc` itself is still fine and necessary: both as the one-time bootstrap
step that turns the self-hosted compiler's own source into `patc1.exe`,
and as the final native-codegen backend `patc1.exe` itself shells out to
(compiled PatLang programs are real machine code; something has to emit
it). **Longer-term direction, not current work**: even that last
dependency on `rustc` as the final backend is meant to go away eventually
— a genuine PatLang-to-native compiler, no `rustc` involved at all for the
last step. Not scoped or started yet; noted here so it isn't lost.

## Do not leave the self-hosted mirror behind

The `pat --patc` carve-out above (test a new host function or codegen
change without touching `self_hosting/lib/runtime_rs.patlang` yet) is
meant to be a same-session shortcut, not a place to stop. **Every session
that adds or changes a host function, a `PRELUDE_*` chunk in `codegen.rs`,
or a language operator must end with either the mirror updated, or an
explicit, visible decision to defer it — never a silent gap.** Left
unchecked this compounds fast: three feature additions in one session
(site-editor host fns, the goal-oriented paradigm, bitwise operators) each
deferred their mirror, and `selfhost_runtime_text_parity` now shows six
chunks red (`core`, `files`, `logic`, `contracts`, `numeric_tower`,
`codegen_bootstrap`) — meaning `patc1.exe` (the compiler PatLang programs
are actually supposed to be compiled by, per the whole point of this repo)
cannot compile programs using any of those features, only the Rust-native
`pat --patc` path can.

Before ending any task that touched `hosts.rs`/`codegen.rs`:
1. Run `cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity` and read which chunks it lists as mismatched.
2. If your change touched a chunk that's now red, update the matching `emit_chunk_<name>` function in `self_hosting/lib/runtime_rs.patlang` to mirror the Rust-text change byte-for-byte (see existing `emit_chunk_logic`/`emit_chunk_files` etc. for the pattern — string-building via `sb_push` calls that must produce output textually identical to the corresponding `codegen.rs` `PRELUDE_*` constant).
3. If deferring anyway (e.g. genuinely out of scope for the current task), say so explicitly to the user rather than letting it pass silently — "the self-hosted mirror is now N chunks behind" is a fact worth surfacing, not burying.

A `/mirror-check` skill (`.claude/skills/mirror-check/SKILL.md`) automates step 1 and reports exactly what's out of sync — run it before considering any `hosts.rs`/`codegen.rs` change complete.

## Full RED → GREEN BDD for every function, no matter how small

A real bug in the spec-library initiative (`spec_library/shell/where.
feature` and 3 others marked `"verification_status": "verified"` while
describing an entirely different, nonexistent command — see `spec_
library/NEEDS_ATTENTION.md`'s incident writeup) came from treating
"write a spec" and "run some check that happens to pass" as if they
were the same claim. They aren't. The failure mode generalizes past
that one pipeline: **it is not safe to write a scenario, an
implementation, and a passing check in any order that lets them drift
apart — the only reliable discipline is genuine RED → GREEN, every
time, including for a function that looks too small to bother.**

Concretely, for any new function or host capability, no matter how
small ("small" is exactly where this discipline gets skipped, and
exactly where it's cheapest to do right):

1. **RED first**: write the Given/When/Then scenario(s) *before* the
   implementation exists (or before trusting an existing one), and
   confirm they actually fail (or that the target genuinely doesn't
   exist yet) — a scenario that has never been seen to fail is not
   trustworthy evidence it's testing anything real.
2. **GREEN via the SAME artifact**: the check that flips RED to GREEN
   must be evaluating the *literal claims written in the scenario* —
   not a differently-scoped, differently-authored probe that happens to
   also return true. If a scenario says a function handles case X, the
   thing that goes GREEN must actually exercise case X, not something
   adjacent to it. Never let a spec's prose and its verification logic
   be authored independently and reconciled only by both "looking
   plausible" or both "usually agreeing."
3. **A passing check is not evidence for content you didn't write it
   to check.** If an LLM (or any generator) produces the scenario text,
   the verification step must confirm THAT TEXT's specific claims
   against a real observation — not run an unrelated hand-written
   assertion and stamp the generated text "verified" by association.
   When in doubt, prefer to keep the spec's prose and its check in the
   same hand-authored place, generated or reviewed together.
4. **State the verification chain explicitly when reporting a
   scenario as passing** — what specifically was run, what output was
   observed, and how that maps to the scenario's own wording. "It's
   marked verified" and "I just watched it happen" are different
   claims; don't let the former stand in for the latter.

This applies uniformly — a one-line utility function deserves the same
RED → GREEN discipline as a large feature; skipping it for "small"
code is exactly the gap that let four specs ship as "verified" while
describing a different program entirely.

## Prefer `elif`/early-return over `else` + nested `if` with deferred `end`s

A real bug (found and fixed 2026-07-30, `self_hosting/lib/codegen_x64.
patlang`'s `x64_callhost_asm`) came from this pattern:

```
if name == "a" then
  ...
else
  if name == "b" then
    ...
  else
    if name == "c" then
      ...
    end
  end
end
```

Adding one more branch to a chain like this means adding one more
`if`/`else` pair — which means the matching `end` has to be added
too, but it's *deferred* to a shared stack, often dozens of lines and
several nesting levels away from the `if` it closes. Forgetting the
one extra `end` does **not** produce a parse error — the file still
parses, but the whole surrounding function's structure silently shifts,
and depending on what follows, the visible symptom can be as
extreme as **the entire program producing zero output and exiting 0**,
with nothing to indicate where — or even that — something broke. This
is exactly what happened: one new branch added to `x64_callhost_asm`'s
existing (112-deep, in that one file) chain, one missing `end`, and
every script that so much as `include`d the file went silent.

**Going forward, for a chain of mutually-exclusive string/value
comparisons, prefer real `elif`** (this grammar supports it — the
Rust parser's own `elif` handling was itself fixed this session,
GitHub #23 — confirmed working correctly): the branch count and the
`end` count can never drift apart, because there's only ever one `end`
for the whole chain regardless of how many `elif`s it has.

**For a function that's really just "check each condition, return the
answer for whichever one matches"** (e.g. this file's own
`x64_is_bool_producing_instr`), prefer early-return guard clauses
instead — PatLang has no `continue`/`break`, but a `return` inside an
`if` that closes immediately is exactly as safe as `elif` for this
same reason: each `if`'s `end` is right next to its own `if`, never
deferred to a shared stack elsewhere.

Not a mandate to mass-refactor existing deferred-`end` chains (the
codebase has many, `x64_callhost_asm` alone has ~20 levels) — but any
*new* branch added to one is worth converting the surrounding chain to
`elif` while you're there, and any *new* chain should use `elif`/early-
return from the start. If you do add to an existing deferred-stack
chain anyway, count the `end`s in the closing stack very carefully and
verify immediately by running anything that includes the file — silent
zero-output-exit-0 is the actual failure mode, not a helpful error.
