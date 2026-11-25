"""Makes the test PKI of packages/tls/spec/x509.feature, into spec/data/certs/:

    py -3 -I packages/tls/spec/make_certs.py

Run once; its output is committed, so the tests read the same certificates
every time (they are made again only when this script changes). Every key
here is a test key, worth nothing outside these tests.

    root.der            the test root: P-384, self-signed with ECDSA-SHA384, CA
    inter.der           the intermediate: RSA-2048, signed by the root, CA, path length 0
    leaf_ec.der         localhost and *.test.example, P-256 key, signed by the
                        intermediate with RSA PKCS#1 v1.5 SHA-256
    leaf_rsa.der        localhost, RSA-2048 key, the same issuer
    expired.der         localhost, valid 2020 to 2021
    wrong_name.der      other.example only
    not_ca.der          an intermediate that is not a CA (basicConstraints CA false)
    leaf_under_not_ca.der   localhost, signed by not_ca
    no_signing.der      localhost, keyUsage keyCertSign only (no digitalSignature)
    unknown_critical.der    localhost, with a critical extension of an unknown OID
    *.pem               the same, PEM; leaf_ec.key and leaf_rsa.key, their keys (PEM),
                        and other.key, the key the refused leaves share
    chain_ec.pem        leaf_ec then inter, for openssl s_server -cert_chain
"""
import datetime
import os
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "certs")
UTC = datetime.timezone.utc
NOW_FROM = datetime.datetime(2026, 1, 1, tzinfo=UTC)
NOW_TO = datetime.datetime(2036, 1, 1, tzinfo=UTC)


def name(cn):
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, cn), x509.NameAttribute(NameOID.ORGANIZATION_NAME, "PatLang tests")])


def key_usage(digital, cert_sign):
    return x509.KeyUsage(digital_signature=digital, content_commitment=False, key_encipherment=False,
                         data_encipherment=False, key_agreement=False, key_cert_sign=cert_sign,
                         crl_sign=cert_sign, encipher_only=False, decipher_only=False)


def make(subject_cn, subject_key, issuer_cn, issuer_key, sig_hash, ca, path_len=None, sans=None,
         digital=True, cert_sign=False, start=NOW_FROM, end=NOW_TO, extra=None, serial=1):
    b = x509.CertificateBuilder().subject_name(name(subject_cn)).issuer_name(name(issuer_cn))
    b = b.public_key(subject_key.public_key()).serial_number(serial)
    b = b.not_valid_before(start).not_valid_after(end)
    b = b.add_extension(x509.BasicConstraints(ca=ca, path_length=path_len), critical=True)
    b = b.add_extension(key_usage(digital, cert_sign), critical=True)
    if sans is not None:
        b = b.add_extension(x509.SubjectAlternativeName([x509.DNSName(s) for s in sans]), critical=False)
        b = b.add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
    if extra is not None:
        b = b.add_extension(extra, critical=True)
    return b.sign(issuer_key, sig_hash)


def write(cert, base):
    with open(os.path.join(OUT, base + ".der"), "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.DER))
    with open(os.path.join(OUT, base + ".pem"), "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))


def write_key(key, base):
    with open(os.path.join(OUT, base + ".key"), "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                  serialization.NoEncryption()))


def main():
    os.makedirs(OUT, exist_ok=True)
    root_key = ec.generate_private_key(ec.SECP384R1())
    inter_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf_ec_key = ec.generate_private_key(ec.SECP256R1())
    leaf_rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    other_key = ec.generate_private_key(ec.SECP256R1())
    not_ca_key = ec.generate_private_key(ec.SECP256R1())

    root = make("PatLang Test Root", root_key, "PatLang Test Root", root_key, hashes.SHA384(), True,
                digital=False, cert_sign=True, serial=1)
    inter = make("PatLang Test Intermediate", inter_key, "PatLang Test Root", root_key, hashes.SHA384(), True,
                 path_len=0, digital=False, cert_sign=True, serial=2)
    sha = hashes.SHA256()
    issued = "PatLang Test Intermediate"
    certs = {
        "root": root,
        "inter": inter,
        "leaf_ec": make("localhost", leaf_ec_key, issued, inter_key, sha, False, sans=["localhost", "*.test.example"], serial=10),
        "leaf_rsa": make("localhost", leaf_rsa_key, issued, inter_key, sha, False, sans=["localhost"], serial=11),
        "expired": make("localhost", other_key, issued, inter_key, sha, False, sans=["localhost"],
                        start=datetime.datetime(2020, 1, 1, tzinfo=UTC), end=datetime.datetime(2021, 1, 1, tzinfo=UTC), serial=12),
        "wrong_name": make("other.example", other_key, issued, inter_key, sha, False, sans=["other.example"], serial=13),
        "not_ca": make("PatLang Test Not A CA", not_ca_key, issued, inter_key, sha, False, serial=14),
        "leaf_under_not_ca": make("localhost", other_key, "PatLang Test Not A CA", not_ca_key, sha, False, sans=["localhost"], serial=15),
        "no_signing": make("localhost", other_key, issued, inter_key, sha, False, sans=["localhost"], digital=False, cert_sign=True, serial=16),
        "unknown_critical": make("localhost", other_key, issued, inter_key, sha, False, sans=["localhost"],
                                 extra=x509.UnrecognizedExtension(x509.ObjectIdentifier("1.3.6.1.4.1.55555.1"), b"\x05\x00"), serial=17),
    }
    for base, cert in certs.items():
        write(cert, base)
    write_key(leaf_ec_key, "leaf_ec")
    write_key(leaf_rsa_key, "leaf_rsa")
    # expired, wrong_name, leaf_under_not_ca, no_signing and unknown_critical
    # share this key, so a test server can present any of them
    write_key(other_key, "other")
    with open(os.path.join(OUT, "chain_ec.pem"), "wb") as f:
        f.write(inter.public_bytes(serialization.Encoding.PEM))
    print("made", len(certs), "certificates in", OUT)


if __name__ == "__main__":
    sys.exit(main())
