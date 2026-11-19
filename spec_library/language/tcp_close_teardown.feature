Feature: TCP connection teardown (tcp_close)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A read on the peer after close returns empty, not an error
    Given the program
      """
      let port = tcp_listen(0)
      let client = tcp_connect("127.0.0.1", port)
      let server_conn = tcp_accept(port)
      tcp_close(client)
      print("[" + tcp_read(server_conn) + "]")
      """
    When it runs interpreted and compiled
    Then both print
      """
      []
      """
