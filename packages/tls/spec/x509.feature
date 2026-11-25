Feature: tls package: X.509 certificates and chains (RFC 5280, RFC 6125)
  A TLS client reads the server's certificates (DER), builds a path from the
  leaf through the intermediates it was sent to a root it trusts, checks each
  link's signature, validity, CA flag, path length and key usage, refuses an
  unknown extension marked critical, and checks the leaf's DNS names against
  the host. Revocation is not checked. The certificates are the test PKI
  spec/make_certs.py made (spec/data/certs); Python's cryptography reads the
  same files as the reference.

  Scenario: each test certificate reads as cryptography reads it
    Then for each certificate, its subject and issuer names, serial number, validity, DNS names and CA flag are cryptography's

  Scenario: a leaf's chain to the test root checks for the names it carries
    Then leaf_ec through inter to root checks for "localhost" and "a.test.example" on 1 June 2026, and so does leaf_rsa for "localhost"

  Scenario: chains that must be refused are, each saying why
    Then on 1 June 2026, against the test root with inter and not_ca sent, each refusal starts with its reason (leaf, host, reason; "none" for no roots):
      """
      leaf_ec | localhost none | untrusted
      expired | localhost | expired
      wrong_name | localhost | name
      leaf_ec | a.b.test.example | name
      leaf_ec | test.example | name
      leaf_under_not_ca | localhost | not a CA
      no_signing | localhost | key usage
      unknown_critical | localhost | unknown critical extension
      """
    And leaf_ec checks for "localhost" in 2026 but is refused as expired in 2037

  Scenario: every root the system trusts reads as a certificate
    Then each of the system's roots (trust_roots) reads, and there are more than ten

  Scenario: malformed DER is refused, never stopping the program
    Then 300 copies of leaf_ec with a byte changed, a byte removed, or the end cut off each read as a certificate or are refused as malformed, and the program goes on
