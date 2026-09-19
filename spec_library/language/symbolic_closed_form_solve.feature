Feature: closed-form solving for recognized polynomial forms (sym_solve_for, self_hosting/lib/symbolic.patlang -- NOT YET IMPLEMENTED, this is the pre-implementation RED spec)

  Scenario: a linear equation returns exactly one exact solution
    Given sym_solve_for is called on 2*x + 4 = 0 for variable "x"
    Then the result is Solutions([-2]) -- one exact Const, not an interval, since the coefficients
    are exact integers and the solve is closed-form

  Scenario: a quadratic with a positive discriminant returns exactly two real solutions
    Given sym_solve_for is called on x^2 - 2 for variable "x" -- discriminant of x^2 + 0x - 2 is
    0^2 - 4*1*(-2) = 8, positive
    Then the result is Solutions([...]) with exactly 2 elements, evaluating via sym_eval_interval to
    Interval(-1.4142135623730951, -1.414213562373095) and Interval(1.414213562373095,
    1.4142135623730951) -- the same sqrt(2) bracket already verified by direct bisection, now reached
    by recognizing x^2-2 as a quadratic rather than a general numeric search

  Scenario: a quadratic with a zero discriminant returns exactly one (repeated) solution
    Given sym_solve_for is called on x^2 - 4*x + 4 for variable "x" -- (x-2)^2, discriminant
    16 - 16 = 0
    Then the result is Solutions([2]) -- a list with exactly ONE element, not two, confirming the
    repeated root is not double-counted

  Scenario: a quadratic with a negative discriminant returns a complex conjugate pair via the Tower's own Complex kind
    Given sym_solve_for is called on x^2 + 1 for variable "x" -- discriminant 0 - 4 = -4, negative
    Then the result is Solutions([...]) with exactly 2 elements, both of numeric_kind "complex" -- i
    and -i, reusing the Numeric Tower's existing Complex promotion (the same mechanism sqrt(-4)
    already uses) rather than inventing a separate complex-number path

  Note: quadratic recognition matches the general shape a*x^2 + b*x + c by inspecting sym_derivative
  applied twice (a function whose SECOND derivative with respect to x is a nonzero constant, and whose
  THIRD is zero, is a quadratic in x), not a syntactic "looks like x^2" pattern match -- reusing
  sym_derivative rather than writing a separate polynomial-degree inspector, and correctly recognizing
  forms like 3*(x-1)^2 - 3*x^2 + 2*x that simplify down to a quadratic even though they don't look
  like one on the page. Linear recognition works the same way one derivative down (first derivative
  constant, second zero).
