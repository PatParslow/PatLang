Feature: tls package: AES-128 and AES-128-GCM on modints, with no table indexed by a secret
  TLS_AES_128_GCM_SHA256 is the suite every TLS 1.3 implementation must offer
  (RFC 8446 section 9.1). The S-box is computed, an inverse in GF(2^8) and
  the affine map, on eight bytes packed in a 64-bit modint at a time, so no
  step's time or address depends on a key or a text, and the GHASH multiply
  is a fixed sequence of shifts, masks and XORs. The known answers are
  FIPS-197's appendix C.1 and the GCM specification's test cases 1 to 4
  (McGrew and Viega); Python's cryptography (spec/oracle.py) is the reference
  for random keys, nonces and lengths.

  Scenario: AES-128 encrypts FIPS-197's example block
    Given the key "000102030405060708090a0b0c0d0e0f"
    Then AES-128 of the block "00112233445566778899aabbccddeeff" is "69c4e0d86a7b0430d8cdb78070b4c55a"

  Scenario: AES-128-GCM gives the GCM specification's test cases 1 and 2
    Given the key "00000000000000000000000000000000"
    And the nonce "000000000000000000000000"
    Then sealing nothing with no additional data under AES-128-GCM gives "58e2fccefa7e3061367f1d57a4e7455a"
    And sealing the text "00000000000000000000000000000000" with no additional data under AES-128-GCM gives "0388dace60b6a392f328c2b971b2fe78ab6e47d42cec13bdf53a67b21257bddf"

  Scenario: AES-128-GCM gives the GCM specification's test cases 3 and 4
    Given the key "feffe9928665731c6d6a8f9467308308"
    And the nonce "cafebabefacedbaddecaf888"
    Then sealing the text "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255" with no additional data under AES-128-GCM gives "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f59854d5c2af327cd64a62cf35abd2ba6fab4"
    And sealing the text "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39" with the additional data "feedfacedeadbeeffeedfacedeadbeefabaddad2" under AES-128-GCM gives "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e0915bc94fbc3221a5db94fae95ae7121a47"
    And opening that under AES-128-GCM gives the text back, and with any one byte changed is refused

  Scenario: AES-128-GCM agrees with Python's cryptography at the block edges
    Then for random keys, nonces and additional data, and texts of lengths 0, 1, 15, 16, 17, 31, 32, 33 and 100, AES-128-GCM sealing agrees with cryptography and opening gives each text back
