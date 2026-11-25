Feature: tls package: the signature checks a TLS 1.3 client makes
  A client checks the server's CertificateVerify and each certificate's
  signature: RSA PKCS#1 v1.5 with SHA-256, SHA-384 or SHA-512 (RFC 8017
  section 8.2), RSA-PSS with SHA-256 and a salt as long as the hash (RFC 8446
  section 4.2.3), and ECDSA on P-256 with SHA-256 and on P-384 with SHA-384
  (FIPS 186-4). Everything a check reads is public. Python's cryptography
  (spec/oracle.py) makes a fresh key and signature for each case, an
  implementation of its own; every check is also made to refuse.

  Scenario: the curves' constants are P-256's and P-384's
    Then for each curve, its generator is on it, n times it is the point at infinity, and a public key cryptography makes is the private key times the generator

  Scenario: RSA PKCS#1 v1.5 signatures with SHA-256, SHA-384 and SHA-512
    Then for each hash, a signature cryptography makes with a fresh 2048-bit key verifies, and is refused with the message changed, a byte of the signature changed, another key, or a byte too few

  Scenario: RSA-PSS signatures with SHA-256
    Then a PSS signature cryptography makes with a fresh 2048-bit key and a 32-byte salt verifies, and is refused with the message changed, a byte of the signature changed, or another key

  Scenario: ECDHE on P-256 agrees with cryptography's, by a ladder with no secret branch
    Then for random private keys, the key share is cryptography's public key for the same key, each side's shared secret is the other's, and a share not on the curve is refused

  Scenario: ECDSA signatures on P-256 with SHA-256 and P-384 with SHA-384
    Then for each curve, a signature cryptography makes with a fresh key verifies, and is refused with the message changed, r or s changed, another key, r or s zero, or r equal to the group's order
