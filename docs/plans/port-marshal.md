# Port marshal: one well-known port, services found by name

Decided 2026-11-22: a package and daemon (`packages/port_marshal`), services that
register at runtime, a new runtime call `tcp_wait_any` for waiting on several
connections, `tcp_unlisten` for closing a listener, and signals left as they are
for now (whether they move onto the marshaller is a later, separate decision).

## Why

Programs here claim fixed ports: signals scan 9430 to 9439, the build daemon has
9410 and 9420, and two programs that want the same port collide. With a
marshaller, only one port is fixed (9400). A service listens on port 0, the
system gives it any free port, and it registers a name. A client asks the
marshaller for the name and is piped through to it.

## Runtime additions (spec 1.8, the TCP bullets)

- `tcp_unlisten(port)` closes this program's listener on `port`, which is then
  free. It stops the program for a port it is not listening on, as `tcp_close`
  does for an unknown connection. `tcp_accept` and `tcp_accept_timeout` look up
  the listener at every turn of their wait: after it is closed, a thread waiting
  in `tcp_accept_timeout` gets -1, and one in `tcp_accept` stops, saying the
  listener was closed. Neither waits on a socket the system has given to
  someone else.
- `tcp_wait_any(conns, ports, ms)` waits up to `ms` (-1 for no limit) for any of
  the connections `conns` to have something to read, or the peer to have closed,
  or any listener in `ports` to have a client waiting. It gives
  `[ready_conns, ready_ports]`, both in the order given, and `[[], []]` when the
  time is up. It is `select` on Windows and `poll` on Linux. An unknown
  connection or port stops the program, as the other calls do.

Both go in `os_windows.patlang` and `os_linux.patlang`, next to `tcp_try_listen`.
The browser host has no TCP.

## The protocol (lines end with LF)

From a client to port 9400, the first line:

- `CONNECT name`. The answer is `OK` followed by the piped bytes both ways, or
  `ERR no service name`, after which the marshaller closes.
- `REGISTER name port token`. The answer is `OK`, or `ERR ...` for a bad token,
  a name already held by a live service, or a port that nothing is listening on.
- `UNREGISTER name token`, and `LIST`, which gives one name and port per line,
  then an empty line.
- `STATUS`, which gives `services=N names=a,b open=N done=N up=N down=N`, the
  bytes counting the open pairs so far; and `QUIT token`.

The token is the marshaller's run token, written where the signals write
theirs (`signal_token_path`, under the user's own profile). Only the same user
can register, which is as far as signals go. CONNECT needs no token: a local
service is reachable on its own port anyway.

A name leaves the table when it is unregistered, or when a CONNECT finds nothing
listening on its port. The client then gets `ERR no service name`.

A service that registers is not probed: the marshaller would make a connection
the service never asked for, and the first build's probe took an echo service's
only accept. The name's holder is probed only when another service asks for a
name already held, so a service that restarts on another port can take its
name back.

## The daemon

- **One control thread** owns the route table, and nothing else writes it. It
  waits with `tcp_wait_any` on the listener, on connections whose first line has
  not finished arriving (so a client that sends nothing holds up no one), and on
  its signals.
- **Each CONNECT that succeeds gets a pump thread.** It is handed the two
  connections and nothing else, waits on both with `tcp_wait_any`, writes what
  arrives to the other side, closes both when either side ends, and returns the
  bytes it moved each way. A slow reader holds up only its own pair.
- **Status and quit go over its own port** (`STATUS`, `QUIT token`), and not
  through a signals port: the marshaller's port is the one every client
  already knows, and the point is to need no second one. The control thread
  waits at most 200 ms at a time, so it answers while pairs are busy. Each pump
  keeps its counts in a virtual file of its own, which threads may write
  together, and STATUS adds them up.
- **QUIT** stops taking clients, unlistens, closes the connections whose first
  line has not come, and waits up to `--drain-ms` for the open pairs, each of
  which ends when either of its sides does. A pump still running then is left
  to the program's end: closing its connections from the control thread would
  race with the pump that holds them.
- `marshal.patlang [--port N] [--drain-ms MS]`, which exits 1 when the port is
  taken. For a program that runs one in a thread, `pm_start(port)` writes the
  token and returns at once, so services can register straight away, and
  `pm_loop(m, drain_ms)` serves.

## The library (`port_marshal.patlang`)

- `pm_register(name, port)`, `pm_unregister(name)` and `pm_list()`.
- `pm_connect(name)` gives `[conn, rest]`, where `rest` is any piped bytes that
  came in with `OK`. It gives `[-1, reason]` when there is no such name.
- `pm_serve_on(name)` listens on port 0, registers, and gives the port. It is
  for a service whose only address is its name.

## Tests (`packages/port_marshal/spec/`, gated as `pkg_port_marshal`)

These run the marshaller, an echo service and clients in one process, on
threads, with the marshaller on a port the test listens for from 0. The gates
run them interpreted, as they run every package's specs; the runner built with
v2.exe passes them too (42 checks, 3 s, checked by hand 2026-11-23).

- An echo service is registered on port 0, and a client connects by name and
  gets back bytes 0 to 255 and a 1 MB block exactly.
- A name that is not there gives `ERR`.
- Two clients on one service at once each get their own bytes.
- A backend's close reaches the client, and a client's close reaches the backend.
- A REGISTER with a wrong token is refused, and so is a name held by a live
  service.
- A service that has stopped is dropped at the next CONNECT.
- A client that connects and sends nothing does not hold up another client's
  CONNECT.
- `status` answers while a pair is moving data. After `quit`, the port is free
  and can be claimed again (this needs `tcp_unlisten`).

These need a Background run before each scenario: `lib/gherkin.patlang` ran a
Background's steps once, where they were written, and does it Gherkin's way now
(`gherkin_select_selftest.patlang` checks it).
- A runtime scenario in `values_and_memory` covers `tcp_wait_any` and
  `tcp_unlisten` on interp, Windows and Linux.

## Order (done 2026-11-23 up to the gates)

1. After gates run 6: write the `tcp_unlisten` and `tcp_wait_any` fixtures and
   scenarios (RED), implement them on both systems, rebuild the interpreter,
   and see them pass (GREEN).
2. `signal_release(port_id)` in `lib/signals.patlang` (unlisten, then remove the
   token), and the ray tracer's status server moved onto it.
3. The package: features first, then the library and daemon. Then its gates
   unit and a line in `packages/README.md`.
4. Gates with `--cap 12`, then commit.
