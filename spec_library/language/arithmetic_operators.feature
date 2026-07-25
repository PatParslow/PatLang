Feature: arithmetic operators + - * / % (plain integers)

  Scenario: Basic arithmetic
    Given the integers 2 and 3
    When +, -, *, / are applied
    Then 2+3=5, 5-3=2, 4*3=12, 10/2=5

  Scenario: Multiplication binds tighter than addition
    Given 2 + 3 * 4
    When evaluated
    Then the result is 14, not 20 -- * is evaluated before +

  Scenario: Modulo follows the dividend's sign (truncating, not floored)
    Given -10 % 3
    When evaluated
    Then the result is -1, matching truncating division convention (like Rust/C, unlike Python's floored modulo)

  Note: this spec covers PLAIN INTEGER arithmetic only. Cross-type
  behaviour (Int+Float, Rational, BigInt overflow promotion, Complex)
  is real and already covered by a separate, previously-verified
  initiative -- see the numeric tower documentation, not this spec.

