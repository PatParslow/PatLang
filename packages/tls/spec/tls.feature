Feature: tls package: ChaCha20, Poly1305 and AEAD_CHACHA20_POLY1305 (RFC 8439)
  The known answers are RFC 8439's sections 2.4.2, 2.5.2 and 2.8.2. Python's
  cryptography (spec/oracle.py) is the reference for random keys, nonces and
  lengths, the block edges among them.

  Scenario: ChaCha20 encrypts RFC 8439 section 2.4.2's sunscreen text
    Given the key "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    And the nonce "000000000000004a00000000"
    And the text "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    Then ChaCha20 from block 1 gives "6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab77937365af90bbf74a35be6b40b8eedf2785e42874d"

  Scenario: Poly1305 of RFC 8439 section 2.5.2's message
    Given the key "85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b"
    And the text "Cryptographic Forum Research Group"
    Then its Poly1305 tag is "a8061dc1305136c6c22b8baf0c0127a9"

  Scenario: AEAD_CHACHA20_POLY1305 seals RFC 8439 section 2.8.2's text
    Given the key "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"
    And the nonce "070000004041424344454647"
    And the additional data "50515253c0c1c2c3c4c5c6c7"
    And the text "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    Then sealing it gives "d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b61161ae10b594f09e26a7e902ecbd0600691"
    And opening that gives the text back
    And opening it with any one byte changed is refused

  Scenario: ChaCha20, Poly1305 and the AEAD agree with Python's cryptography at the block edges
    Given a random key, nonce and additional data
    Then for random texts of lengths 0, 1, 15, 16, 17, 63, 64, 65 and 200, ChaCha20, Poly1305 and sealing agree with Python's cryptography, and opening gives each text back
