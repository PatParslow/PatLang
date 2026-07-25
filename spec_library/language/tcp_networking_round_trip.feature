Feature: TCP networking (tcp_listen/connect/accept/read/write/close)

  Scenario: A client can connect before the server calls accept
    Given `require port > 0` after tcp_listen(0)
    When tcp_connect is called immediately, with no tcp_accept having run yet
    Then it succeeds (the OS backlog queues it) -- confirmed via a passing require, not assumed

  Scenario: Both directions of a round trip genuinely transfer bytes
    Given a connected client/server pair
    When the client writes "hello from client" and the server writes "hello from server"
    Then the server's tcp_read returns exactly the client's message, and the client's tcp_read returns exactly the server's message

