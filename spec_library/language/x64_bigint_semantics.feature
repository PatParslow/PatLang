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

  A second, related class of gap (GitHub #187), found chasing a real crash in
  `utf8_selftest.patlang`: `v.to_s` (a paren-less Member access) lowers to
  `CallHost "get" 2`, matching the interpreter's own `host_get` ->
  `builtin_primitive_method` dispatch. Native `get(store, key)` only ever
  implemented the ambient-`__vars`-namespace-lookup meaning, so a non-string
  receiver reached `rt_ns_find`'s own `rt_str_eq` comparison as if it were a
  heap pointer -- a segfault once any other namespace already existed, a
  silent wrong `0` otherwise. Separately, `chr()` on a Rational (`/` on two
  ints promotes to Rational unless exact, which byte-math idioms like
  `chr(192 + cp / 64)` rely on `chr()` truncating back down, matching the
  interpreter) took its argument as a raw tagged word with no type check, so
  the Rational's tag bits became the byte instead of its truncated value.
  Third, `%` between two Rational values had no implementation at all (the
  same #185 trap, whose own comment wrongly assumed Rational `%` has no
  meaningful definition -- checked directly against the interpreter and it
  does: real floating-point-style modulo).

  Scenario: v.to_s on primitives, chr() on a Rational, and Rational %, match the interpreter
    Given int, Rational, Bool and List values stringified with .to_s, a byte built via chr() on a Rational produced by /, and several Rational % combinations including negative operands
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same thirteen lines
