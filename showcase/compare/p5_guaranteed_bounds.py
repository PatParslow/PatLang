"""The guaranteed bounds of showcase/p5_guaranteed_bounds.patlang, in Python.

Python's standard library has no interval type, so the sketch writes the
small one it needs over fractions.Fraction: about twenty lines for + - * and
printing. (mpmath has interval arithmetic, outside the standard library, with
float bounds rounded outwards; exact bounds are what this program wants.)
PatLang has intervals built in, with exact bounds when the numbers are exact.
The contracts become asserts, which python -O removes.

Prints the same lines as the PatLang program.
"""
from fractions import Fraction
from math import sqrt


class Interval:
    def __init__(self, lo, hi):
        assert lo <= hi
        self.lo, self.hi = lo, hi

    @staticmethod
    def of(x):
        return x if isinstance(x, Interval) else Interval(x, x)

    def __add__(self, other):
        o = Interval.of(other)
        return Interval(self.lo + o.lo, self.hi + o.hi)

    def __sub__(self, other):
        o = Interval.of(other)
        return Interval(self.lo - o.hi, self.hi - o.lo)

    def __mul__(self, other):
        o = Interval.of(other)
        ends = [self.lo * o.lo, self.lo * o.hi, self.hi * o.lo, self.hi * o.hi]
        return Interval(min(ends), max(ends))

    def __str__(self):
        return f"[{self.lo},{self.hi}]"


def b(x):
    """A bool as PatLang prints one."""
    return "true" if x else "false"


def measured(value, tol):
    assert tol >= 0
    iv = Interval(value - tol, value + tol)
    assert iv.lo <= value <= iv.hi
    return iv


def area(w, h):
    a = w * h
    assert a.lo <= a.hi
    return a


print("== a measured rectangle ==")
w = measured(Fraction(2), Fraction(1, 100))
h = measured(Fraction(3), Fraction(1, 100))
print(f"width {w}, height {h}")
a = area(w, h)
print(f"area lies in {a}")
print(f"so the area is {a.lo} at least and {a.hi} at most")
print(f"perimeter lies in {w * 2 + h * 2}")


def narrow(iv):
    assert iv.lo * iv.lo <= 2 and iv.hi * iv.hi >= 2
    mid = (iv.lo + iv.hi) / 2
    half = Interval(iv.lo, mid) if mid * mid > 2 else Interval(mid, iv.hi)
    assert half.lo * half.lo <= 2 and half.hi * half.hi >= 2
    return half


def width(iv):
    return iv.hi - iv.lo


print("== the square root of 2 ==")
root = Interval(Fraction(1), Fraction(2))
steps = 0
while width(root) > Fraction(1, 1000000):
    root = narrow(root)
    steps += 1
print(f"after {steps} steps the root lies in {root}")
print(f"width {width(root)}, under a millionth: {b(width(root) < Fraction(1, 1000000))}")
f = sqrt(2.0)
print(f"the float sqrt(2.0) = {f!r} lies inside: {b(root.lo <= f <= root.hi)}")
g = root * root - 2
print(f"x*x - 2 over the interval lies in {g}, which contains zero: {b(g.lo <= 0 <= g.hi)}")
