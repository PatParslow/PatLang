Feature: port_marshal package: one well-known port, services found by name
  A marshaller listens on one port. A service listens on any free port (port 0)
  and registers a name with it; a client asks for the name and is piped through
  to the service, both ways, until either side ends. Each scenario runs the
  marshaller, its services and its clients in this process, on threads, with the
  marshaller on a port the system chose, and stops it with quit afterwards.

  Background:
    Given a marshaller on a free port
    And an echo service registered as "echo"

  Scenario: a client reaches a service by its name, and every byte comes back as sent
    When a client connects to "echo"
    Then the marshaller answers OK
    And bytes 0 to 255 sent through it come back the same
    And a block of 1 MB sent through it comes back the same

  Scenario: a name nothing has registered is refused
    When a client connects to "nobody"
    Then the marshaller answers "ERR no service nobody" and closes

  Scenario: two clients on one service at once each get their own bytes
    When two clients connect to "echo" and each sends 64 KB of its own bytes, in turns of 4 KB
    Then each gets back exactly what it sent

  Scenario: a close on either side reaches the other
    When a client connects to "echo" and closes
    Then the echo service sees its connection end
    When a client connects to "echo" and the service closes its end
    Then the client sees its connection end

  Scenario: registering takes the marshaller's token, and a name a live service holds
    Then REGISTER with a wrong token is refused
    And REGISTER of "echo" by another service is refused while the first is listening

  Scenario: a service that has stopped is dropped at the next CONNECT
    When the echo service stops listening
    And a client connects to "echo"
    Then the marshaller answers "ERR no service echo" and closes
    And LIST no longer names "echo"

  Scenario: a client that sends nothing holds up no one
    When a client connects to the marshaller and sends nothing
    And another client connects to "echo"
    Then the second client's bytes come back within a second

  Scenario: the marshaller answers status while it pipes, and after quit its port is free
    When a client connects to "echo" and keeps sending
    Then a status query names "echo", 1 pair open, and bytes moved each way
    When the marshaller is sent quit
    Then it ends, and its port can be listened on again
