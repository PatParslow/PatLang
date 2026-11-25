Feature: tls package: SHA-256 and SHA-384 on modints, HMAC, HKDF and TLS 1.3's labels
  The key schedule of TLS 1.3 (RFC 8446 section 7.1) is HKDF (RFC 5869) over
  the handshake's hash, SHA-256 or SHA-384, and every secret it makes passes
  through them; so they work on modints, as the AEADs do, and the
  constant-time check follows the secrets. The known answers are FIPS 180-4's
  examples, RFC 4231's HMAC test case 2, RFC 5869's test cases 1 and 3, and
  RFC 8448's first secrets. Python's hashlib and cryptography (spec/oracle.py)
  are the reference at the block edges and for HKDF-SHA384. A hex value "-"
  is no bytes.

  Scenario: SHA-256 on modints gives FIPS 180-4's digests
    Then SHA-256 of "abc" is "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    And SHA-256 of the empty text is "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    And SHA-256 of "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" is "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"

  Scenario: SHA-384 gives FIPS 180-4's digests
    Then SHA-384 of "abc" is "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7"
    And SHA-384 of the empty text is "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b"

  Scenario: both hashes agree with Python's hashlib at the block edges
    Then for random texts of lengths 0, 1, 55, 56, 63, 64, 65, 111, 112, 127, 128, 129 and 300, SHA-256 and SHA-384 agree with hashlib

  Scenario: HMAC with each hash gives RFC 4231's test case 2
    Then HMAC-SHA256 with the key "Jefe" of "what do ya want for nothing?" is "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
    And HMAC-SHA384 with the key "Jefe" of "what do ya want for nothing?" is "af45d2e376484031617f78d2b58a6b1b9c7ef464f5a01b47e42ec3736322445e8e2240ca5e69e2c78b3239ecfab21649"

  Scenario: HKDF-SHA256 gives RFC 5869's test case 1
    Given the input key "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b", the salt "000102030405060708090a0b0c", and the info "f0f1f2f3f4f5f6f7f8f9"
    Then HKDF-Extract with SHA-256 gives "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5"
    And HKDF-Expand of that to 42 bytes gives "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"

  Scenario: HKDF-SHA256 gives RFC 5869's test case 3, with no salt and no info
    Given the input key "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b", the salt "-", and the info "-"
    Then HKDF-Extract with SHA-256 gives "19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04"
    And HKDF-Expand of that to 42 bytes gives "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8"

  Scenario: HKDF-SHA384 agrees with Python's cryptography
    Then for random input keys, salts and infos, HKDF-SHA384 to 16, 48 and 100 bytes agrees with cryptography

  Scenario: the key schedule's first secrets are RFC 8448's
    Then the early secret, HKDF-Extract with SHA-256 of 32 zero bytes under no salt, is "33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a"
    And Derive-Secret of it with the label "derived" and no messages is "6f2615a108c702c5678f54fc9dbab69716c076189c48250cebeac3576c3611ba"
    And HKDF-Expand-Label agrees with cryptography's HKDF-Expand of the label's encoding, for each hash
