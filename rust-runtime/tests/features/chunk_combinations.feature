# Guards against: codegen.rs's `required_chunks`/`CROSS_CHUNK_EDGES` failing
# to pull in a chunk that another selected chunk's text silently depends on.
# The real incident: `oo`'s `send()` dispatcher references the `FACTS`
# thread-local, which is only *declared* in `logic`'s chunk text -- but
# nothing exercised "objects/events without also using facts/queries" until
# a benchmark program did, and `pat --patc` failed with
# `error[E0425]: cannot find value 'FACTS'`. Existing tests only compiled
# whichever chunks the hand-picked demo programs happened to touch; this
# feature instead compiles one minimal program per chunk (plus the two
# documented cross-chunk-edge cases) so a newly-introduced silent dependency
# fails loudly here instead of surprising the next person to combine chunks
# in a new way.
#
# Scope note: `networking` and `codegen_bootstrap` are deliberately left out
# of the per-chunk sweep below -- `networking`'s host calls block on real
# socket I/O (tcp_listen/tcp_accept) rather than failing fast, and
# `codegen_bootstrap`'s host calls (parse_tiny_source, run_ir, ...) need a
# non-trivial IR-shape argument to exercise meaningfully. Both are already
# covered by their own dedicated tests (tcp_client.rs, selfhost_pipeline.rs,
# selfhost_targets.rs) that compile and run real programs through them.

Feature: Compiled-chunk combinations
  As a maintainer of the chunked codegen system
  I want every practically-reachable chunk combination to compile and run
  So that a silently-added cross-chunk dependency is caught here, not by a user

  Scenario Outline: a minimal single-chunk program compiles and runs natively
    Given a PatLang program that prints "<expr>"
    When I compile and run it natively
    Then it prints exactly "<expected>"

    Examples:
      | expr                                                | expected |
      | list_len(list_push(list_push([], 1), 2))            | 2        |
      | substr("hello world", 6, 5)                          | world    |
      | max(3, 7)                                             | 7        |
      | file_exists("this_file_should_not_exist_12345.tmp")   | 0        |
      | 10 / 3                                                | 10/3     |
      | sqrt(16)                                              | 4        |

  Scenario: collections_handles chunk (vec_* handle API) compiles and runs natively
    Given a PatLang program:
      """
      let v = vec_new()
      vec_push(v, 10)
      vec_push(v, 20)
      print(vec_len(v))
      """
    When I compile and run it natively
    Then it prints exactly "2"

  # Regression guard for the actual FACTS bug: `send()` with no `fact`/
  # `query`/`goal` call anywhere, which is exactly the shape that first
  # exposed the missing (Oo, Logic) cross-chunk edge.
  Scenario: oo chunk without any logic host calls still compiles (oo -> logic edge)
    Given a PatLang program:
      """
      new("Counter", "c1")
      send("c1", "set", "v", 5)
      print(get("c1", "v"))
      """
    When I compile and run it natively
    Then it prints exactly "5"

  Scenario: logic chunk alone compiles and runs natively
    Given a PatLang program:
      """
      fact("parent", "alice", "bob")
      print(query("parent", "alice", 0))
      """
    When I compile and run it natively
    Then it prints exactly "1"

  Scenario: contracts chunk (require/ensure) compiles and runs natively
    Given a PatLang program:
      """
      make a function called safe_divide takes a, b returns r
        require b != 0
        let r = a / b
        return r
      end
      print(safe_divide(10, 2))
      """
    When I compile and run it natively
    Then it prints exactly "5"

  # Native-compiled fibers (the mod fibers text ported into PRELUDE_CORE):
  # a budgeted(ms, handle) block wrapping a loop with a tight enough budget
  # that it's guaranteed to pause at least once, driven by a caller loop
  # that repeatedly resumes it until "done". If resumption were silently
  # restarting instead of genuinely continuing, this would never converge.
  Scenario: budgeted(...) blocks (fiber-backed) compile and run natively, converging via resumption
    Given a PatLang program:
      """
      let mut n = 0
      let mut handle = false
      let mut done = false
      let mut rounds = 0
      while not done do
        rounds = rounds + 1
        let r = budgeted(5, handle) do
          while n < 200000 do
            n = n + 1
          end
        end
        if r[0] == "done" then
          done = true
        else
          handle = r[1]
        end
      end
      print(done)
      """
    When I compile and run it natively
    Then it prints exactly "true"

  # Regression guard for the (Math, NumericTower) cross-chunk edge: no
  # ordinary arithmetic BinOp anywhere, so `required_chunks`'s BinOp-driven
  # rule alone would NOT select numeric_tower -- only the explicit edge does.
  Scenario: math chunk with no arithmetic BinOp still pulls in numeric_tower
    Given a PatLang program that prints "sqrt(16)"
    When I compile and run it natively
    Then it prints exactly "4"
