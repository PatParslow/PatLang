"""Test oracle for the trust package's Gherkin runner (tests only).

Python's `cryptography` (Ed25519) makes the test keys and signatures, and
checks signatures for the features' verifier closure. Keys are made from
fixed seeds: a name's seed is SHA-256("patlang-trust-test " + name), so
every run makes the same keys. Each command prints one line.

  pub NAME                     the name's Ed25519 public key, lowercase hex
  sign NAME HASHHEX            the name's signature over the bytes of HASHHEX
  verify ALG PUBHEX MSGHEX SIGHEX
                               "true" when ALG is ed25519 and the signature
                               holds, else "false"
  sha256 PATH                  SHA-256 of a file's bytes, lowercase hex
  mkdir PATH                   makes a directory (and its parents); "ok"
  clean PATH                   removes a directory under packages/trust/build
                               and everything in it; "ok"
"""
import hashlib
import os
import shutil
import sys

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat


def private_key(name):
    seed = hashlib.sha256(("patlang-trust-test " + name).encode("ascii")).digest()
    return Ed25519PrivateKey.from_private_bytes(seed)


def verify(alg, pub_hex, msg_hex, sig_hex):
    if alg != "ed25519":
        return False
    try:
        pub = Ed25519PublicKey.from_public_bytes(bytes.fromhex(pub_hex))
        pub.verify(bytes.fromhex(sig_hex), bytes.fromhex(msg_hex))
        return True
    except (ValueError, InvalidSignature):
        return False


def main(args):
    cmd = args[0]
    if cmd == "pub":
        raw = private_key(args[1]).public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)
        print(raw.hex())
    elif cmd == "sign":
        print(private_key(args[1]).sign(bytes.fromhex(args[2])).hex())
    elif cmd == "verify":
        print("true" if verify(args[1], args[2], args[3], args[4]) else "false")
    elif cmd == "sha256":
        with open(args[1], "rb") as f:
            print(hashlib.sha256(f.read()).hexdigest())
    elif cmd == "mkdir":
        os.makedirs(args[1], exist_ok=True)
        print("ok")
    elif cmd == "clean":
        root = os.path.realpath(os.path.join("packages", "trust", "build"))
        target = os.path.realpath(args[1])
        if os.path.commonpath([root, target]) != root or target == root:
            print("refused", args[1])
            return 2
        shutil.rmtree(target, ignore_errors=True)
        print("ok")
    else:
        print("unknown command", cmd)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
