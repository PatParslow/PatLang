# PatLang: conventions for working in this repo

## Use the self-hosted compiler for ordinary compiles, not the native pipeline

PatLang was deliberately pushed to self-host: the lexer, parser, lowerer, and code generator are all written in PatLang itself (`self_hosting/lib/ {lexer,parser,lower,codegen,runtime_rs}.patlang`), not just as a novelty but so that PatLang programs actually get compiled by a PatLang-authored compiler.

---

## 1. Compilers

* **`./patc1.exe`**: Everyday builds/verification. Must use explicit relative path `./` on Windows to avoid `CreateProcess` failures.


* Rebuild stale compiler: `rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang`.




* **`pat --patc`**: Testing native compiler/runtime (`codegen.rs`) only. Do not use for routine builds.


* **Goal**: Transition from `rustc` bootstrap to pure PatLang-to-native emission.



---

## 2. Mirror Sync (`codegen.rs` $\rightarrow$ `self_hosting/`)

* **Rule**: Update mirror before session end or explicitly report deferred gaps.


* **Workflow**:
1. Check parity: `cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity`

2. Update matching `emit_chunk_<name>` in `self_hosting/lib/runtime_rs.patlang` via `sb_push`.


3. Report precise un-mirrored chunk counts if deferring.





---

## 3. BDD Testing Workflow

1. **RED**: Write Given/When/Then first. Confirm scenario fails.


2. **GREEN**: Test exact scenario prose claims.


3. **Verify**: Match spec claims against real runtime output.


4. **Report**: State command, output, and exact spec alignment.

5. **Standing language-spec gate** (GitHub #49): `spec_library/language/*.feature` is executable, not prose — wired via `self_hosting/lib/spec_steps_language.patlang`'s `step()` registrations onto `self_hosting/lib/test.patlang`'s real Gherkin runner. Run it with:
   `rust-runtime/target/release/pat.exe --ir-run self_hosting/tools/run_language_spec_suite.patlang`
   Any language-semantics change (new operator, control-flow form, numeric-tower/tagging behavior) needs a scenario added/updated here as part of the change, RED before / GREEN after — not deferred to a one-off investigation. For representation/type invariants (e.g. "this op's result stays `int`, doesn't silently misclassify as `bigint`" — the root pattern behind #24/#46/#48), use `And ensure <var> == <literal>` (`self_hosting/lib/gherkin_contracts.patlang`) against a var set from `numeric_kind(x)`/`type_of(x)`; unquoted literal, `==`/`!=` also compare as strings when non-numeric. `spec_library/language/` is fully wired (37 of 37 `.feature` files, including two-process/cross-backend specs via `spawn()`/`exec_capture` — see `self_hosting/tools/spec_fixtures/`). `patlang_stdlib/`, `patlang_stdlib_auto/`, `shell/` are explicitly OUT OF SCOPE (leftover auto-generated specs from a different project, per project owner) — do not wire these without being asked.



---

## 4. Control Flow Rules

* **No Nested `else if**`: Causes silent execution failures (exit `0`, no output, no parse error).


* **Use `elif**`:
```patlang
if cond1 then
  ...
elif cond2 then
  ...
end
```[cite: 1]

```


* **Early Returns**: Prefer `if cond then return val end`.


* **Refactor**: Convert legacy nested chains to `elif` or audit `end` stacks.



---

## 5. Output Rules

* Keep turn narration to lean, concise text.


* Summarize results; do not paste full stdout.


* Save detailed write-ups for major milestones.

* **Avoid `| head -N` / `| tail -N`**: they queue output up instead of letting it stream, truncate before you've actually seen what matters, and aren't usually needed. Prefer `wc -l`, `grep -c`, or targeted `grep` for counts/verification; only cap output when a command is genuinely unbounded (e.g. a live log tail) and even then prefer a real filter over a blind line count. A prior session miscounted a directory's file total this way — trust an explicit count command (`ls ... | wc -l`) over a truncated listing.
