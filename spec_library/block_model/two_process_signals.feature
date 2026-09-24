Feature: a block-model program talks to a separate OS process over real signals (GitHub issue #178)

  The acceptance test #178 named: `spawn` plus `signal_query`, through the block
  engine, matching `pat --ir-run`. self_hosting/tools/spec_fixtures/signal_secondary.patlang
  spawns signal_primary.patlang (a real detached child that claims port 9701 with
  `signal_claim`, answers `status` through a `when` handler calling `signal_reply`,
  and stops on `quit`), sleeps while the child claims its port, sends the query over
  real loopback TCP, prints the reply, sends `quit`, waits for the child to exit and
  prints what the child logged about how it stopped.

  The same file is run twice, unchanged: directly under `pat --ir-run` (the
  reference) and through the block engine by the generic driver, whose include base
  is now the program's own directory. Both runs use the same port one after the
  other; the language spec gate uses it too, so neither runs at the same time as the
  other.

  What made it possible, each with its own scenario: the named-object contract
  (named_objects.feature) and handlers that call declared functions
  (event_dispatch.feature). `spawn`, `sleep_ms`, `is_alive` and the `tcp_*` calls
  needed nothing new: the shared host table already served them.

  Scenario: a block-model program queries a spawned child over real TCP signals and matches the real engine
    Given a program that spawns a signal primary in another process, queries its status, tells it to quit and reads its log
    When it runs through the block engine and again under the real engine
    Then both print the child's reply and the child's own account of stopping via quit, identically
