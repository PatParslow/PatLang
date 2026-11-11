@language
Feature: integers modulo n (spec 1.14)

  Scenario: a modint is an integer modulo n with the arithmetic of residues
    Given modints made with mod_make, with int and bigint moduli
    When a program prints their class, residues and moduli, their sums, differences, products, quotients, powers and negations, alone and with integers, and compares them, and remakes them modulo other moduli
    Then each prints what the rules of spec 1.14 give

  Scenario: a modint modulo 2^k is a k-bit word
    Given modints modulo 2^8, 2^32, 2^62 and 2^64
    When a program prints their band, bor, bxor, bnot, shl, shr, rotl and rotr
    Then each prints what the rules of spec 1.14 give for words

  Scenario: SHA-256 written on words modulo 2^32 gives the FIPS 180-4 digests
    Given a SHA-256 written in PatLang on modints modulo 2^32
    When a program prints the digests of "abc", the empty message, and the 448-bit and 896-bit messages
    Then each is the digest FIPS 180-4 gives

  Scenario: a modulus below 2 cannot be made
    Given mod_make(3, 1)
    When it is called
    Then the program stops at that call, naming mod_make's require clause

  Scenario: modints with different moduli do not mix
    Given mod_make(1, 7) + mod_make(1, 11)
    When it is evaluated
    Then the program stops at the sum, naming the modint class

  Scenario: a modint does not mix with a float
    Given mod_make(1, 7) + 1.5
    When it is evaluated
    Then the program stops at the sum with a float, naming the modint class

  Scenario: a modint has no order and no remainder
    Given mod_make(1, 7) < mod_make(2, 7), and mod_make(1, 7) % 2
    When each is evaluated
    Then each program stops, naming the modint class

  Scenario: dividing by a modint with no inverse
    Given mod_make(1, 8) / mod_make(2, 8)
    When it is evaluated
    Then the program stops at the quotient, naming the modint class

  Scenario: the bit operators need a modulus that is a power of two, and a count in range
    Given mod_make(1, 7) band mod_make(1, 7), and mod_make(1, 256) shl 9
    When each is evaluated
    Then each program stops at the bit operator, naming the modint class
