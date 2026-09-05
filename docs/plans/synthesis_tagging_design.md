# Plan: Descriptive tagging for the synthesis-engine primitive/composite registry

**Status: corrected and being implemented (2026-09-06).**

## Context

PatLang's synthesis/GOAP stack already has formal contracts (`require`/`ensure`,
lowered to `contract_check(...)`) and a primitive/composite registry
(`pr_register`/`pr_lookup` in `self_hosting/lib/primitive_registry.patlang` and
`friendly_cli/synthesis_experiment_goap_relevance_full_registry.patlang`) that
stores arity, cost, arg/ret types, and per-arg contract predicates. Contracts
are precise but expensive to check across a growing library, and there's no
cheap way to ask "what's roughly in the ballpark of this goal" before paying
for contract/type verification. The user wants to add associative, human- and
machine-legible **tags** (`#doubling`, `#dsp`, `#math:geometry`,
`#complexity:o-1`) as a semantic pre-filter layer sitting in front of the
existing contract/type checks in the GOAP candidate-gathering path, and wants
a concrete recommendation on whether tags are manually authored, synthesizer-
managed, or both.

This plan is design-only — no code changes were made; it lays out the
concrete additions for a future implementation pass.

## Existing infrastructure this builds on

- **Registry** (`self_hosting/lib/primitive_registry.patlang`,
  `friendly_cli/synthesis_experiment_goap_relevance_full_registry.patlang`,
  `friendly_cli/lib/goap_relevance.patlang`): Dict-backed via `pr_new_registry`
  / `pr_register` / `pr_lookup`, entries shaped
  `["prim"|"composite", fn_or_ast, arity, cost, snippets, arg_types, ret_type, arg_contracts]`,
  with a secondary inverted index `__by_ret_type__` mapping
  `ret_type -> [names]` for "what produces type X" queries — this is the
  direct precedent for the new tag index.
- **Contracts**: `require`/`ensure`/`assert` lower to `contract_check(func, kind, text, ok)`
  (`rust-runtime/src/ir/lowering.rs:365-374`) — inline, per-function, not
  queryable metadata. The registry's own `arg_contracts` field (predicate
  function names per argument) is the closer, lighter-weight analog tags sit
  alongside.
- **The actual enumerative synthesis engine — corrected after checking the
  live code, not just the plan's original assumption**: `synthesize_from_examples`
  (`self_hosting/lib/synthesis_by_example.patlang:765-845`) and its GOAP-driven
  twin `goap_synthesize_from_examples` (`self_hosting/lib/goap_synthesis.patlang:315-370`)
  are where primitive candidates actually get gathered. Both take a
  `primitive_names` list argument and loop over it at every search-size
  level, calling `pr_lookup(registry, prim)` per name (`synthesis_by_example.patlang:830-831`,
  `goap_synthesis.patlang:347-348`) — there is no return-type or other
  index-based narrowing on this path today.
  `pr_names_for_ret_type`/`__by_ret_type__` (the plan's original assumed
  insertion point) is real but is dead code: defined in
  `primitive_registry.patlang`, never actually called anywhere in the repo.
  Every existing caller (`self_hosting/examples/synth_demo_*.patlang`) instead
  hand-curates a small `primitive_names` list (1-9 names) per call, precisely
  to dodge the cost of a large search space — which is exactly the workaround
  tags are meant to make unnecessary: pass the whole registry and let
  `pr_lookup_by_tags` do the narrowing instead of hand-picking names forever.
- `register_composite` (`self_hosting/lib/synthesis_by_example.patlang:1138`)
  is the composite-registration path and already builds `__by_ret_type__`
  right there (lines 1167-1170) — the direct precedent/insertion point for
  composite auto-tagging (§4) and the new `__by_tag__` index.
- **Out of scope**: `friendly_cli/synthesis_experiment_goap_relevance_full_registry.patlang`
  and `friendly_cli/lib/goap_relevance.patlang` are a different, STRIPS-style
  GOAP goal-planning catalog (`[name, preconditions, effects, extra, cost]`
  action tuples, no `ret_type`/`arg_contracts`/registry at all) — not a copy
  of `primitive_registry.patlang`, and not something this design mirrors
  additions into. Tagging that catalog, if ever wanted, needs its own design
  against its own data shape.
- No existing hierarchical/faceted tag-like string convention, and no
  embedding/vector-similarity infrastructure anywhere in the repo — this is
  new ground, so the design stays string/Dict-based rather than reaching for
  NL embeddings.

## Design

### 1. Storage: forward field + inverse index (mirrors `__by_ret_type__`)

- Add a `tags` list as a new trailing field on registry entries:
  `[..., arg_contracts, tags]`.
- Add a new top-level registry key `__by_tag__`: `tag string -> [names]`,
  built the same way `__by_ret_type__` already is.
- Both are needed: the forward field lets composite auto-tagging read an
  ancestor's tags (§4) and supports introspection via `pr_lookup`; the
  inverse index is what makes "find everything tagged X" O(1) instead of a
  full scan — the entire point of a pre-filter.
- Always access tags through a new accessor `pr_tags(entry)` (returns `[]`
  if the field is absent) rather than positional indexing, so entries
  created before this change (shorter lists) don't need to be rewritten.

### 2. Tag string format

- Stored without a leading `#` (that's a display/authoring convention only):
  `"doubling"`, `"math:geometry"`, `"o-1"`.
- **Faceted tags**: single `facet:value` form — `math:geometry`, `io:stream`,
  `collection:transform`, `complexity:o-1`, `allocation:zero`,
  `paradigm:functional`. One colon only for now (splitting logic stays
  trivial); deeper nesting can be added later without a format change.
- **Free tags**: no colon, for fuzzy/associative concepts that don't yet fit
  a facet (`"doubling"`, `"smoothing"`, `"dsp"`). Facets are reserved for a
  small fixed vocabulary (domain, complexity, allocation, paradigm, purity);
  popular free tags get promoted into a facet later via a curation pass, not
  forced upfront.
- Add a `pr_tag_valid(tag)` helper (lowercase, at most one colon, no spaces —
  use `-`) called at registration time.

### 3. Non-breaking registry API change

- Leave `pr_register(...)` (existing 9-arg signature) untouched — zero
  call-site churn.
- Add `pr_register_tagged(registry, name, try_fn_name, arity, cost, snippets, arg_types, ret_type, arg_contracts, tags)`
  that does everything `pr_register` does plus populates `tags` and
  `__by_tag__`. Have `pr_register` internally delegate to
  `pr_register_tagged(..., [])` so there's one code path.
- Add `pr_lookup_by_tags(registry, tags, mode)` (`mode` = `"any"`/`"all"`) in
  the same file, next to the return-type lookup, following existing style.

### 4. Manual authoring vs. auto-inference — recommended: both, staged

- **Primitives (leaves): manually authored** via `pr_register_tagged` at
  registration time — small, fixed, human-curated set; no ancestor to infer
  from.
- **Composites (synthesized): auto-tag as provisional suggestions**, derived
  from provenance, not invented from scratch:
  1. **Ancestor-intersection/union rule**: once a composite passes
     contract/type checking, take the intersection of shared facet-value
     tags across its constituent primitives per facet, and the union of
     their free tags.
  2. **Structural derivation** for a few cheap facets (`complexity:o-1`,
     `allocation:zero`, `purity:pure`) computed from the composite's own
     `cost` field and whether any constituent breaks purity/allocation —
     reuses data the registry already computes.
  3. Written into the composite's `tags` field immediately (so search works
     right away) but distinguishable as provisional (e.g. a parallel
     `tags_suggested` marker) for later human review or auto-promotion once
     a tag is independently re-derived enough times. Wrong tags are low-risk
     since tags only ever narrow the pre-filter — the contract/type stage
     still gates correctness.

### 5. Where this plugs into the synthesis search

- Corrected insertion point: `synthesize_from_examples` and
  `goap_synthesize_from_examples` both accept a `primitive_names` list
  from their caller and loop over it directly — no index sits in front of
  that today. Add a new, non-breaking wrapper rather than changing either
  function's signature:
  `pr_narrow_by_tags(registry, primitive_names, intent_tags, mode)` —
  if `intent_tags` is `[]`, returns `primitive_names` unchanged; otherwise
  calls `pr_lookup_by_tags(registry, intent_tags, mode)` and intersects
  the result with `primitive_names` (preserving `primitive_names`' order,
  so existing determinism — "first match in original order wins" — is
  untouched).
- A caller that wants tag-narrowing passes
  `pr_narrow_by_tags(registry, all_candidate_names, ["dsp", "smoothing"], "any")`
  as the `primitive_names` argument instead of a hand-curated list; a
  caller that doesn't care about tags keeps passing its own list exactly
  as today, unchanged. Fully additive — no existing call site
  (`synth_demo_*.patlang`) needs to change.
- Inferring intent tags automatically from goal/example text is explicitly
  deferred; start with explicit tags only.

### 6. Migration/rollout (no big-bang rewrite)

- `tags` defaults to `[]`; untagged legacy entries are simply absent from
  `__by_tag__` and still resolve correctly through existing return-type/
  contract search — tags are additive, never required for lookup.
- Backfill by converting existing `pr_register(...)` call sites to
  `pr_register_tagged(...)` incrementally, one domain/file at a time (e.g.
  string primitives, then int, then network), each a small independently
  reviewable/testable diff.
- No format-version bump needed — the registry Dict is rebuilt fresh from
  source `pr_register` calls each run, not persisted/serialized.

### 7. Testing (RED/GREEN selftest, per repo convention)

`self_hosting/primitive_registry_tags_selftest.patlang`
(`include "lib/test.patlang"`, `t_init()`, `check(...)`, same shape as
`synthesis_by_example_selftest.patlang`), covering:

- Registration populates both the forward `tags` field and `__by_tag__`.
- Untagged (plain `pr_register`) entries return `[]` from `pr_tags` and
  don't appear in any `__by_tag__` bucket — backward compatibility.
- `pr_lookup_by_tags` "any" vs. "all" semantics with overlapping tag sets.
- `pr_narrow_by_tags` narrows a `primitive_names` list to the tagged
  subset when intent tags are given, and returns it unchanged when
  `intent_tags` is `[]`.
- Composite auto-tag inheritance: given two tagged primitives combined into
  a passing composite via `register_composite`, assert the specific derived
  tag set per the intersection/union rule in §4.

## Files to touch

- `self_hosting/lib/primitive_registry.patlang` — `tags` field, `__by_tag__`
  index, `pr_register_tagged`, `pr_lookup_by_tags`, `pr_tags`, `pr_tag_valid`.
- `self_hosting/lib/synthesis_by_example.patlang` — composite auto-tagging in
  `register_composite` (§4), `pr_narrow_by_tags` wrapper (§5).
- New `self_hosting/primitive_registry_tags_selftest.patlang` — this is a
  library feature, not a language-semantics change, so it follows the
  existing `*_selftest.patlang` convention (see
  `self_hosting/synthesis_by_example_selftest.patlang`) rather than
  `spec_library/language/*.feature`, which is reserved for language-syntax/
  semantics gates per `CLAUDE.md` §3.

## Verification

- Run the new selftest with `./patc1.exe self_hosting/primitive_registry_tags_selftest.patlang`,
  RED before / GREEN after per repo convention.
- Manually exercise `pr_lookup_by_tags`/`pr_narrow_by_tags` against
  `pr_standard_registry()` to confirm narrowing actually reduces candidate
  counts on a realistic goal.
- Confirm no existing `pr_register(...)` caller or `pr_lookup` consumer
  breaks — re-run `self_hosting/synthesis_by_example_selftest.patlang` and
  a couple of `self_hosting/examples/synth_demo_*.patlang` to confirm
  they're untouched by the change (additive only).
