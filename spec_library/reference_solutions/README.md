# reference_solutions: written by a human, never claimed as synthesis

Every entry here is code a PERSON wrote — usually because an automated
attempt (logic induction, then an LLM) failed first, and a working
reference was still useful for curriculum progression or as a control.
None of these belong in `spec_library/synthesized_registry/`, and none
should ever be described as something "the system found."

## Why this directory exists at all
Direct, correct pushback from the project owner: *"I'm rather nervous
about these hand authored fallbacks - that implies you are writing the
code rather than the synthesis engine finding the right code to
use..."* Right — the earlier default behavior (LLM fails once, silently
write it myself, register it in the SAME pool as genuine induction
wins) was a real category error: my own code and the system's own
output looked identical in that directory's shape, distinguished only
by a metadata field. The fix isn't better labeling within one pool —
it's a genuinely separate pool, so the DIRECTORY is the signal, not
something a reader has to remember to check.

## What's here and why each one ended up here
- `sum_1_to_n`, `sum_of_evens`, `eval_rpn` — the LLM (llama3.2) failed
  every attempt (0/7 across the whole initiative so far); hand-authored
  after that failure, verified via the same real-execution + blind-
  holdout discipline as everything else, but the ALGORITHM is mine.
- `peano_arithmetic`, `stack_tally_arithmetic` — hand-SPECIFIED (the
  classic Peano encoding), because the current induction engine's
  clause-search template can't reach 3-argument relations like
  addition — verified rigorously (including an 81-pair consistency
  sweep against native arithmetic), but the RULES are mine, not found
  by a search.
- `is_palindrome_hand_authored` — written deliberately as a CONTROL, to
  settle whether the language itself was the obstacle to 3 failed LLM
  attempts (it wasn't) — explicitly never meant to be mistaken for a
  synthesis win, which is exactly why it's here and not in the
  registry.

## Still useful, just honestly labeled
`curriculum_available_functions_text()` (friendly_cli/lib/curriculum_
engine.patlang) reads from BOTH this directory and synthesized_
registry when injecting "available building blocks" into a later
problem's prompt — a reference solution is still a real, working,
callable thing worth reusing, even though it wasn't found by the
system itself. The distinction that matters is provenance, not
usability.
