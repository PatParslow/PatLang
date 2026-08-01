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
