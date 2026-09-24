Feature: lowering time is linear in a function body's size (GitHub issue #156)

  `bm_lower_program` took about 4x as long per doubling of a function body's
  statement count. The cause, confirmed by isolating one variable: this runtime
  copies a list on `list_push` whenever something else still refers to it, and
  `let instrs = bm_lower_stmt(stmt, instrs, ...)` kept the caller's binding
  alive across the call, so every statement copied the whole instruction list
  accumulated so far.

  The fix keeps the accumulator from crossing a call boundary: each statement is
  lowered into a fresh fragment, the fragment's jump targets (relative to its own
  start, since it began empty) are shifted by the accumulated length, and it is
  appended with an inline push loop.

  Two more sources of the same copy were removed: `bm_collect_let_names` (the
  function's bound-name set, one union call per `let`) and the free-variable
  analysis's `bound` set and the lowerer's `known_locals`, which grew by one
  entry per `let` rather than per distinct name.

  What stays: name lookups scan a list, so cost is O(n * d) for n statements and
  d DISTINCT local names in scope. The `lets` shape therefore cycles through 20
  names; a body with thousands of distinct locals is still quadratic in d, which
  is unrealistic for hand-written code and is stated here rather than hidden.

  The check is a ratio, not a wall-clock threshold: a shape is lowered at 2000
  and at 8000 statements, and linear growth makes the second about 4x the first
  while quadratic growth makes it about 16x, so the scenario asserts the ratio
  stays under 8.

  Scenario: lowering 8000 statements costs under 8x lowering 2000, for every statement shape
    Given function bodies of bare calls, lets, an if-branch of calls, sequential ifs, and many small functions
    When each is lowered by bm_lower_program at 2000 and at 8000 statements
    Then every 8000-statement time is under 8 times its 2000-statement time
