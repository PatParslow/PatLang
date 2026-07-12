---
name: mirror-check
description: Check (and guide fixing) self-hosted compiler mirror parity (runtime_rs.patlang AND parser/lower/codegen.patlang grammar) after changes to the Rust runtime
---

# mirror-check

PatLang's self-hosted compiler (`patc1.exe`) has **two separate kinds of
mirror debt** against the Rust runtime, and a fix for one does not fix the
other:

1. **Host-function-body parity** — `self_hosting/lib/runtime_rs.patlang`
   builds up, as plain string concatenation (`emit_chunk_<name>`
   functions, one per `ChunkId`), Rust source text that must be
   byte-for-byte identical to the corresponding `PRELUDE_<NAME>` constant
   in `rust-runtime/src/ir/codegen.rs`. Covers new/changed host functions.
2. **Grammar parity** — `self_hosting/lib/lexer.patlang` /
   `parser.patlang` / `lower.patlang` / `codegen.patlang` are the
   self-hosted compiler's OWN lexer/parser/lowerer/codegen, separate PatLang
   source files that must independently know about any new *keyword or
   operator* added to the real Rust `lexer.rs`/`parser.rs`/`ast.rs`. A
   feature that's pure host functions (e.g. the goal-oriented paradigm:
   `rule_add`/`solve`/`action_add`/`plan`) only needs #1. A feature that
   adds real syntax (e.g. bitwise `band`/`bor`/`bxor`/`bnot`/`shl`/`shr`
   keyword operators) needs **both** — #1 alone will silently produce a
   compiler that parses the new keyword as a plain function call and fails
   at runtime with `host fn 'X' not found`, not a compile-time error.

Neither is enforced automatically. Check both, every time.

## What to do when invoked

### Part 1: host-function-body parity

1. Run:
   ```
   cd F:\PatLang
   cargo test --release --manifest-path rust-runtime/Cargo.toml --test selfhost_pipeline -- selfhost_runtime_text_parity
   ```
2. Read the panic message's chunk list. Format is:
   `PatLang runtime chunk(s) differ from host template chunk(s) [...] — ["PARITY-OK-<name>", "PARITY-MISMATCH-<name>", ...]`
   Report exactly which chunks are `PARITY-MISMATCH` to the user (ignore
   the `"all"` entry, it's just an aggregate).
3. Fix via the generator script rather than hand-transcription — hand-
   editing 100s of lines of embedded Rust text chunk-by-chunk is exactly
   how this debt piled up to 6 chunks in the first place:
   ```
   "/d/Program Files/Python313/python" tools/regen_runtime_rs.py
   ```
   This parses each mismatched `const PRELUDE_<NAME>` out of `codegen.rs`
   and regenerates the matching `emit_chunk_<name>` + `emit_runtime_rs_
   <name>_<i>` sub-functions in `runtime_rs.patlang` from scratch (150
   lines per sub-function, with correct PatLang string escaping), replacing
   whatever was there by name-pattern regex. Add new entries to the
   `CHUNKS` dict at the top of the script for any newly-added `PRELUDE_*`
   constant it doesn't already know about. Re-run step 1 to confirm.

### Part 2: grammar parity (only relevant if new keywords/operators were added)

4. Check whether the change added a new *keyword or operator* (not just a
   host function) — grep `self_hosting/lib/lexer.patlang` and
   `parser.patlang` for the new keyword string (e.g. `"band"`). If it's
   genuinely new syntax:
   - `parser.patlang`: this self-hosted parser recognizes keyword
     operators by comparing identifier TEXT (`tok_is(t, "IDENT", "and")`),
     not distinct token kinds like the real Rust lexer — find the
     `parse_*` precedence-climbing function at the right tier (see
     `parse_and`/`parse_or` for the pattern) and add an analogous
     `tok_is(t, "IDENT", "<newop>")` branch. For a new precedence tier
     between two existing ones, insert a new `parse_X` function that calls
     the tighter-binding one and is called by the looser-binding one
     (see `parse_shift`/`parse_bitwise`, added between `parse_mul` and
     `parse_cmp` for `shl`/`shr`/`band`/`bxor`/`bor`, as the template).
   - `lower.patlang`: only needs changes if the new op is short-circuiting
     (like `and`/`or`) — everything else already falls through a fully
     generic `["Bin", node[1]]` / `["Un", node[1]]` arm, no per-op code
     needed.
   - `codegen.patlang`: find `binop_name` (maps an op string to a
     `BinOpKind` variant name string) and the `"Un"` arm of
     `emit_instr_rs` (maps `not`/`bnot`/`-` to `UnOpKind` variant names) —
     add the new op's string→variant-name mapping in both, matching
     `codegen.rs`'s own enum variant names exactly.
5. Rebuild and prove it for real — text/parity checks are necessary but
   not sufficient; only a full rebuild-and-run proves the self-hosted
   compiler actually understands the new syntax:
   ```
   rm -f self_hosting/build/patc1.fingerprint
   rust-runtime/target/release/pat --ir-run self_hosting/build_patc1.patlang
   ./patc1.exe <a .patlang file exercising the new feature> <out.exe>
   <out.exe>
   ```
   Compare output against the same file run via `pat --ir-run` and
   `pat --patc` — all three must match exactly.

## When to invoke this

- Before ending any task that added/changed a host function, a
  `PRELUDE_*` chunk, or an operator/keyword in the Rust runtime (per
  `CLAUDE.md`'s "Do not leave the self-hosted mirror behind" section).
- Any time it's been a while since the mirror was last checked and you're
  about to build on top of `patc1.exe` for something new — better to find
  drift before it compounds further than after.
