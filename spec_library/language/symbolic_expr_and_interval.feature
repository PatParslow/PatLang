Feature: symbolic expression construction and interval evaluation (sym_const/sym_var/sym_add/sym_sub/sym_mul/sym_div/sym_pow/sym_sqrt, sym_eval_interval, sym_interval_add/sub/mul/div, self_hosting/lib/symbolic.patlang -- NOT YET IMPLEMENTED, this is the pre-implementation RED spec)

  Scenario: A constant expression evaluates to a zero-width interval
    Given sym_const(2)
    When sym_eval_interval is called with no bindings
    Then the result is Interval(2, 2) -- lo and hi identical, since a literal constant carries no uncertainty

  Scenario: An exact rational operation keeps a zero-width interval
    Given sym_div(sym_const(10), sym_const(3)) -- 10/3, which the Numeric Tower already keeps as an exact Rational rather than a lossy float
    When sym_eval_interval is called
    Then the result is Interval(10/3, 10/3) -- still zero-width, because the Tower's own Rational is exact, not an approximation needing enclosure

  Scenario: sqrt of a non-perfect-square widens the interval to genuine machine precision, matching the hand-verified bisection result
    Given sym_sqrt(sym_const(2))
    When sym_eval_interval is called
    Then the result is Interval(1.414213562373095, 1.4142135623730951) -- the same one-ULP-wide bracket already hand-verified by direct bisection on interval-arithmetic.html, confirming sym_eval_interval's sqrt enclosure and the page's own worked example agree

  Scenario: interval multiplication checks all four endpoint cross-products, not just same-position pairs
    Given A = Interval(1, 2) and B = Interval(3, 4)
    When sym_interval_mul(A, B) is called
    Then the result is Interval(3, 8)

  Scenario: multiplication correctly picks the true min/max when a sign flips inside an interval
    Given A = Interval(-2, 3) and B = Interval(-1, 4)
    When sym_interval_mul(A, B) is called
    Then the result is Interval(-8, 12) -- the minimum comes from (-2)*4, not from any same-position endpoint pairing

  Note: interval endpoints are Numeric Tower values, not raw floats -- sym_eval_interval must keep
  every endpoint as an exact Int/Rational for as long as the expression stays purely algebraic
  (+, -, *, /, integer Pow), and only switches to a genuinely-enclosing (possibly float) bound at a
  transcendental node (Sqrt of a non-perfect-square, Sin, Cos, Tan) with no exact Tower
  representation. This is the concrete form of the design decision that exact-Rational endpoints
  sidestep the usual directed-rounding problem interval arithmetic normally needs hardware support
  for -- most of this library gets correctness-by-construction from the Tower already being exact,
  for free.
