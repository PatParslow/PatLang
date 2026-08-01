Feature: x64 tag-collision PREVENTION sweep (GitHub #49's core ask, #48's fix)

  Scenario: A plain int cannot coincidentally collide with a reserved family tag at zero payload
    Given a plain int bit-identical to each of the 8 reserved x64 family tags (String/List/Closure/Object/BigInt/Rational/Complex/Interval), each with a ZERO payload
    When type_of() classifies each one, compiled and run via --x64
    Then a plain int bit-identical to any of the 8 reserved family tags (String/List/Closure/Object/BigInt/Rational/Complex/Interval) with a ZERO payload is still classified as "int", never coincidentally misread as that family (GitHub #48's fix, swept across all 8 tags at once)

  Note: this is a PREVENTION invariant over the values themselves, not a
  per-consumer robustness test (see GitHub #49's own framing) -- it
  exists specifically to catch a regression of #48's fix across all 8
  reserved tags at once, rather than relying on any one function
  happening to be exercised by chance. A SEPARATE, real bug (GitHub #51)
  was found while writing this: the same collision with a NONZERO
  payload segfaults type_of() outright -- not covered by #48's fix, not
  yet fixed, and deliberately NOT wired into this standing suite until
  there's a real fix to regression-test (a scenario asserting a known
  crash isn't useful as a passing gate).
