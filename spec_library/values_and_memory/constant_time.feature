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
