Feature: build_daemon (exemplar: logic + GOAP + timing/persistence + events + signals, self_hosting/lib/build_daemon.patlang)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang). The program spawns
  self_hosting/examples/build_daemon_demo.patlang on the v2 interpreter, finds
  it by the announcement it makes once it holds its port, asks it for its
  status and tells it to quit.

  Scenario: A detached primary runs a GOAP-planned build cycle, answers status, and stops on quit
    Given the program
      """
      include "{lib}/v2_engines.patlang"
      include "{lib}/signal_discovery.patlang"
      let history = "portfolio/build/build_daemon_history.txt"
      let had = file_exists(history) == true
      let backup = ""
      if had then
        let backup = read_file(history)
      end
      let started = now_ms()
      let pid = spawn(v2_interpreter(), "self_hosting/examples/build_daemon_demo.patlang")
      let port = ""
      while (port == "") and is_alive(pid) do
        sleep_ms(50)
        let port = signal_discover_one("build_daemon", now_ms() - started)[0]
      end
      print(port != "")
      let reply = signal_query(to_num(port), "status", "")
      print(str_contains(reply, "rebuilt"))
      signal_send(to_num(port), "quit", "")
      while is_alive(pid) do
        sleep_ms(50)
      end
      print(is_alive(pid))
      if had then
        write_file(history, backup)
      elif file_exists(history) == true then
        write_file(history, "")
      end
      let restored = ""
      if file_exists(history) == true then
        let restored = read_file(history)
      end
      print(restored == backup)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      true
      false
      true
      """

  IMPORTANT: this exemplar writes to a REAL SHARED file (portfolio/
  build/build_daemon_history.txt), not an isolated scratch path -- the
  program backs up that file's content first and restores it afterward,
  and prints whether it is byte-for-byte equal again.
