# synthesized_registry: things a real mechanism actually found

Every entry here means a genuine automated process — logic induction
(`synth5_lgg_from_positive`/`synth2_induce_chain`) or GOAP planning
(`plan`/`pursue`) — produced the actual rule, plan, or action selection,
not a person. Real BDD verification (visible + held-back blind checks)
still applies to every entry, same as everywhere else in `spec_library/`.

**What does NOT belong here**: anything where a human wrote the actual
solution after an automated attempt failed. That goes in
`spec_library/reference_solutions/` instead — a deliberate, load-bearing
separation, not a formality. See that directory's own README for why.

This split exists because of a direct, correct challenge from the
project owner: *"I'm rather nervous about these hand authored fallbacks
- that implies you are writing the code rather than the synthesis
engine finding the right code to use..."* — right. Before this split,
a hand-authored fallback and a genuine induction win looked identical
in this directory's shape, distinguished only by a metadata field
someone had to remember to check. Now the DIRECTORY itself is the
signal.

## What's genuinely here right now
- `great_grandparent`, `is_even` — rules found by real logic induction,
  not written by a person.
- `fetch_parslow_redirect`, `fetch_parslow_https_via_curl` — plans
  (which actions, in what order) found by the real GOAP planner. Note:
  the ACTIONS themselves (their bound closures) were still hand-written
  — the planner only ever composed them, never wrote one. This is
  still a genuine automated result (the composition/search), just not
  a claim that the primitives were synthesized too.
- `goap_action_relevance_filter` — infrastructure (a real filtering
  algorithm), not a "solution" to a curriculum problem; kept here since
  it's genuinely-built tooling, not a stand-in for failed synthesis.
- `is_palindrome_TIER_B_ATTEMPT` — an honest FAILURE record (the LLM
  attempt didn't work), kept here because it makes no success claim at
  all — a failure record and a hand-authored success are different
  things, and only the latter needed to move out.
