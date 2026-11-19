Feature: TCP networking (tcp_listen/connect/accept/read/write/close)

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: A client can connect before the server calls accept
    Given the program
      """
      let port = tcp_listen(0)
      print(port > 0)
      let client = tcp_connect("127.0.0.1", port)
      print(client >= 0)
      tcp_close(client)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      true
      """

  Scenario: Both directions of a round trip genuinely transfer bytes
    Given the program
      """
      let port = tcp_listen(0)
      let client = tcp_connect("127.0.0.1", port)
      let server_conn = tcp_accept(port)
      tcp_write(client, "hello from client")
      tcp_write(server_conn, "hello from server")
      print(tcp_read(server_conn))
      print(tcp_read(client))
      tcp_close(client)
      tcp_close(server_conn)
      """
    When it runs interpreted and compiled
    Then both print
      """
      hello from client
      hello from server
      """
