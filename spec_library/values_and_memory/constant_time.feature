@language
Feature: the constant-time check (spec 1.14 and 2.7)

  Scenario: modint arithmetic, inverses, powers and word operations depend on the modulus alone
    Given a program that adds, subtracts, multiplies, divides, negates and raises modints to powers modulo 2^255 - 19 and modulo 2^32 * 3, and rotates, shifts and combines words modulo 2^32, comparing them only in asserts
    When the constant-time check reads it
    Then it reports nothing and exits 0

  Scenario: a branch on whether two modints are equal is reported
    Given a program with if a == b, for modints a and b
    When the constant-time check reads it
    Then it reports a branch deciding on a secret, and exits 1

  Scenario: arithmetic on, and an address from, a word of a residue are reported
    Given a program reading a word of a modint's residue from its block, adding 1 to it, and reading memory at it
    When the constant-time check reads it
    Then it reports arithmetic on a secret integer and an address computed from a secret, and exits 1

  Scenario: a residue leaving the class is reported
    Given a program printing mod_value of a modint
    When the constant-time check reads it
    Then it reports the residue leaving the class, and exits 1

  Scenario: a residue the program declares public with mod_reveal is listed, not reported
    Given a tag check whose verdict is made public with mod_reveal
    When the constant-time check reads it
    Then it lists the reveal as declared by tag_matches, reports nothing, and exits 0

  Scenario: ChaCha20-Poly1305 seals and opens with no value-dependent step but its declared verdict
    Given AEAD_CHACHA20_POLY1305 from the tls package sealing and opening a text under a secret key
    When the constant-time check reads it
    Then it lists the tag check's verdict as declared by chacha20_poly1305_check, reports nothing, and exits 0

  Scenario: X25519, Ed25519 key making and Ed25519 signing have no value-dependent step
    Given a program that agrees an X25519 secret, makes an Ed25519 key and signs a message, all written in PatLang on modints
    When the constant-time check reads it
    Then it reports nothing in them and exits 0

  Scenario: a stream cipher's round on 32-bit modints has no value-dependent step, and a branch on one of their bits is reported
    Given ChaCha20's quarter round on modints modulo 2^32, and a program with an if on such a modint's low bit
    When the constant-time check reads each
    Then it reports nothing in the round and exits 0, and reports the branch and exits 1
