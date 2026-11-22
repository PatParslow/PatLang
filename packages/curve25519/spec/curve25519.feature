Feature: curve25519 package: X25519 (RFC 7748) and Ed25519 (RFC 8032) on modints
  The vectors are RFC 7748's sections 5.2 and 6.1 and RFC 8032's section 7.1.
  Keys, scalars and signatures are lists of bytes, each a modint modulo 256.

  Scenario: X25519 of RFC 7748 section 5.2's first scalar and u-coordinate
    Given the scalar "a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4"
    And the u-coordinate "e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c"
    Then X25519 gives "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552"

  Scenario: X25519 of RFC 7748 section 5.2's second scalar and u-coordinate
    Given the scalar "4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d"
    And the u-coordinate "e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493"
    Then X25519 gives "95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957"

  Scenario: The Diffie-Hellman exchange of RFC 7748 section 6.1
    Given Alice's private key "77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a"
    And Bob's private key "5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb"
    Then Alice's public key is "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a"
    And Bob's public key is "de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f"
    And both compute the shared secret "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742"

  Scenario: Ed25519, RFC 8032 section 7.1 TEST 2
    Given the Ed25519 seed "4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"
    And the message "72"
    Then its public key is "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c"
    And its signature is "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
    And the signature verifies
    And the signature does not verify for the message with a byte added
