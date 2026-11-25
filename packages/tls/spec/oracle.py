"""The reference for packages/tls/spec/*.feature: Python's hashlib and cryptography.

    py -3 -I oracle.py seal KEY NONCE AAD PLAINTEXT   (all hex) -> sealed hex
    py -3 -I oracle.py poly1305 KEY MSG                (hex)     -> tag hex
    py -3 -I oracle.py chacha20 KEY COUNTER NONCE DATA            -> hex
    py -3 -I oracle.py aesgcm KEY NONCE AAD PLAINTEXT (all hex) -> sealed hex
    py -3 -I oracle.py rsasign pkcs1|pss HASH BITS MSG  -> n e signature (hex), a fresh key
    py -3 -I oracle.py ecsign p256|p384 MSG            -> x y r s (hex), a fresh key
    py -3 -I oracle.py ecpub p256|p384 D               -> x y (hex) of the private key D
    py -3 -I oracle.py p256dh D PEER                   -> the shared x (hex), private key D, peer share PEER
    py -3 -I oracle.py hash ALG DATA                   (sha256 or sha384) -> digest hex
    py -3 -I oracle.py hkdf ALG IKM SALT INFO LENGTH                -> output key hex
    py -3 -I oracle.py label ALG SECRET LABEL CONTEXT LENGTH        -> HKDF-Expand-Label hex
      (RFC 8446 section 7.1: HKDF-Expand of the HkdfLabel struct, built here;
      LABEL is text without "tls13 ", the rest hex)

A hex argument "-" stands for no bytes.
"""
import calendar
import hashlib
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms
from cryptography.hazmat.primitives.ciphers.aead import AESGCM, ChaCha20Poly1305
from cryptography.hazmat.primitives.kdf.hkdf import HKDF, HKDFExpand
from cryptography.hazmat.primitives.poly1305 import Poly1305


def h(x):
    return b"" if x == "-" else bytes.fromhex(x)


def alg(name):
    return {"sha256": hashes.SHA256(), "sha384": hashes.SHA384(), "sha512": hashes.SHA512()}[name]


def main(argv):
    op = argv[1]
    if op == "seal":
        print(ChaCha20Poly1305(h(argv[2])).encrypt(h(argv[3]), h(argv[5]), h(argv[4])).hex())
    elif op == "poly1305":
        print(Poly1305.generate_tag(h(argv[2]), h(argv[3])).hex())
    elif op == "chacha20":
        nonce = int(argv[3]).to_bytes(4, "little") + h(argv[4])
        print(Cipher(algorithms.ChaCha20(h(argv[2]), nonce), None).encryptor().update(h(argv[5])).hex())
    elif op == "rsasign":
        # a fresh key; prints n, e and the signature (hex), for pkcs1 or pss
        key = rsa.generate_private_key(public_exponent=65537, key_size=int(argv[4]))
        if argv[2] == "pss":
            pad = padding.PSS(mgf=padding.MGF1(alg(argv[3])), salt_length=alg(argv[3]).digest_size)
        else:
            pad = padding.PKCS1v15()
        sig = key.sign(h(argv[5]), pad, alg(argv[3]))
        pn = key.public_key().public_numbers()
        print(format(pn.n, "x"), format(pn.e, "x"), sig.hex())
    elif op == "ecsign":
        # a fresh key on p256 (SHA-256) or p384 (SHA-384); prints x, y, r, s (hex)
        curve, hname = {"p256": (ec.SECP256R1(), "sha256"), "p384": (ec.SECP384R1(), "sha384")}[argv[2]]
        key = ec.generate_private_key(curve)
        r, s = decode_dss_signature(key.sign(h(argv[3]), ec.ECDSA(alg(hname))))
        pn = key.public_key().public_numbers()
        print(format(pn.x, "x"), format(pn.y, "x"), format(r, "x"), format(s, "x"))
    elif op == "ecpub":
        # the public key of the private key d (hex) on p256 or p384: x, y (hex)
        curve = {"p256": ec.SECP256R1(), "p384": ec.SECP384R1()}[argv[2]]
        pn = ec.derive_private_key(int(argv[3], 16), curve).public_key().public_numbers()
        print(format(pn.x, "x"), format(pn.y, "x"))
    elif op == "p256dh":
        # the shared x (hex) of private key D with the peer's share (04 || x || y, hex)
        key = ec.derive_private_key(int(argv[2], 16), ec.SECP256R1())
        peer = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), h(argv[3]))
        print(key.exchange(ec.ECDH(), peer).hex())
    elif op == "x509":
        # a certificate file's subject CN|issuer CN|serial|not before|not
        # after (Unix seconds)|DNS names (comma)|CA (true/false)
        with open(argv[2], "rb") as f:
            cert = x509.load_der_x509_certificate(f.read())
        cn = lambda n: n.get_attributes_for_oid(x509.NameOID.COMMON_NAME)[0].value
        try:
            sans = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName)
        except x509.ExtensionNotFound:
            sans = []
        ca = cert.extensions.get_extension_for_class(x509.BasicConstraints).value.ca
        print("|".join([cn(cert.subject), cn(cert.issuer), str(cert.serial_number),
                        str(calendar.timegm(cert.not_valid_before.utctimetuple())), str(calendar.timegm(cert.not_valid_after.utctimetuple())),
                        ",".join(sans), str(ca).lower()]))
    elif op == "aesgcm":
        print(AESGCM(h(argv[2])).encrypt(h(argv[3]), h(argv[5]), h(argv[4]) or None).hex())
    elif op == "hash":
        print(hashlib.new(argv[2], h(argv[3])).hexdigest())
    elif op == "hkdf":
        salt = h(argv[4]) or None
        print(HKDF(alg(argv[2]), int(argv[6]), salt, h(argv[5])).derive(h(argv[3])).hex())
    elif op == "label":
        full = b"tls13 " + argv[4].encode("ascii")
        context = h(argv[5])
        length = int(argv[6])
        info = length.to_bytes(2, "big") + bytes([len(full)]) + full + bytes([len(context)]) + context
        print(HKDFExpand(alg(argv[2]), length, info).derive(h(argv[3])).hex())
    else:
        raise SystemExit("unknown operation " + op)


main(sys.argv)
