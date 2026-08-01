# PatLang: Developer & Repo Conventions

## 1. Compilation Workflows

* **Self-Hosted Compiler (`./patc1.exe`)**:
  * **Default for everyday compiles** (portfolio builds, verification, dev tools).
  * **Execution Path**: Always use `./patc1.exe` (with explicit relative path separator) when calling via `exec_capture` or host processes on Windows. Bare `patc1.exe` fails due to `CreateProcess` `SafeProcessSearchMode`.
  * **Rebuilding Stale Compiler**:
    ```bash
    rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang
    ```
    *(Skips `rustc` via fingerprint file `self_hosting/build/patc1.fingerprint` if unchanged).*

* **Native Compiler Pipeline (`pat --patc`)**:
  * **Use strictly for**: Debugging/testing the native Rust compiler/runtime (`rust-runtime/src/ir/codegen.rs`), verifying runtime changes before mirroring, or BDD parity checks.
  * Do **NOT** use for routine/everyday builds.

* **Backend Direction**:
  * `rustc` is currently used for bootstrap and final native backend emission. The long-term goal is a pure PatLang-to-native backend (no `rustc`).

---

## 2. Self-Hosted Mirror Synchronization

* **Strict Rule**: Every session modifying host functions, `PRELUDE_*` constants in `codegen.rs`, or operators **must update the mirror before closing** or explicitly report the deferred gap to the user.
* **Pre-commit / Verification Workflow**:
  1. Run `/mirror-check` or:
     ```bash
     cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity
     ```
  2. For every mismatched chunk, update the corresponding `emit_chunk_<name>` string-builder in `self_hosting/lib/runtime_rs.patlang` to match `codegen.rs` byte-for-byte (`sb_push`).
  3. If intentionally deferring, explicitly report the exact un-mirrored chunk count to the user.

---

## 3. Mandatory Spec & Testing Discipline (RED → GREEN BDD)

Applied uniformly to all changes, regardless of size:

1. **RED First**: Write Given/When/Then scenarios *before* implementation. Confirm the scenario actively fails. Unseen-to-fail scenarios are invalid.
2. **Literal GREEN Alignment**: The pass condition must directly test the literal claims in the scenario prose—not an adjacent hand-written check.
3. **No Assumed Verification**: LLM or generated spec text must be verified against real runtime outputs matching the specific text claims.
4. **Explicit Reporting**: When reporting passing specs, explicitly state the exact command executed, observed output, and how it satisfies the scenario wording.

---

## 4. Control Flow & Branching Rules

* **Avoid Nested `else if` Chains**: Do **NOT** use `else` followed by nested `if ... end` blocks. Deferring `end` keywords to a shared stack causes silent execution failures (program exits `0` with zero output without throwing a parse error).
* **Use `elif`**: For mutually exclusive conditions, use `elif` (supported natively).
  ```patlang
  if cond1 then
    ...
  elif cond2 then
    ...
  end
Use Early Returns: For decision/lookup functions, use early-return guard clauses (if cond then return val end).

Existing Chains: When adding new branches to legacy nested if/else chains, refactor the chain to elif or carefully audit end stack counts and test execution immediately.

---

## 5. Output Discipline

Keep turn-by-turn narration **short**. A one-line status per action ("waiting on rebuild", "found X, fixing Y") is enough — no restating context already established earlier in the session, no repeating full command output back verbatim when a one-line summary of the result suffices. Save the longer write-up for a real milestone (root cause found, fix verified, ready to commit), not every intermediate step.
