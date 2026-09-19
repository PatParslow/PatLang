Feature: structural symbolic differentiation and interval-based monotonicity (sym_derivative, sym_is_monotonic, self_hosting/lib/symbolic.patlang -- NOT YET IMPLEMENTED, this is the pre-implementation RED spec)

  Scenario: derivative of a sum is the sum of derivatives
    Given sym_add(sym_pow(sym_var("x"), sym_const(2)), sym_const(5)) -- x^2 + 5
    When sym_derivative is called with respect to "x", then evaluated at x=3
    Then the result is Interval(6, 6) -- d/dx(x^2+5) = 2x, and 2*3 = 6

  Scenario: derivative of a product uses the product rule, not a naive per-factor derivative
    Given sym_mul(sym_var("x"), sym_sin(sym_var("x"))) -- x * sin(x)
    When sym_derivative is called with respect to "x", then evaluated at x=0
    Then the result is Interval(0, 0) -- sin(x) + x*cos(x) at x=0 is 0 + 0 = 0, distinguishing this
    from the wrong naive answer (just cos(x), which would give 1 at x=0)

  Scenario: a strictly increasing region is correctly identified as monotonic
    Given f(x) = x^2 - 2 and its derivative 2x
    When sym_is_monotonic is called with interval Interval(1, 2)
    Then the result is true -- the derivative's own interval evaluates to Interval(2, 4), which does
    not straddle zero

  Scenario: a region straddling a turning point is correctly identified as NOT monotonic
    Given f(x) = x^2 - 2 and its derivative 2x
    When sym_is_monotonic is called with interval Interval(-1, 1)
    Then the result is false -- the derivative's own interval evaluates to Interval(-2, 2), which
    DOES straddle zero, so no monotonicity guarantee can be made from this test alone

  Note: sym_is_monotonic is deliberately a SUFFICIENT, not necessary, test -- it can return false for
  a function that IS genuinely monotonic on the given interval if the interval is too coarse for the
  derivative's own interval evaluation to prove it (a false negative is safe; a false positive is not,
  and must never happen). This asymmetry is exactly why the root-set solver (see
  symbolic_materialize_bounded_range.feature) bisects sub-intervals that fail the monotonicity check
  further, rather than giving up on them.
