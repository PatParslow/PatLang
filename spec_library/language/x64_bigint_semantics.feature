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

  A third, unrelated gap (GitHub #188), found writing a fixture for the second:
  the self-hosted lexer (used only by `patc1 --x64`, not the interpreter) reads
  a `.` as the start of a float literal without checking whether a digit
  follows it, so `233.to_s` (an int literal immediately followed by a
  paren-less member access, no space) tokenized as the malformed number text
  "233." with no `.` token left at all for the parser to see -- a parse error,
  not a runtime issue. Fixed to match the real lexer, which only commits to a
  float literal when a digit genuinely follows the dot.

  Scenario: an int literal immediately followed by .member parses and runs, matching the interpreter
    Given 233.to_s, 4.to_s, [1, 2, 3].length, and n.to_s through a variable
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same five lines

  A fourth gap (GitHub #186), found once the previous three were fixed: an
  exact Rational result never demoted back to Int/BigInt on native x64, even
  though the interpreter always has (`(1/2) + (1/2)` is `int`, not
  `rational`). Both backends now agree with the interpreter's own behaviour:
  Rational demotes on an exact result, matching every other numeric-tower
  demotion this backend already does (BigInt -> Int, Rational's own
  `rt_rational_to_string` "d == 1" display case). This matters beyond
  `type_of`: native x64 decides per-operation whether later arithmetic on a
  value takes the plain-int or dynamic-mode path from its own static
  analysis, so a Rational escaping an exact `/`/`%` broke ordinary integer
  idioms like `(n - n % k) / k` used throughout this codebase, not just the
  reported type.

  Scenario: an exact Rational result demotes to int, an inexact one stays Rational, matching the interpreter
    Given exact and inexact sums, an exact and inexact product, an exact subtraction, exact and inexact division, and an exact modulo, all built from Rationals
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same twelve lines

  A fifth gap (GitHub #189), found testing #187's own .to_s fix against a
  float value directly: type_of() and .to_s only ever recognized a BOXED
  float (rt_box_float), and boxing only happened as a side effect of
  dynamic-mode arithmetic promotion. A genuine unboxed float -- a bare
  float literal in a function with no other dynamic-mode trigger, or the
  direct result of sqrt()/sin()/etc. -- carries no runtime tag at all, so
  type_of misread its raw bit pattern as a plain int. rt_box_float's own
  header already named the missing piece: "the compiler-side analysis that
  would automatically decide WHERE to box a float value ... across an
  unprovable call boundary." Native x64 now runs that analysis (reusing
  the same per-instruction float taint used for print's own float-aware
  fix) for the two call boundaries that actually need a real tag: a Call
  to type_of, and the receiver argument of a Call to get (the primitive
  behind .to_s and other generic member access) -- boxing the value there,
  immediately before the call, rather than trying to box every float the
  moment it's created.

  Scenario: type_of and .to_s recognize a genuine unboxed float, whether from a bare literal or sqrt()'s direct result
    Given a bare float literal and the direct, un-promoted result of sqrt()
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same six lines: float, its string form, float again, the sqrt result's string form, the literal's own correct print, and "after"
