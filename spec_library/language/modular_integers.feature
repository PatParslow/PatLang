Feature: integers modulo n are a number class of their own

  Scenario: Arithmetic on modints stays modulo n, and an integer operand is reduced
    Given `let a = mod_make(3, 7)`
    When a is added to, multiplied by, divided by and raised to powers, alone and with integers
    Then each result is a modint modulo 7 with the residue the arithmetic of residues gives

  Scenario: A modint modulo 2^k is a k-bit word for the bit operators and rotations
    Given `let w = mod_make(200, 256)`
    When band, bor, bxor, bnot, shl, shr, rotl and rotr are applied to it
    Then each result is the 8-bit word the operation gives, still a modint modulo 256

  Scenario: A modint modulo 2^64 is a 64-bit word
    Given `let z = mod_make(0 - 1, 18446744073709551616)`
    When bnot, shl, shr, rotl and bxor are applied to it, with counts up to 64
    Then each result is the 64-bit word the operation gives

  Scenario: mod_make of a modint reduces its residue modulo the new modulus
    Given `let a = mod_make(300, 1000)`
    When mod_make(a, 256), mod_make(a, 7) and mod_make(a, 2^255 - 19) are made
    Then each is a's residue 300 reduced modulo the new modulus
