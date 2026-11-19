Feature: signals full round trip (signal_send/signal_query/signal_reply, two real concurrent processes)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). The program is the secondary: it
  spawns the primary (self_hosting/tools/spec_fixtures/signal_primary.patlang)
  on the v2 interpreter, waits for the "port N" line the primary writes to its
  log once it holds a port, and talks to it over loopback TCP.

  Scenario: A query reaches the primary and its reply comes back verbatim, and a quit signal stops it early
    Given the program
      """
      include "{lib}/v2_engines.patlang"
      include "{lib}/signals.patlang"
      let log_path = "self_hosting/tools/spec_fixtures/signal_primary.log"
      write_file(log_path, "")
      let pid = spawn(v2_interpreter(), "self_hosting/tools/spec_fixtures/signal_primary.patlang")
      let port = 0 - 1
      let looking = true
      while looking do
        let text = read_file(log_path)
        let n = text.length
        if (n > 6) and (substr(text, 0, 5) == "port ") and (char_code(text, n - 1) == 10) then
          let port = to_num(substr(text, 5, n - 6))
          let looking = false
        elif not is_alive(pid) then
          let looking = false
        else
          sleep_ms(20)
        end
      end
      print(signal_query(port, "status", ""))
      signal_send(port, "quit", "")
      while is_alive(pid) do
        sleep_ms(50)
      end
      print(read_file(log_path))
      """
    When it runs interpreted and compiled
    Then both print
      """
      uptime: 42
      exited via quit path
      """

  The primary stops by itself after 200 polls of 100 ms, so the wait for it
  to exit ends either way; its log says which way it went.
