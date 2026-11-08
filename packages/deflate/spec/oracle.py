"""Test oracle for the deflate package's Gherkin runner (tests only).

Python's zlib is the reference the PatLang code is checked against. Each
command reads and writes files and prints one line the runner checks.

  gen KIND N OUT               deterministic test data
  zcompress IN OUT LEVEL STRAT zlib stream; STRAT is default or fixed
  rawcompress IN OUT LEVEL     raw DEFLATE (no zlib wrapper)
  zdecompress IN OUT           prints "ok LEN" or "error MESSAGE"
  rawdecompress IN OUT         same, for raw DEFLATE
  crc32 IN / adler32 IN        prints the checksum in decimal
  same A B                     prints "same" or "differ at I"
"""
import random
import sys
import zlib

WORDS = (b"the quick brown fox jumps over lazy dog package manifest version "
         b"deflate inflate huffman block stored fixed dynamic window match "
         b"literal length distance PatLang compiler runtime list vec ").split()


def gen(kind, n):
    rng = random.Random(1951)
    if kind == "random":
        return rng.randbytes(n)
    if kind == "repetitive":
        unit = b"PatLang packages "
        return (unit * (n // len(unit) + 1))[:n]
    if kind == "zeros":
        return bytes(n)
    if kind == "one":
        return bytes([rng.randrange(256) for _ in range(n)])
    if kind == "text":
        out = bytearray()
        while len(out) < n:
            out += rng.choice(WORDS)
            out += b"\n" if rng.random() < 0.1 else b" "
        return bytes(out[:n])
    if kind == "mixed":
        out = bytearray()
        while len(out) < n:
            k = rng.randrange(4)
            size = rng.randrange(1, 5000)
            if k == 0:
                out += rng.randbytes(size)
            elif k == 1:
                out += bytes([rng.randrange(256)]) * size
            else:
                out += gen("text", size)
        return bytes(out[:n])
    raise SystemExit("unknown kind " + kind)


def read(path):
    with open(path, "rb") as f:
        return f.read()


def write(path, data):
    with open(path, "wb") as f:
        f.write(data)


def main(argv):
    cmd = argv[0]
    if cmd == "gen":
        write(argv[3], gen(argv[1], int(argv[2])))
        print("ok")
    elif cmd == "zcompress":
        level = int(argv[3])
        strategy = zlib.Z_FIXED if argv[4] == "fixed" else zlib.Z_DEFAULT_STRATEGY
        c = zlib.compressobj(level, zlib.DEFLATED, 15, 9, strategy)
        write(argv[2], c.compress(read(argv[1])) + c.flush())
        print("ok")
    elif cmd == "rawcompress":
        c = zlib.compressobj(int(argv[3]), zlib.DEFLATED, -15)
        write(argv[2], c.compress(read(argv[1])) + c.flush())
        print("ok")
    elif cmd in ("zdecompress", "rawdecompress"):
        wbits = 15 if cmd == "zdecompress" else -15
        try:
            d = zlib.decompressobj(wbits)
            out = d.decompress(read(argv[1])) + d.flush()
            if not d.eof:
                raise zlib.error("stream not finished")
            if d.unused_data:
                raise zlib.error("%d bytes after the stream" % len(d.unused_data))
        except zlib.error as e:
            print("error " + str(e))
            return
        write(argv[2], out)
        print("ok %d" % len(out))
    elif cmd == "crc32":
        print(zlib.crc32(read(argv[1])))
    elif cmd == "adler32":
        print(zlib.adler32(read(argv[1])))
    elif cmd == "same":
        a, b = read(argv[1]), read(argv[2])
        if a == b:
            print("same")
        else:
            i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), min(len(a), len(b)))
            print("differ at %d (%d vs %d bytes)" % (i, len(a), len(b)))
    else:
        raise SystemExit("unknown command " + cmd)


if __name__ == "__main__":
    main(sys.argv[1:])
