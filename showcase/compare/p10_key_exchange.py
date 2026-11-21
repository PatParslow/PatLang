"""The X25519 exchange of showcase/p10_key_exchange.patlang, in Python.

Python's arbitrary-size integers make RFC 7748's algorithm short to write:
the Montgomery ladder below follows section 5 line for line. What Python
cannot say is how long it takes. Its integers take time that depends on their
values (a multiplication of small numbers is quicker than one of large ones),
the ladder's conditional swap is written with arithmetic only as a matter of
care, and no tool in the standard distribution checks any of it. Code that
needs that guarantee calls a library written in C or assembly for the purpose
(the cryptography package wraps OpenSSL's X25519). PatLang's compiler checks
the PatLang code itself with --constant-time.

Prints the same lines as the PatLang program.
"""
P = 2**255 - 19
A24 = 121665


def decode_scalar(k):
    b = bytearray(k)
    b[0] &= 248
    b[31] &= 127
    b[31] |= 64
    return int.from_bytes(b, "little")


def decode_u(u):
    b = bytearray(u)
    b[31] &= 127
    return int.from_bytes(b, "little")


def cswap(swap, x2, x3):
    """Swaps when swap is 1, by arithmetic, as RFC 7748 writes it."""
    mask = -swap
    dummy = mask & (x2 ^ x3)
    return x2 ^ dummy, x3 ^ dummy


def x25519(k, u):
    k, x1 = decode_scalar(k), decode_u(u)
    x2, z2, x3, z3, swap = 1, 0, x1, 1, 0
    for t in reversed(range(255)):
        k_t = (k >> t) & 1
        swap ^= k_t
        x2, x3 = cswap(swap, x2, x3)
        z2, z3 = cswap(swap, z2, z3)
        swap = k_t
        a, b = (x2 + z2) % P, (x2 - z2) % P
        aa, bb = a * a % P, b * b % P
        e = (aa - bb) % P
        c, d = (x3 + z3) % P, (x3 - z3) % P
        da, cb = d * a % P, c * b % P
        x3, z3 = (da + cb) ** 2 % P, x1 * (da - cb) ** 2 % P
        x2, z2 = aa * bb % P, e * (aa + A24 * e) % P
    x2, x3 = cswap(swap, x2, x3)
    z2, z3 = cswap(swap, z2, z3)
    return (x2 * pow(z2, P - 2, P) % P).to_bytes(32, "little")


nine = bytes.fromhex("09" + "00" * 31)
alice_private = bytes.fromhex("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a")
bob_private = bytes.fromhex("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb")

print("== public keys, sent in the open ==")
alice_public = x25519(alice_private, nine)
bob_public = x25519(bob_private, nine)
print("alice: " + alice_public.hex())
print("bob:   " + bob_public.hex())

print("== each combines the other's public key with their own private one ==")
alice_shared = x25519(alice_private, bob_public)
bob_shared = x25519(bob_private, alice_public)
print("alice's secret: " + alice_shared.hex())
print("bob's secret:   " + bob_shared.hex())
print("they agree: " + ("true" if alice_shared == bob_shared else "false"))
print("as RFC 7748 gives it: " + ("true" if alice_shared.hex() == "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742" else "false"))
