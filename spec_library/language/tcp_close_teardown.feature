Feature: TCP connection teardown (tcp_close)

  Scenario: A read on the peer after close returns empty, not an error
    Given a connected pair, then `tcp_close(client)`
    When the server side calls tcp_read on its end of the connection
    Then it returns "" (an ensure guard on this exact fact passes) -- confirming the close was a real, graceful teardown the peer can observe, not just a local no-op

