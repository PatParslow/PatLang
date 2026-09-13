Feature: signals (signal_claim/signal_poll -- port ownership + idle polling)

  Scenario: The first claimant of a port becomes its primary
    Given signal_claim(9601) called for the first time
    When the result is checked
    Then it is >= 0 (a real port_id)

  Scenario: A second claim on the same port is rejected
    Given the same process still holds the port from the first claim
    When signal_claim(9601) is called again
    Then it returns -1 -- the free single-instance-detection this subsystem relies on

  Scenario: Polling an idle port times out to empty, not an error
    Given a claimed port with nothing sent to it
    When signal_poll(port_id, 20) is called
    Then it returns "" within the timeout, not an error or a hang

  Scenario: Polling an inherited port_id from a DIFFERENT thread is a no-op, not a crash (GitHub #79)
    Given a port claimed on the main thread, then its port_id handed to parallel_map workers running on their own OS threads
    When each worker calls signal_poll(port_id, 50)
    Then every worker returns "" -- the listener genuinely lives only on the claiming thread, but a poll from elsewhere reports "nothing here" instead of the old fatal "no listener on port N" error

  IMPORTANT SCOPE NOTE: the full signal_send/signal_query/signal_reply
  round trip needs TWO genuinely concurrent processes (a primary polling
  in a loop while a secondary connects and queries it) -- PatLang has no
  detached-process-spawn host function today, so this cannot be proven
  by a single synchronous test script. NOT covered here; would need a
  real two-terminal/two-process manual or CI-level test.

