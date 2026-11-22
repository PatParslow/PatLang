"""The reference for packages/tls/spec/tls.feature: Python's cryptography.

    py -3 -I oracle.py seal KEY NONCE AAD PLAINTEXT   (all hex) -> sealed hex
    py -3 -I oracle.py poly1305 KEY MSG                (hex)     -> tag hex
    py -3 -I oracle.py chacha20 KEY COUNTER NONCE DATA            -> hex
"""
import sys

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives.poly1305 import Poly1305


def h(x):
    return bytes.fromhex(x)


def main(argv):
    op = argv[1]
    if op == "seal":
        print(ChaCha20Poly1305(h(argv[2])).encrypt(h(argv[3]), h(argv[5]), h(argv[4])).hex())
    elif op == "poly1305":
        print(Poly1305.generate_tag(h(argv[2]), h(argv[3])).hex())
    elif op == "chacha20":
        nonce = int(argv[3]).to_bytes(4, "little") + h(argv[4])
        print(Cipher(algorithms.ChaCha20(h(argv[2]), nonce), None).encryptor().update(h(argv[5])).hex())
    else:
        raise SystemExit("unknown operation " + op)


main(sys.argv)
