"""The watched job of showcase/p9_watching_a_job.patlang, in Python.

If the monitor were only ever a thread of the same program, Python would let
it read the job's variables, and no sockets would be needed. The PatLang job
can be watched by another program with no change, so the sketch gives Python
the same: a TCP server on a port the system picks, a registry file naming the
job and its port, and a queue between the server's thread and the job, which
answers between slices of 20 ms. PatLang has these as signal_claim,
signal_announce, budgeted and when handlers; here they are built from
socketserver, threading, queue and json.

Prints the same lines as the PatLang program.
"""
import json
import os
import queue
import socket
import socketserver
import tempfile
import threading
import time

REGISTRY = os.path.join(tempfile.gettempdir(), "showcase_p9_registry.json")
requests = queue.Queue()


class Handler(socketserver.StreamRequestHandler):
    """One request a line; the job answers it between slices."""

    def handle(self):
        name = self.rfile.readline().decode().strip()
        reply = queue.Queue(1)
        requests.put((name, reply))
        self.wfile.write((reply.get() + "\n").encode())


def announce(name, port, actions):
    with open(REGISTRY, "w") as f:
        json.dump({name: {"port": port, "actions": actions}}, f)


def discover(name):
    with open(REGISTRY) as f:
        entry = json.load(f)[name]
    return entry["port"], entry["actions"]


def query(port, name):
    with socket.create_connection(("127.0.0.1", port)) as s:
        s.sendall((name + "\n").encode())
        return s.makefile().readline().strip()


def is_prime(k):
    if k < 2:
        return False
    d = 2
    while d * d <= k:
        if k % d == 0:
            return False
        d += 1
    return True


class Job:
    next_k, primes, running = 2, 0, True


job = Job()
server = socketserver.ThreadingTCPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
announce("prime_counter", server.server_address[1], [["status", "how many numbers it has checked, and how many primes it found"], ["quit", "stop after the current slice"]])

heard = []


def monitor():
    port, actions = discover("prime_counter")
    time.sleep(0.2)
    first = query(port, "status")
    time.sleep(0.2)
    second = query(port, "status")
    last = query(port, "quit")
    heard.extend([actions, first, second, last])


watcher = threading.Thread(target=monitor)
watcher.start()

while job.running:
    # one slice of 20 ms of work, then the requests that came in meanwhile
    end = time.monotonic() + 0.02
    while job.running and time.monotonic() < end:
        if is_prime(job.next_k):
            job.primes += 1
        job.next_k += 1
    while not requests.empty():
        name, reply = requests.get()
        if name == "status":
            reply.put(f"checked {job.next_k - 2}, found {job.primes}")
        elif name == "quit":
            job.running = False
            reply.put(f"stopping at {job.primes} primes")

watcher.join()
server.shutdown()
os.remove(REGISTRY)


def b(x):
    return "true" if x else "false"


def checked_of(reply):
    return int(reply[len("checked "):].split(",")[0])


print("the monitor found the job by name, offering: " + ", ".join(a[0] for a in heard[0]))
print("first status has the form 'checked N, found M': " + b(heard[1].startswith("checked ")))
print("the second shows more work than the first: " + b(checked_of(heard[2]) > checked_of(heard[1])))
print("quit was answered: " + b(heard[3].startswith("stopping at ")))
print("the job counted some primes before it stopped: " + b(job.primes > 0))
