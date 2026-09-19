Feature: closed-form solving for periodic (trig) equations as a parametric solution family (sym_solve_for, sym_pi, self_hosting/lib/symbolic.patlang -- NOT YET IMPLEMENTED, this is the pre-implementation RED spec)

  Scenario: sin(x) = 0 returns a parametric family, not a finite list
    Given sym_solve_for is called on sym_sin(sym_var("x")) for variable "x" with no bounded range
    supplied
    Then the result is a Family, not a Solutions list -- shape ["Family", generator_expr_in_n, "n",
    ["Integers"]] -- because sin has infinitely many roots and no finite list can enumerate them all

  Scenario: the family's generator matches the real closed-form solution
    Given the Family returned above
    When its generator expression is evaluated at n = 0, n = 1, and n = -1
    Then the results are 0, pi, and -pi -- the (-1)^n * asin(c) + n*pi form collapsing correctly for
    c = 0

  Scenario: cos(x) = 1 returns a family with period 2*pi, not pi
    Given sym_solve_for is called on sym_sub(sym_cos(sym_var("x")), sym_const(1)) for variable "x"
    Then the family's generator, evaluated at successive integer n, produces exactly
    ..., -2*pi, 0, 2*pi, ... -- cos's own period, distinct from sin/tan's

  Note: a Family is returned specifically because the underlying trig equation is recognized as a
  closed form -- it is NOT the numeric monotonic-piece fallback from
  symbolic_materialize_bounded_range.feature wearing a different name. The fallback only appears when
  no closed form matches at all, and it always returns Solutions (already bounded, already finite),
  never a Family -- an unbounded solution set can only ever come out of the closed-form path, since
  the numeric path has no way to describe "all of them" without a formula.
