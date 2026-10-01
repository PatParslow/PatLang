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

  A sixth gap (GitHub #50/#102), found reviewing #50's own scheduled
  design question about the tagging representation: mixing a genuine int
  local with a float literal inside the SAME Bin, in a function this
  backend already classifies float_mode (e.g. `x + 2.5` where x is an
  ordinary int local), was compiled as though BOTH operands already held
  raw float64 bit patterns -- reinterpreting the int's own bits as a
  double instead of converting it, silently discarding its real value
  (`5 + 2.5` printed `2.5`, not `7.5`). Fixed by tracking, per Bin
  operand, whether it is PROVEN to be a genuine plain int fully
  accounted for within this function's own code (a literal, or
  arithmetic built only from such values) -- only a side proven this way
  is converted via a real cvtsi2sd; a function PARAMETER or any Call/
  CallHost result is never trusted this way, since its true value could
  be anything the analysis cannot see, and treating "never proven float"
  as "definitely int" there corrupted a genuine float smuggled in from
  outside (found the hard way: an earlier, less careful version of this
  fix silently corrupted x64_runtime.patlang's own internal float-
  printing code, segfaulting even a bare `print(2.5)`, which contains no
  Bin at all in its own body).

  Scenario: an ordinary int local mixed with a float literal in one Bin converts correctly on either side
    Given `x + 2.5` where x is an int local, and `a + x` where a is a float local and x an int local
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print true for both comparisons against 7.5

  A seventh gap (GitHub #194, a follow-up to #50's own scheduled design
  review): a genuinely polymorphic function (no float literal anywhere in
  its own body, so never classified float_mode -- e.g. `make a function
  called plus takes a, b returns r; return a + b end`) compiles its own
  `a + b` through the DYNAMIC-mode arithmetic dispatch instead
  (x64_binop_asm_dynamic -> rt_dynamic_binop), which had no awareness of
  the boxed-float family tag at all -- a float argument reaching it had
  its raw bits misread as whichever OTHER family they happened to decode
  to (often List or Closure) and dereferenced as a heap pointer, a real
  segfault, not just a wrong value. Fixed by giving rt_dynamic_binop's
  own numeric dispatch (rt_dynamic_numeric_binop) a genuine float case,
  using new raw-float64-arithmetic primitives (x64_int_to_float_bits,
  x64_float_add/sub/mul/div_bits, x64_float_cmp_bits) that expose the
  same real SSE2 ops x64_binop_asm_float already does inline for a
  float_mode function's own Bin instructions, as ordinary callable
  primitives a non-float_mode function's dynamic dispatch can use too.
  Verified with a value boxed explicitly (`rt_box_float`, this backend's
  own internal representation, not reachable from the interpreter, so
  this scenario is native-only) rather than relying on automatic
  boxing at the call site, which remains real, separate follow-up work
  (see GitHub #195 for the precise reason it isn't done yet -- a
  block-model calling-convention detail found but not yet root-caused
  while investigating it).

  Scenario: a boxed float reaching a non-float-mode function's dynamic arithmetic computes and reports its type correctly
    Given plus(a, b) with no float literal in its own body, called with an explicitly boxed 1.5 and a plain int 2
    When the file is compiled and run via --x64 only (rt_box_float has no interpreter equivalent)
    Then it prints 3.5 and then float, not a segfault

  An eighth gap (GitHub #195, the cross-compilation-unit half of #50's
  own design review): a float-returning function, compiled as its own
  isolated per-function unit by the object-cache pipeline, was invisible
  to its CALLER's own unit -- `type_of(make_half())` reported "int" for
  `make_half() { return 1.0/2.0 }` even though make_half's own body has
  an obvious float literal. Root-caused to two compounding gaps: (1)
  float_func_names was computed fresh per compilation unit instead of
  whole-program (now threaded across units via the ambient __vars
  namespace, see x64_extra_float_func_names's own header), and (2), the
  deeper one: the Block Ownership Model's own calling convention wraps
  every declared function's return value as a two-element
  [value, final_globals] list (Fork B's elimination of ambient global
  state), unpacked by a fixed instruction sequence immediately after
  every Call -- the taint analysis was treating the Call's own raw
  result (always a List, never a float) as directly the float-or-not
  value, instead of the unpack sequence's own final list_get. Fixed by
  recognizing block-model-lowered calls by their "bm_fn_" name prefix
  and shifting the float classification to the unpack's own tail
  instruction (x64_bm_unpack_value_callee).

  Scenario: a float-returning function proves float across the per-unit compilation boundary
    Given make_half() returning 1.0/2.0, with no caller-side float evidence of its own
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both report type_of "float" and both confirm the value equals 0.5

  A ninth gap, closing #194's own remaining half (the first half, the
  core dynamic-dispatch segfault, was fixed in the "boxed 1.5" scenario
  above): a float argument passed to an ORDINARY call site -- no manual
  `rt_box_float` anywhere in the source -- still reached a non-float-mode
  callee's dynamic arithmetic as raw, unboxed bits, silently misread as
  a fixnum. Fixed by computing, during the existing per-instruction taint
  analysis, which Call arguments are float-tainted AND the callee is both
  not float_mode and a genuine block-model-lowered user function
  ("bm_fn_"-prefixed) -- deliberately excluding runtime primitives like
  `type_of`/`get` (already boxed via #189's own dedicated, narrower
  mechanism; boxing here too would double-box) and `floor` (expects raw
  bits directly, per #99's own adaptive-dispatch note) -- then emitting a
  self-contained box-in-place sequence against the real stack slot for
  each flagged position, immediately before the call itself.

  Scenario: a float literal argument at an ordinary call site is auto-boxed, no manual boxing needed
    Given plus(a, b) with no float literal in its own body, called directly as plus(1.5, 2)
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print 3.5, with no manual rt_box_float call anywhere in the source
