Feature: integers modulo n are a number class of their own

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: Arithmetic on modints stays modulo n, and an integer operand is reduced
    Given the program
      """
      let a = mod_make(3, 7)
      print(type_of(a))
      print(a + 5)
      print(a * mod_make(5, 7))
      print(a / 2)
      print(pow(a, 0 - 1))
      print(a == 10)
      print(type_of(1 - a))
      """
    When it runs interpreted and compiled
    Then both print
      """
      modint
      1 mod 7
      1 mod 7
      5 mod 7
      5 mod 7
      true
      modint
      """

  Scenario: A modint modulo 2^k is a k-bit word for the bit operators and rotations
    Given the program
      """
      let w = mod_make(200, 256)
      print([mod_value(w band 15), mod_value(w bor 7), mod_value(w bxor 255), mod_value(bnot w)])
      print([mod_value(w shl 1), mod_value(w shr 3), mod_value(rotl(w, 1)), mod_value(rotr(mod_make(201, 256), 1))])
      print(mod_modulus(w shl 1))
      """
    When it runs interpreted and compiled
    Then both print
      """
      [8, 207, 55, 55]
      [144, 25, 145, 228]
      256
      """

  Scenario: A modint modulo 2^64 is a 64-bit word
    Given the program
      """
      let z = mod_make(0 - 1, 18446744073709551616)
      print([mod_value(z), mod_value(bnot z), mod_value(z shl 64), mod_value(z shr 63)])
      print([mod_value(rotl(mod_make(1, 18446744073709551616), 63)), mod_value(rotr(mod_make(3, 18446744073709551616), 1)), mod_value(z bxor 1)])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [18446744073709551615, 0, 0, 1]
      [9223372036854775808, 9223372036854775809, 18446744073709551614]
      """

  Scenario: mod_make of a modint reduces its residue modulo the new modulus
    Given the program
      """
      let a = mod_make(300, 1000)
      let p = 57896044618658097711785492504343953926634992332820282019728792003956564819949
      print(mod_make(a, 256))
      print(mod_make(a, 7))
      print(mod_value(mod_make(a, p)))
      print(mod_modulus(mod_make(a, p)) == p)
      """
    When it runs interpreted and compiled
    Then both print
      """
      44 mod 256
      6 mod 7
      300
      true
      """
