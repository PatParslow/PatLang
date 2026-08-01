Feature: bitwise operators band / bor / bxor / shl / shr

  Scenario: band/bor/bxor perform ordinary bitwise logic
    Given 12 (1100) and 10 (1010)
    When band, bor, bxor are applied
    Then 12 band 10 = 8 (1000), 12 bor 10 = 14 (1110), 12 bxor 10 = 6 (0110)

  Scenario: shl/shr shift by the given bit count
    Given 1 and 16
    When shl 4 and shr 4 are applied respectively
    Then 1 shl 4 = 16, 16 shr 4 = 1

  Scenario: bitwise ops on small operands stay int, not misclassified as bigint (GitHub #24/#46/#48 regression guard)
    Given x = 12 bxor 10
    When numeric_kind(x) is captured
    Then ensure x_kind == int

  Scenario: an add that overflows a machine int correctly promotes to bigint
    Given x = 9223372036854775807 + 1
    When numeric_kind(x) is captured
    Then ensure x_kind == bigint

