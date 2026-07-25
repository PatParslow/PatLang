Feature: signals full round trip (signal_send/signal_query/signal_reply, two real concurrent processes)

  Scenario: A query reaches the primary and its reply reaches the secondary, verbatim
    Given a detached primary process (launched via `start /B`) with `when status do signal_reply("uptime: 42") end` registered
    When a separate, synchronous secondary process calls signal_query(port, "status", "")
    Then it receives exactly "uptime: 42" -- the primary's own handler's reply text, round-tripped over the real TCP connection between two real OS processes

  Scenario: A fire-and-forget quit signal stops the primary's poll loop early
    Given the secondary also calls signal_send(port, "quit", "") afterward
    When the primary's own log is inspected after the fact
    Then it shows the primary exited via the quit path, not by running its full bounded iteration count

  This closes the gap [[patlang-language-instruction-specs]]'s earlier
  single-process signals spec explicitly left open (the full round trip
  needs two genuinely concurrent processes, which a single synchronous
  script cannot provide) -- a batch file with `start /B` supplies the
  real concurrency PatLang itself has no host function for yet.

