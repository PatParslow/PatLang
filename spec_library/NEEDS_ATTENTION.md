# INCIDENT: risk classifier misses transitive helper-call side effects (auto-prober)

User: **"Spot check a statistically significant sample of the 430 new
auto-probed specs for accuracy."** Sampled 30/430 (~7%) at random,
re-executed each fresh, compared byte-for-byte against the recorded
`observed_output`. **28/30 (93.3%) matched exactly.** The 2 that
didn't (`update_task_weights`, `predict_compile_duration`) turned out
to be a real, systemic classifier gap, not noise.

## Root cause
Both functions were classified `likely_pure` by `patlang_function_
discovery.patlang`'s `body_looks_side_effecting` heuristic and
therefore auto-probed -- but both delegate their REAL file-backed
persisted-state I/O (regression weights for a learned duration
predictor) to helper functions (`load_regression_weights`/`save_
regression_weights`, `load_task_regression_weights`/`save_task_
regression_weights`), rather than calling `write_file`/`read_file`
directly in their own body text. The risk classifier only scans a
candidate's OWN body-window text for risky substrings -- it has no
transitive call-graph awareness, so delegating real I/O to a helper
makes a function invisible to it, even though the function's real,
observed behaviour is neither pure nor stable across repeated calls
with identical input.

## Full sweep, not just the 2 the sample caught
Since the only `load_*`/`save_*` functions anywhere in the codebase
are exactly 6 names (`load_ir`/`save_ir`, `load_regression_weights`/
`save_regression_weights`, `load_task_regression_weights`/`save_task_
regression_weights`), swept all 616 then-auto-probed entries for calls
to any of them. Found **4 more direct hits** beyond the 2 the random
sample caught: `load_regression_weights`, `update_model_weights`,
`load_task_regression_weights`, `predict_task_duration` -- all removed
(6 total). `load_ir`/`save_ir` are never actually called anywhere in
the codebase (confirmed via grep), so pose no risk despite existing.

## Action taken
Removed all 6 misclassified specs from `spec_library/patlang_stdlib_
auto/` (612 remain, down from 618). Logged with full reasoning in the
new `spec_library/patlang_stdlib_auto/MISCLASSIFIED_STATEFUL.txt`.

## Suggested fix, not yet implemented (backlog)
`body_looks_side_effecting` (patlang_function_discovery.patlang) should
either (a) recognize a `load_*`/`save_*`/`persist_*`/`*_history` naming
convention as risky by itself, or (b) do one level of transitive
same-file call-graph awareness: if a candidate calls another
locally-defined function, and THAT function's own body trips the risky-
substring check, the candidate should inherit the "likely_side_effecting"
classification. (b) is more general and would have caught this family
without needing to guess at naming conventions.

# INCIDENT: LLM-content vs probe mismatch in the Slice 1 shell-command specs

User caught this directly: **"Just to note, the shell feture for where
is entirely wrong...?"** -- confirmed and, on inspection, not isolated
to `where`.

## What was wrong
`spec_library/shell/where.feature` and `which.feature` described an
entirely nonexistent command ("list/sort open windows", "close an open
window" for `which`; a GUI window enumerator for `where`) -- both real
commands actually resolve an executable name to its path on PATH.
`find.feature` described recursive-directory-search flags (`/s`, `/r`,
`/type`, `/x`) the real native `find.exe` doesn't have (it's a literal
string-in-file search, one file at a time). `findstr.feature` claimed
5 scenarios but only 1 (basic literal match) had ever actually been
checked -- one of the other 4 named a flag (`/ic`) that isn't even
real (real findstr uses `/I`). **All four were marked
`"verification_status": "verified"`.**

## Root cause
`discover_shell_command_spec` (spec_discovery_engine.patlang) asks an
LLM to freely IMAGINE Gherkin for a command from its own "knowledge",
completely independently of the hand-written `verify_*` probe that
actually runs the real command. If that UNRELATED probe passed, the
LLM's text got persisted and stamped `"verified"` -- nothing anywhere
cross-checked that the LLM's specific claims (flags, described
behaviour) had anything to do with what the probe actually observed.
A real, non-vacuous probe passing was being used to certify an
entirely disconnected claim.

Not yet consumed downstream at the time this was found (self_healing_
engine.patlang's `known_shell_solution` table doesn't reference these
commands) -- contained to documentation, but would have been a real,
active hazard the moment anything downstream trusted these specs as
ground truth.

## Fix (root cause, not just data)
Added `hand_gherkin_for_command(command_name)` to spec_discovery_
engine.patlang: for any command with a hand-written `verify_*` probe,
the PERSISTED `.feature` text now comes from a hand-authored Gherkin
block tied to that same probe, added in the same table at the point
the probe is written -- never from the LLM call, which is now only a
first-draft aid for genuinely new, not-yet-allowlisted commands (where
verification_status honestly stays unverified). If a probe ever passes
with no matching hand_gherkin_for_command entry, the pipeline now
prints a loud warning and flags it in the persisted metadata rather
than silently trusting the LLM -- the exact gap that let this happen.

Re-ran `friendly_cli/discover_shell_specs.patlang` end-to-end after the
fix: confirmed all 4 commands now come back `"source": "hand-authored"`
with the correct content, automatically, going forward.

## Verification of the fix itself -- NOT just "hand-authored", actually re-checked
User's follow-up, correctly skeptical: **"That only seems to confirm it
is hand authored not the 'correct' claim, though."** Right -- the
pipeline picking the hand-authored branch only proves provenance, not
correctness. Closed the loop with fresh, first-hand command execution
(not re-reading old code, not trusting the probe's own comments):
personally ran `where findstr`, `which findstr`, `which <bogus>`,
`where <bogus>`, `findstr` positive/negative, and `find.exe`
positive/negative (via the same batch-file quoting workaround the
codebase itself needs) just now, and confirmed every claim in the
corrected specs against the real output byte-for-byte -- including a
detail the original probes' pass/fail check didn't need but a spec
should state precisely: `find.exe` also prints a `---------- <FILENAME>`
header line before any match, which the first correction pass missed;
added after seeing it appear in the real output.

## Audit of the other two spec pipelines for the same bug class
Explicitly checked per the user's request ("Probably also need to
check that the code running the current (and previous...) discoveries
hasn't fallen prey to the same issue"):
- **Top-40 hand-authored batch** (`spec_library/patlang_stdlib/`):
  structurally different from the shell pipeline -- the Gherkin and the
  `verify_*` probe were always written by the same hand, in the same
  pass, deriving the spec text directly from the probe's own
  assertions (not from an independent LLM guess). Spot-checked 2 samples
  by fresh re-execution rather than trusting that reasoning alone:
  `str_trim` (confirmed: strips space/tab, does NOT strip `\n`) and the
  `html_escape` divergence claim (confirmed: html.patlang's escapes
  `"`, html_scan.patlang's doesn't) -- both hold up exactly as specified.
- **Auto-prober** (`spec_library/patlang_stdlib_auto/`): safe by
  construction, not just by discipline -- the `.feature` text is
  templated directly from the actual observed call (never independently
  imagined), and never claims more than "this exact input produced this
  exact output, no error" -- the real observed output is recorded
  honestly in `.meta.json`, never overclaimed as a specific meaningful
  behaviour beyond what was actually seen. Spot-checked 3 samples
  (`binop_name`, `bd_default_cost`, `join_csv`) -- all consistent with
  their own stated (deliberately minimal) claim.



Running log of candidates from the usage-ranked list
([[patlang-slice2-usage-ranking]] in memory) triaged during the batch
pass. **All groups (A/B/C/D) are now RESOLVED** — every candidate
originally logged here has a real, independently-verified spec. Kept as
a record of what each one took and what was found, not as an open
backlog.

## Group A: x64_runtime.patlang tagged-pointer functions — RESOLVED
Not callable via `--ir-run` at all — worse than first suspected:
**including the WHOLE `x64_runtime.patlang` file breaks even functions
with plain-integer bodies and no tagged-value handling of their own**
(confirmed directly: `rt_payload_mask()`, body is just `return 1 shl 48
- 1`, still throws `band: expected an integer` the instant it's called,
purely because the file as a whole is included — isolating that exact
function alone in its own tiny file works fine). One confirmed
contributing factor: the file also redefines `print` itself (a
tagged-value-aware version), shadowing native `print` globally the
moment it's included. Not fully root-caused, but the practical
conclusion held: only the real `--x64` compile+run pipeline can verify
this file's functions.

Closed out by extending `friendly_cli/spec_scratch/
x64_stdlib_probe.patlang` with probe lines for all 5 remaining
candidates, recompiling via `patc1.exe ... --x64`, running the real
.exe, and confirming every value by hand: `char_code("ABC",0)=65`,
`char_code("ABC",2)=67`; `rt_print_i64(-42)` printed `"-42"`;
`file_exists` of a real file printed `"1"`, a nonexistent path printed
`"0"`; `sc_code(str_intern("XYZ"),0)=88`, `sc_char(...,2)="Z"`. Real
note kept in the specs: `sc_code`/`sc_char` ALSO exist as genuine,
DIFFERENT native host functions (`rust-runtime/src/ir/hosts.rs`
registers `sc_len`/`sc_code`/`sc_char`/`str_intern` directly) —
x64_runtime.patlang's own versions are unrelated thin wrappers around
`mem_peek_qword`/`mem_peek_byte`; confirm which one a given call site
resolves to before assuming this spec applies.

## Group B: complex/stateful self-hosted-compiler internals — RESOLVED
All 5 turned out tractable. The "needs deep domain understanding"
caution only applied to part of what's in these files, not the
specific functions ranked here — see [[patlang-slice2-x64-runtime-specs-and-let-gotcha]]
for the full story. `tokenize`/`parse_program` needed real
fixture-building (5 and 3 hand-checked scenarios respectively);
`synth2_ground`/`synth2_query`/`synth5_fact_binary` turned out to be
trivial one-line constructors once actually read, not the search logic
itself. Lesson for future triage: don't classify a candidate as complex
based on which file it lives in.

## Group C: test-framework / dev-tooling helpers — RESOLVED
`t_report` and `step` (self_hosting/lib/test.patlang). Resolved the
"who verifies the verifier" concern by being precise about what's
actually being claimed: NOT "does check() correctly judge equality"
(genuinely circular), but t_report's own narrow, observable contract —
given known `t_pass`/`t_fail` counter values (set directly via
`set_var`, bypassing `check()` entirely so the probe doesn't depend on
the thing it would be circular to assume), does `t_report` report and
return correctly? That's a plain, non-circular claim, verified true.
`step` verified by reading its real object-system side effect back
(`get(text, "fn")`), the same access pattern the framework's own
step-dispatch code uses.

## Group D: name collisions — RESOLVED
- `html_escape` (html.patlang vs html_scan.patlang) — CONFIRMED
  genuinely DIFFERENT: html.patlang's escapes `&`/`<`/`>`/`"`;
  html_scan.patlang's escapes only `&`/`<`/`>` (quote-escaping is a
  separate `html_attr_escape` function there). Found by running the
  SAME probe against both and getting a real `quote_ok=false` mismatch
  — not assumed. Both have their own correct, independent specs.
- `starts_with` (markdown.patlang vs test.patlang) — CONFIRMED
  byte-identical bodies by direct source read. Both independently
  verified anyway rather than assumed identical from the collision
  alone (following the same discipline as `nl`/`q`).

## Final tally
**40 real, independently-verified `.feature`/`.meta.json` pairs** in
`spec_library/patlang_stdlib/`: `lower_case`, `sb_new`, `sb_push`,
`sb_str`, `to_num`, `chr`, `substr`, `vec_new`, `vec_push`, `vec_get`,
`char_code`, `file_exists`, `sc_code`, `sc_char`, `rt_print_i64` (all
x64_runtime.patlang, the tagged-pointer cluster, verified via real
`--x64` compile+run), `nl` ×3 files, `q` ×2 files, `str_trim`,
`str_starts_with`, `contains_text`, `json_quote`, `html_escape` ×2 files
(genuinely different contracts), `sdsl_len`, `sdsl_trim`, `x64_nl_char`,
`tok_is`, `tpl_raw`, `tokenize`, `parse_program`, `synth2_ground`,
`synth2_query`, `synth5_fact_binary`, `t_report`, `step`, `starts_with`
×2 files.

This closes out the top-40-by-usage batch from
[[patlang-slice2-usage-ranking]]. Next candidates would come from
further down that ranked list (below the ~57-use cutoff of `sdsl_trim`)
or from the wider 850-candidate `likely_pure` pool
([[patlang-slice2-function-discovery]]) not yet touched by usage
ranking.
