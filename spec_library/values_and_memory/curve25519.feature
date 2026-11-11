@language
Feature: X25519 and Ed25519 written in PatLang on modints (spec 1.14)

  Scenario: SHA-512 written on words modulo 2^64 gives the FIPS 180-4 digests
    Given a SHA-512 written in PatLang on modints modulo 2^64
    When a program prints the digests of "abc", the empty message and the 896-bit message
    Then each is the digest FIPS 180-4 gives for it

  Scenario: X25519 gives the outputs of RFC 7748
    Given X25519 written in PatLang on modints modulo 2^255 - 19
    When a program prints its outputs for the vectors of RFC 7748 sections 5.2 and 6.1, after 1 and 1000 iterations
    Then each is the output RFC 7748 gives

  Scenario: X25519 agrees with every Wycheproof case
    Given X25519 written in PatLang on modints modulo 2^255 - 19
    When it computes the shared secret of every case in Wycheproof's x25519_test.json
    Then all 518 shared secrets agree with the cases

  Scenario: Ed25519 gives the keys and signatures of RFC 8032
    Given Ed25519 written in PatLang on modints modulo 2^255 - 19 and modulo the group order
    When a program makes the key and signature of each vector of RFC 8032 section 7.1, and verifies each signature for its message and for an altered one
    Then each key and signature is the one RFC 8032 gives, each verifies, and none verifies for the altered message

  Scenario: Ed25519 verification agrees with every Wycheproof case
    Given Ed25519 written in PatLang on modints modulo 2^255 - 19 and modulo the group order
    When it verifies every case in Wycheproof's ed25519_test.json
    Then every valid signature is accepted and every invalid one rejected
