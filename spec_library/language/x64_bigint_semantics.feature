Feature: BigInt arithmetic agrees between the interpreter and native x64 (GitHub #185)

  Native x64 dispatches `%` through its own dedicated dynamic-mode path, which
  handles two genuine fixnums directly and, until this issue, hard-exited with
  code 97 ("unsupported operand") the moment either side of `%` was not a plain
  fixnum. BigInt `%` had no runtime implementation at all -- not a wrong answer,
  a deliberate trap, but one a real program (a hash or a modular reduction over
  a value that overflowed into BigInt) can reach. `rt_bigint_mod`
  (x64_runtime.patlang) now does real bigint long division: a schoolbook
  division, one base-10^9 limb of the quotient at a time, each limb found by
  binary search using the existing, already-correct magnitude add/sub/mul/cmp
  primitives, so no intermediate ever needs more than ordinary 64-bit
  arithmetic. Truncating toward zero, matching this backend's own plain-int `%`
  and the interpreter's BigInt `%`: the remainder's sign is the dividend's sign
  (or zero), never the divisor's. Rational/Complex/Interval have no meaningful
  `%` in this tower and a zero divisor is a genuine error; both still exit 97,
  the same code this trap always used, now reached only for a genuinely
  unsupported case.

  Scenario: BigInt modulo, mixed signs and a BigInt divisor, matches the interpreter
    Given a value that overflows into BigInt, reduced by a small positive divisor, a small negative divisor, a negated dividend, and by another BigInt (including an exact multiple)
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same nine lines
