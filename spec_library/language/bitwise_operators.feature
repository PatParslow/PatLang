Feature: bitwise operators band / bor / bxor / shl / shr

  Each scenario carries its program, runs it interpreted and compiled, and says
  what both print (spec_steps_program.patlang).

  Scenario: band/bor/bxor perform ordinary bitwise logic
    Given the program
      """
      print([12 band 10, 12 bor 10, 12 bxor 10])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [8, 14, 6]
      """

  Scenario: shl/shr shift by the given bit count
    Given the program
      """
      print([1 shl 4, 16 shr 4])
      """
    When it runs interpreted and compiled
    Then both print
      """
      [16, 1]
      """

  Scenario: bitwise ops on small operands stay int, not misclassified as bigint (GitHub #24/#46/#48 regression guard)
    Given the program
      """
      let x = 12 bxor 10
      print(numeric_kind(x))
      """
    When it runs interpreted and compiled
    Then both print
      """
      int
      """

  Scenario: an add that overflows a machine int correctly promotes to bigint
    Given the program
      """
      let x = 9223372036854775807 + 1
      print(numeric_kind(x))
      print(x)
      """
    When it runs interpreted and compiled
    Then both print
      """
      bigint
      9223372036854775808
      """
