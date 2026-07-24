# Arc\<String\> migration: status and handoff

**Read this before touching anything.** This documents an in-progress,
partially-verified core runtime change with a large, currently-unfinished
follow-on. Written for a fresh session with zero prior context.

## UPDATE (2026-07-23 session): layer #2 finished for real, #3/#4 reconfirmed, one genuine perf bug found and fixed, one new perf characteristic found and NOT fixed

The previous write-up below (from an earlier session) claimed layer #2
("`codegen.rs`'s embedded `PRELUDE_*` runtime text") was "DONE, believed
correct, but UNVERIFIED by a real compile." That was overly optimistic:
when actually rebuilt for real, it failed with **101 rustc errors**, all
"expected `Arc<String>`, found `String`" (or the reverse), inside the
`PRELUDE_*` string-literal text. Layer #2 was NOT actually complete.

### What this session actually did

1. **Layer #2, for real this time.** Went through every `Value::String(`
   occurrence inside the ~11 `PRELUDE_*` constants in
   `rust-runtime/src/ir/codegen.rs` (lines ~252-4177) and fixed every
   remaining construction site missing `.into()`, plus a related and
   more important class of bug the first pass had missed: several
   `match args.get(n) { Some(Value::String(s)) => s.clone(), ... }`
   extraction sites were doing `s.clone()` on `s: &Arc<String>`
   (yielding `Arc<String>`) when the other match arms (`String::new()`,
   `to_s(v)`, `display_value(v)`) yield plain `String` — a type
   mismatch. Fixed via `s.as_ref().clone()` (which yields a fresh
   `String`, matching the sibling arms) at all ~35 such sites. Also
   fixed a handful of one-off cases: `"1"/"0".into()` on `Arc<String>`
   (no `From<&str>` impl — needed `"1".to_string().into()`), `Option<Arc<String>>`
   vs `Option<&'static str>` comparison (`target.as_deref() ==
   Some("...")`, needed the `target` variable itself built via
   `.as_ref().clone()` not `.clone()`), and `Arc<String>` passed directly
   to APIs requiring `AsRef<OsStr>`/`AsRef<Path>`/`AsRef<[u8]>`
   (`std::process::Command::arg`, `Path::new`, `std::fs::write`) — same
   root cause, same `s.as_ref().clone()` fix at the extraction site so
   the downstream local stays a plain `String` throughout.

   **Also found a second, separate bug in the SAME session while chasing
   this**: `RustCodegen::emit_value` in `codegen.rs` (the function that
   emits Rust source text for a compiled program's own `Instr::Const`
   nodes — this is real compiled Rust code, NOT inside a `PRELUDE_*`
   string) had:
   ```rust
   Value::String(s) => out.push_str(&format!("Value::String(\"{}\".to_string())", rust_str(s))),
   ```
   missing `.into()`, so ANY compiled PatLang program with a string
   literal in its own source failed to compile with rustc (confirmed via
   `pat --patc` on a one-line `print(type_of("hello"))` test — this is
   what the BDD suite's `interp_compiled_parity`/`type_of` scenarios were
   catching as "compiled run not performed"). Fixed the same way as the
   `codegen.patlang` mirror fix mentioned below (add `.into()`).

2. **Iterated the rebuild-error-fix loop to completion.** Went
   101 errors → 49 → 9 → clean, rebuilding `pat` (`cargo build --release`)
   and regenerating the self-hosted mirror
   (`tools/regen_runtime_rs.py`) between each round — critical
   discovery: **`self_hosting/build_patc1.patlang` builds `patc1.exe`
   using the self-hosted mirror (`self_hosting/lib/runtime_rs.patlang`),
   NOT `codegen.rs` directly**, so editing `codegen.rs` alone has zero
   effect on this pipeline until (a) `pat` itself is rebuilt with
   `cargo build --release` (it's compiled Rust, not re-read at runtime)
   and (b) the mirror is regenerated. Missing either step reproduces the
   exact same stale error list on every retry and looks like "my edit
   didn't work" when actually the edit was never exercised.

3. **`cargo test --release` (full suite): PASSES, 0 failures.**
   Confirmed twice, including the BDD suite's `interp_compiled_parity`
   and `type_of` feature files (the ones that exercise `--patc` directly
   and were catching the `emit_value` bug above) and
   `value_layout.feature`'s direct-rustc-compile-of-the-fast-Value-module
   scenario (this is what caught the `to_s`-in-`PRELUDE_VALUE_FAST`
   `s.clone()` mismatch — a pre-existing latent bug in the destructuring
   match arm inside `fn to_s`, `Value::String(s)=>s.clone()`, that would
   never surface via `cargo build`/`cargo test` alone since it's inside a
   string literal; only compiling the embedded text for real catches it).

4. **Self-hosted mirror (layer #3): regenerated and reconfirmed passing.**
   `tools/regen_runtime_rs.py` (Python, run via
   `"/d/Program Files/Python313/python.exe"` — no `python`/`python3` on
   PATH in this environment, only under `D:\Program Files\Python31{0,1,3}`)
   regenerated `self_hosting/lib/runtime_rs.patlang` from the corrected
   `codegen.rs` twice this session (once after the bulk `.into()`/
   `.as_ref().clone()` fixes, once after the `emit_value` fix + the
   perf fix in point 5 below).
   `cargo test --release --test selfhost_pipeline -- selfhost_runtime_text_parity`
   passes clean both times. `cargo test --release --test selfhost_pipeline`
   (the other 6 non-ignored tests: pipeline-compiles-via-frontend,
   tcp-echo-server, feature-demo, stage3-lowering-in-patlang,
   stage4-codegen-in-patlang) also all pass.

5. **Real end-to-end rebuild of `patc1.exe`: SUCCEEDS, clean, no rustc
   errors.** `rm self_hosting/build/patc1.fingerprint && pat --ir-run
   self_hosting/build_patc1.patlang` now completes with `GEN A: ...
   \patc1.exe` and zero errors (was: 101, hadn't succeeded even once
   before this session per the prior write-up's own account).

6. **A genuine, still-live O(n) perf bug found and fixed at the
   `codegen.rs`/PRELUDE layer while doing the perf verification below**:
   `host_call_strings_ext_inner`'s `"char_code"` and `"substr"` arms
   were extracting their string argument via
   `Value::String(s) => s.as_ref().clone()` — i.e. **deep-copying the
   entire backing `String` on every single call**, exactly the
   O(n) per-access cost (turning per-character-scan loops into O(n²))
   that the whole Arc<String> migration exists to eliminate, just
   relocated to a call site the mechanical `.into()`/`.as_ref().clone()`
   fix-up pass introduced as its "safe default" without checking hot-path
   cost. Fixed by borrowing instead of cloning: `let s: &str = match
   &args[0] { Value::String(s) => s.as_str(), v => { owned0 = to_s(v);
   owned0.as_str() } };` (both functions, see `codegen.rs` around
   line 2219). Confirmed via a controlled test: calling `char_code` 1000
   times against a 500,000-char string is fast (~0.4s) regardless of the
   string's size, proving the per-call cost is no longer proportional to
   string length.

7. **A NEW, different, NOT-yet-root-caused perf characteristic remains**:
   with the fix in point 6 applied, `500,000` calls to `char_code`
   against a single large (500,000-char) string still takes ~5.2s
   (improved from ~9.7s before the fix, and from "never finishes" before
   any of this session's fixes — genuine progress, just not the
   "near-instant" the original status doc predicted). Isolation tests
   run this session:
   - 500K `char_code` calls against a small literal `"x"`: ~0.44s (fast).
   - 500K trivial-arithmetic loop iterations, no `char_code` at all:
     ~0.32s (fast).
   - 500K `sb_push` calls building the big string, no `char_code` loop
     after: ~0.39s (fast).
   - 1000 `char_code` calls against the big string: ~0.39s (fast —
     confirms point 6's fix works, cost is not per-call proportional to
     string size).
   - 250,000 `char_code` calls against the big string: ~1.4s.
   - 500,000 `char_code` calls against the big string: ~5.2s.
   The 250K→500K scaling (~4x for 2x the call count) suggests something
   still scales worse than linear specifically when BOTH the call count
   AND the string size are large simultaneously — not proportional to
   string size alone (ruled out by the 1000-call-on-big-string case) and
   not proportional to call count alone (ruled out by the
   500K-calls-on-small-string case). Root cause NOT found this session —
   candidates not yet checked: host-function dispatch overhead in the
   generated match/chain-of-matches across `host_call_core` /
   `host_call_math` / `host_call_strings_ext` / etc. (a per-call constant
   that wouldn't explain the specific big-string-only slowdown, so
   probably not this alone), or something in how `args: Vec<Value>` is
   assembled/dropped per `CallHost` when one argument is a large
   `Arc<String>` clone that still isn't as cheap as expected. **Flagging
   honestly rather than guessing further — this needs a fresh, focused
   investigation, not folded silently into "the Arc<String> migration is
   done."**

### Current true status of the 4 layers (+ a "#5" that does NOT exist)

1. **Interpreter (`--ir-run`)**: DONE, unchanged this session,
   `cargo test --release` (full suite) passes.
2. **`codegen.rs`'s embedded `PRELUDE_*` runtime + `emit_value`**: DONE
   AND VERIFIED FOR REAL this time — compiles cleanly via actual rustc
   (not just `cargo build`, which never checks this text), full
   `cargo test --release` suite passes including the BDD scenarios that
   exercise `--patc` directly. The char_code/substr perf fix in point 6
   above is also in this layer.
3. **Self-hosted mirror (`self_hosting/lib/runtime_rs.patlang`)**: DONE,
   regenerated twice via `tools/regen_runtime_rs.py`, parity test passes.
4. **Self-hosted compiler's own codegen
   (`self_hosting/lib/codegen.patlang`)**: Already fixed in a prior
   session (the `.into()` on the `"str"` Const-emission arm, line ~158);
   reconfirmed present and correct this session, not touched further.
5. **Is there a "#5" (other `.patlang` files hand-building
   `Value::String`-shaped IR text)?** Checked: no. The real end-to-end
   `patc1.exe` rebuild (point 5 above) completed with zero errors on the
   first clean attempt after layers #2-#4 were all correct — if another
   `.patlang` file had its own independent `Value::String` construction
   bug, that rebuild would have surfaced it as a new rustc error the way
   layer #4's bug did in the prior session. It didn't. No #5 exists.

### What's still open (for a future session, not blocking, not silently dropped)

- **Point 7's perf mystery** — a real, reproducible, NOT-yet-explained
  perf characteristic (500K `char_code` calls against one large string
  scaling worse than linear in call count specifically when the string
  is also large). This is a different bug from the one this whole
  migration was chasing (that one — deep-cloning the whole string per
  call — is confirmed fixed per point 6's isolation test). Needs a
  fresh investigation: instrument/profile `patc1.exe`-compiled binaries
  directly (e.g. a release build with `perf`/Windows equivalent, or
  bisect by commenting out pieces of the generated Rust) rather than
  guessing from black-box timing.
- Given point 7, the "real-world case" verification (site builder's
  `html_unescape` over the 1.2MB file, verification command #5 in the
  original doc below) was NOT re-run this session — no point measuring
  the original real-world case until the char_code-scaling mystery in
  point 7 is actually understood, since it's plausible (not confirmed)
  that the site-builder path exercises the same still-slow pattern.
- The other ~35 `s.as_ref().clone()` extraction sites introduced this
  session (across `oo`, `logic`, `contracts`, `networking`,
  `codegen_bootstrap` chunks etc.) were fixed purely for
  compile-correctness and were NOT individually audited for the same
  "is this a hot per-character loop" perf question that caught
  char_code/substr in point 6. Most are one-shot extractions (function
  names, file paths, object property names) not called in tight loops,
  so this is lower risk than char_code/substr was, but it hasn't been
  exhaustively checked either.

## Nothing in any of this is committed

Repo is on branch `feature/self-healing-red-green-refactor`. `git status`
in `F:\PatLang` will show the real diff scope once ready to review/commit.

---

## Original write-up from the prior session (kept for context; see the
## "UPDATE" section above for what's actually true now)

## How this started

Originally: porting the Parslow site's Python `build.py` to PatLang
(`D:\Projects_Organized\parslow-soft-editorial\tools\site\build.patlang`
— this file IS finished and correct as PatLang source, see "Site
builder status" at the bottom). While testing it against real site
content, a 1.2MB real article (`patlang-numeric-tower.html`) never
finished tokenizing even after 8+ minutes under `--ir-run`. That led to
discovering a fundamental interpreter performance bug, and THAT led to
discovering the bug has three/four separate, textually-duplicated
implementations across this codebase that all need the same fix. This
document is about that bug and its cascade — the site builder itself is
basically done and blocked only on this.

## The root bug (found, understood, and it's real)

`Instr::LoadLocal` (wherever it's implemented) clones the **entire
Value** every time a local variable is read, not just on explicit
host-function calls. For a `Value::String` that was a bare `String`
(not reference-counted), reading a large string inside a loop — e.g.
`s[i]` in a per-character scanning loop, exactly what an HTML
tokenizer/lexer does — cloned the whole remaining string on every
single iteration, turning an intended O(n) scan into O(n²).

(See point 6/7 above: the `LoadLocal`-clone bug itself is fixed
end-to-end as of this session, but a related, distinct perf
characteristic around repeated host calls against large strings remains
open.)

## Two smaller, already-fixed bugs found and fixed along the way (in `self_hosting/lib/html_scan.patlang`, unrelated to the Arc<String> architecture issue)

1. Several functions (`html_lower`, `html_unescape`, `html_escape`,
   `html_attr_escape`, `html_trim`) had `while i < s.length do` loop
   conditions that re-evaluate `.length` every iteration — O(n²)
   independent of Arc<String>. Fixed by caching `let n = s.length` once.
2. `html_unescape` gated its expensive `substr`-based entity-matching
   cascade behind a single `char_code(s, i) == 38` ('&') check first.

Both DONE, don't need revisiting.

## Site builder status (the ORIGINAL task, separate from all of the above)

`D:\Projects_Organized\parslow-soft-editorial\tools\site\build.patlang`
is fully written but has NOT been run to completion against the real
site yet — blocked on point 7's perf mystery above, not on the compile
errors this session fixed (those are now resolved). Once point 7 is
understood:
```bash
cd "D:/Projects_Organized/parslow-soft-editorial"
F:/PatLang/patc1.exe tools/site/build.patlang /tmp/site_build.exe
time /tmp/site_build.exe
```
and compare its output in `publish/` against the existing Python
`build.py`'s output (already known-good).

Two small PatLang language gotchas learned while writing `build.patlang`:
- Top-level `let` statements in an **included** file do not execute —
  only function definitions get pulled in by `include`.
- `+` does NOT concatenate lists — use `list_push` in a loop instead.
- `\U0001F4DA`-style unicode escapes are not supported in PatLang string
  literals — use the real UTF-8 character directly in the source file.
