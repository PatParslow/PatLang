"""A DNS server for the rt_tcp_remote fixture, on 127.0.0.1 only.

It answers A queries for three names and refuses the rest:
  two.test     two A records, 192.0.2.7 and 192.0.2.8
  alias.test   a CNAME to two.test (with a compressed name), then two.test's
               first A record
  anything else  NXDOMAIN
It writes the UDP port it holds to the file named by its first argument, then
answers until it has answered as many queries as its second argument says, or
until no query has come for 60 seconds.
"""
import socket
import struct
import sys


def name_end(msg: bytes, at: int) -> int:
    while msg[at] != 0:
        at += 1 + msg[at]
    return at + 1


def qname(msg: bytes, at: int) -> str:
    parts = []
    while msg[at] != 0:
        n = msg[at]
        parts.append(msg[at + 1:at + 1 + n].decode("ascii"))
        at += 1 + n
    return ".".join(parts)


def a_record(owner: bytes, addr: str) -> bytes:
    return owner + struct.pack(">HHIH", 1, 1, 60, 4) + socket.inet_aton(addr)


def answer(query: bytes) -> bytes:
    qid = query[:2]
    end = name_end(query, 12) + 4
    question = query[12:end]
    name = qname(query, 12).lower()
    to_question = b"\xc0\x0c"  # a pointer to the question's name at 12
    if name == "two.test":
        records = [a_record(to_question, "192.0.2.7"), a_record(to_question, "192.0.2.8")]
        rcode = 0
    elif name == "alias.test":
        target = b"\x03two\x04test\x00"
        cname = to_question + struct.pack(">HHIH", 5, 1, 60, len(target)) + target
        # the CNAME's target sits at 12 + len(question) + 12 (the cname record's
        # name, type, class, ttl and length): its A record points back at it
        target_at = 12 + len(question) + 2 + 10
        records = [cname, a_record(struct.pack(">H", 0xC000 | target_at), "192.0.2.7")]
        rcode = 0
    else:
        records = []
        rcode = 3
    flags = 0x8180 | rcode
    header = qid + struct.pack(">HHHHH", flags, 1, len(records), 0, 0)
    return header + question + b"".join(records)


def main() -> None:
    port_file, limit = sys.argv[1], int(sys.argv[2])
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("127.0.0.1", 0))
    sock.settimeout(60)
    with open(port_file + ".tmp", "w") as f:
        f.write(str(sock.getsockname()[1]))
    import os
    os.replace(port_file + ".tmp", port_file)
    answered = 0
    while answered < limit:
        try:
            query, peer = sock.recvfrom(4096)
        except socket.timeout:
            break
        sock.sendto(answer(query), peer)
        answered += 1


if __name__ == "__main__":
    main()
