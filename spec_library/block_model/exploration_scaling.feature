Feature: exploration under block-model is linear in the number of states (GitHub issue #179)

  zs_explore's breadth-first search records each state it has seen and asks
  whether a new state is among them. Under block-model the visited set is the real
  engine's hash-backed named Dict (named_objects.feature), so each check is one
  hash lookup and exploring N states costs O(N). A list-backed set would make the
  same exploration O(N^2).

  The check is a ratio, not a wall-clock threshold. A bounded counter has exactly
  K + 1 reachable states; it is explored at K = 100, 200, 400 and 800 through
  block-model and, for reference, under the real engine. Linear growth makes the
  K = 800 time about 8 times the K = 100 time; quadratic growth would make it about
  64, so the scenario asserts under 24. The absolute block-model time is about 480
  times the real engine's, which is the cost of running the interpreter on the
  interpreter and is not what this scenario is about.

  Scenario: exploring 8 times as many states costs under 24 times as long, under block-model and under the real engine
    Given a bounded counter explored at 100, 200, 400 and 800 states
    When it runs under block-model and under the real engine
    Then each engine's K=800 time is under 24 times its K=100 time
