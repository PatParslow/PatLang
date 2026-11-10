Feature: integers modulo n are a number class of their own

  Scenario: Arithmetic on modints stays modulo n, and an integer operand is reduced
    Given `let a = mod_make(3, 7)`
    When a is added to, multiplied by, divided by and raised to powers, alone and with integers
    Then each result is a modint modulo 7 with the residue the arithmetic of residues gives

  Scenario: A modint modulo 2^k is a k-bit word for the bit operators and rotations
    Given `let w = mod_make(200, 256)`
    When band, bor, bxor, bnot, shl, shr, rotl and rotr are applied to it
    Then each result is the 8-bit word the operation gives, still a modint modulo 256
