Feature: build_daemon (exemplar: logic + GOAP + timing/persistence + events + signals, self_hosting/lib/build_daemon.patlang)

  Scenario: A detached primary runs an initial GOAP-planned build cycle
    Given self_hosting/examples/build_daemon_demo.patlang launched with no CLI args (via `start /B`)
    When it claims the signal port
    Then it runs a build cycle derived from real logic facts (rule_add/solve) and a real cost-weighted GOAP plan (action_add/plan), logging via when/emit

  Scenario: A separate 'status' invocation gets a real reply
    Given the primary is still running
    When a separate process runs the same demo with "status" as its CLI argument
    Then it receives a reply describing what was actually rebuilt -- a real signal_query round trip, same mechanism as the standalone signals spec

  Scenario: A separate 'quit' invocation cleanly stops the primary
    Given the primary is still polling
    When a separate process sends "quit"
    Then the primary's own log shows "DAEMON: exiting", not left running indefinitely

  IMPORTANT: this exemplar writes to a REAL SHARED file (portfolio/
  build/build_daemon_history.txt), not an isolated scratch path -- any
  test driving this program for real must back up that file's existing
  content first and restore it afterward, confirmed byte-for-byte equal
  again, exactly as this probe itself does.

