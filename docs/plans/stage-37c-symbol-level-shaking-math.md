# Stage 37C — Symbol-level shaking for `math.patlang` (built now, per the user's explicit choice)

See [`README.md`](./README.md) for shared context, locked-in decisions, and
the master critical-files list.

**Depends on / related:**
- Builds on the manifest/dedup infrastructure from
  [`stage-37b-dependency-aware-library-inclusion.md`](./stage-37b-dependency-aware-library-inclusion.md).
- The primary consumer of this mechanism is
  [`stage-39-math-library.md`](./stage-39-math-library.md) — each function in
  `math.patlang` gets a `deps.manifest` entry specifically so this splice
  mechanism can shake it per-function.
- Uses the same style of call-graph walk as `lowering.rs`'s existing
  `collect_referenced_idents`, referenced also in
  [`stage-36-numeric-tower-interpreter.md`](./stage-36-numeric-tower-interpreter.md)'s
  broader IR-walking conventions.
- Verified per [`verification-plan.md`](./verification-plan.md), including
  the live end-to-end check that compiling a program calling only `sqrt`
  excludes `factorial`/`is_prime` from the emitted source.

## Goal

Build real per-function dependency tracking for the math library specifically
(not just file-level), as the user explicitly chose this over deferring it.

## Detailed design

New directive on `include`: `include "path" only [fn1, fn2, ...]` (confirm
keyword style against `self_hosting/lib/parser.patlang`'s existing grammar
conventions before finalizing syntax).

### Mechanism

1. Parse the target file once with the existing lexer/parser (reuse, don't
   reinvent); walk the resulting `Stmt::Function` list to build
   `fn_name -> source_span` and `fn_name -> Set<called_fn_names>` (same style
   of walk as `lowering.rs`'s existing `collect_referenced_idents` used for
   closure free-variable analysis).
2. Given the requesting program's own call set (a `required_chunks`-style
   scan for `Call("sqrt", ...)` etc. — see
   [`stage-37a-host-prelude-chunking.md`](./stage-37a-host-prelude-chunking.md)
   for the analogous host-function-side mechanism), compute the transitive
   closure of needed library functions.
3. Splice only those functions' original source spans (line-range based, not
   AST-reserialized, to avoid whitespace/formatting drift) into the
   expansion, in place of whole-file concatenation.
4. Dedup `(canonical_path, fn_name)` pairs across the whole recursive
   expansion.

### New tooling

New tool `self_hosting/tools/tree_shake_lib.patlang` (or inlined into
`codegen.patlang`) implementing the PatLang-side equivalent for the
self-hosted front end, and `self_hosting/tools/patbuild_main.patlang` /
`patbuild.manifest` updated so any `+`-joined component naming a
`deps.manifest` entry with declared symbol-level info goes through this path
instead of `read_bundle`'s raw concatenation.

## Files touched

- `self_hosting/lib/parser.patlang` (new `include ... only [...]` grammar)
- `self_hosting/tools/tree_shake_lib.patlang` (new)
- `self_hosting/tools/patbuild_main.patlang`, `patbuild.manifest`

## Tests

No dedicated file called out separately in the source plan for this
sub-stage; covered by:
- The Stage 39 math-library tests (functions have `deps.manifest` entries
  specifically to exercise this mechanism).
- The live end-to-end check #5 in
  [`verification-plan.md`](./verification-plan.md): "Compile a program
  calling only `sqrt` from `math.patlang` — confirm the emitted source
  contains `sqrt`'s definition but not `factorial`/`is_prime`."
