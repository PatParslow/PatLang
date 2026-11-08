"""Test oracle for the sha256 package's Gherkin runner (tests only).

Python's hashlib and hmac are the reference the PatLang code is checked
against. Each command prints one line the runner checks.

  gen N OUT              N deterministic pseudo-random bytes into OUT; prints "ok N"
  sha256 IN              SHA-256 of a file's bytes, lowercase hex
  hmac KEYHEX DATAHEX    HMAC-SHA-256, lowercase hex
  utf8 CODES             SHA-256 of the UTF-8 encoding of the characters
                         whose code points are CODES (comma-separated decimal)
"""
import hashlib
import hmac
import random
import sys


def main(args):
    cmd = args[0]
    if cmd == "gen":
        n = int(args[1])
        data = random.Random(180_4).randbytes(n)
        with open(args[2], "wb") as f:
            f.write(data)
        print("ok", n)
    elif cmd == "sha256":
        with open(args[1], "rb") as f:
            print(hashlib.sha256(f.read()).hexdigest())
    elif cmd == "hmac":
        key = bytes.fromhex(args[1])
        data = bytes.fromhex(args[2])
        print(hmac.new(key, data, hashlib.sha256).hexdigest())
    elif cmd == "utf8":
        codes = [int(c) for c in args[1].split(",") if c]
        text = "".join(chr(c) for c in codes)
        print(hashlib.sha256(text.encode("utf-8")).hexdigest())
    else:
        print("unknown command", cmd)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
