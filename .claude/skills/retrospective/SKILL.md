---
name: retrospective
description: Use after a burst of live debugging or firefighting, after a long task where several things went wrong, or when the owner asks for a retrospective. Produces what broke, why, what made it slow to find, and turns each lesson into a check, a tool, a CLAUDE.md line or a skill step -- not only a memory.
---

# retrospective

A retrospective is finished when its lessons are in force, not when they are
written down. Run it unprompted after a dev spike (CLAUDE.md 2.6, hardening loop).

## 1. Gather facts first

- The commits and diffs of the session (`git log`, `git diff`), the failures and
  their exact messages, and how long each took to find.
- Measure before claiming: count the files a problem affects, time the slow unit,
  grep for the same pattern elsewhere. A retrospective that guesses misleads.

## 2. Write it

For each problem:
- **What broke**, with the evidence.
- **The cause**, and why an earlier theory was wrong if there was one.
- **What made it slow or fast to find.**
- **Mine or the system's**: name your own mistakes plainly (a skipped check, a
  convention-dependent fix, an edit during a gates run).

Then what worked, so it is kept.

## 3. Turn each lesson into something that acts

Rank the fixes by value for effort, and for each pick the strongest form that fits:

1. **A check that fails** (a repository scenario, a selftest check, a contract):
   the next occurrence cannot pass the gates.
2. **A tool** that makes the right way the easy way (`tools/edit_files.py`,
   `lib/program_run.patlang`, `gates.sh --kill`).
3. **A skill step** for a procedure (`patlang-change`, `gates`).
4. **A CLAUDE.md line** for a rule that needs judgement.
5. **A memory**, only for what belongs to how this owner works and the repo cannot
   hold.

A lesson recorded only as a memory has not been acted on. If the same kind of
problem has happened before, the earlier fix was too weak: move it up this list.

## 4. Report

Say which lessons became which check, tool, skill step or rule, which are filed as
issues (on board 5), and which were not done and why.
