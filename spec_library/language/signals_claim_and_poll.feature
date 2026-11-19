Feature: signals (signal_claim/signal_poll -- port ownership + idle polling)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). Claims are on port 0, so the
  system picks a port no other program on the machine holds.

  Scenario: The first claimant of a port becomes its primary, and a second claim is rejected
    Given the program
      """
      include "{lib}/signals.patlang"
      let port_id = signal_claim(0)
      print(port_id >= 0)
      print(signal_claim(port_id))
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      -1
      """

  Scenario: Polling an idle port times out to empty, not an error
    Given the program
      """
      include "{lib}/signals.patlang"
      let port_id = signal_claim(0)
      print("[" + signal_poll(port_id, 20) + "]")
      """
    When it runs interpreted and compiled
    Then both print
      """
      []
      """

  Scenario: Polling an inherited port_id from a DIFFERENT thread is a no-op, not a crash (GitHub #79)
    Given the program
      """
      include "{lib}/signals.patlang"
      make a function called poll_elsewhere takes id returns got
        return signal_poll(id, 50)
      end
      let port_id = signal_claim(0)
      print(parallel_map([port_id, port_id], "poll_elsewhere") == ["", ""])
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      """

  The full signal_send/signal_query/signal_reply round trip, between two
  processes, is signals_full_round_trip.feature's.
