Feature: tls package: the TLS 1.3 client (RFC 8446)
  The client's handshake, record layer and application data, checked against
  RFC 8448 section 3, a whole 1-RTT handshake traced byte for byte
  (spec/data/rfc8448_simple.txt, made by spec/rfc8448_extract.py). The trace's
  ClientHello is NSS's, with extensions of its own choosing, so the client is
  given it and the trace's x25519 key; everything after is the client's own.
  The trace's certificate is self-signed for "rsa" and names no host, so
  these scenarios give the client a chain check that accepts it; the real
  check is x509.feature's, and the client never runs without one.

  Scenario: the client completes RFC 8448's handshake as traced
    Given the trace's ClientHello and the client's x25519 private key
    When the client reads the server's ServerHello and encrypted flight
    Then its handshake traffic secrets are the trace's, and it accepts the server's CertificateVerify and Finished
    And its Finished record is the trace's
    And its application traffic secrets are the trace's

  Scenario: application data and close_notify as traced
    Given the client has completed RFC 8448's handshake
    Then it reads past the server's NewSessionTicket to the server's 50 bytes
    And its own 50 bytes and its close_notify are the trace's records

  Scenario: a changed byte anywhere in the server's encrypted flight ends the handshake
    Given the trace's ClientHello and the client's x25519 private key
    Then the server's flight with its first, middle or last byte changed is refused, saying the record did not decrypt
    And the flight as traced is refused when the chain check refuses the certificate, saying why

  Scenario: the client's own ClientHello
    Then a ClientHello the client makes for "example.org" offers TLS 1.3 alone, ChaCha20-Poly1305 then AES-128-GCM, an x25519 key share, the name, RSA-PSS and ECDSA signatures, and ALPN http/1.1
