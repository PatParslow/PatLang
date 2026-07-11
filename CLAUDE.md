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
