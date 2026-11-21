"""The measured-value calculator of showcase/c4_proven_calculator.patlang, in Python.

Python's operator overloading suits this well: Measured defines __add__,
__sub__, __mul__ and __truediv__, as the PatLang class defines + - * and /,
and a formula reads as arithmetic in both. What Python lacks is the interval
itself, so the sketch carries the small one it needs over fractions.Fraction,
and the notebook notation is read with a regular expression at run time
where PatLang defines it as syntax. The contract that each nominal figure
lies inside its interval is an assert in each operation.

Prints the same lines as the PatLang program.
"""
import re
from fractions import Fraction
from math import floor

NOTEBOOK = """
    mass = 1250/1000 +- 5/1000 kg
    speed = 340/100 +- 2/100 m_per_s
    drop = 2/1 +- 1/100 m
    g = 981/100 +- 1/100 m_per_s_squared
"""


class Interval:
    def __init__(self, lo, hi):
        assert lo <= hi
        self.lo, self.hi = lo, hi

    def __add__(self, o):
        return Interval(self.lo + o.lo, self.hi + o.hi)

    def __sub__(self, o):
        return Interval(self.lo - o.hi, self.hi - o.lo)

    def __mul__(self, o):
        ends = [self.lo * o.lo, self.lo * o.hi, self.hi * o.lo, self.hi * o.hi]
        return Interval(min(ends), max(ends))


def nominal_of(x):
    return x.nominal if isinstance(x, Measured) else Fraction(x)


def range_of(x):
    return x.range if isinstance(x, Measured) else Interval(Fraction(x), Fraction(x))


class Measured:
    def __init__(self, nominal, rng):
        assert rng.lo <= nominal <= rng.hi
        self.nominal, self.range = nominal, rng

    def __add__(self, o):
        return Measured(self.nominal + nominal_of(o), self.range + range_of(o))

    def __sub__(self, o):
        return Measured(self.nominal - nominal_of(o), self.range - range_of(o))

    def __mul__(self, o):
        return Measured(self.nominal * nominal_of(o), self.range * range_of(o))

    def __truediv__(self, o):
        d = range_of(o)
        assert d.lo > 0 or d.hi < 0
        return Measured(self.nominal / nominal_of(o), self.range * Interval(1 / d.hi, 1 / d.lo))


READINGS = {}
for m in re.finditer(r"(\w+) = (\d+)/(\d+) \+- (\d+)/(\d+) (\w+)", NOTEBOOK):
    v, t = Fraction(int(m[2]), int(m[3])), Fraction(int(m[4]), int(m[5]))
    READINGS[m[1]] = Measured(v, Interval(v - t, v + t))


def decimal(x, way):
    """x to four places: to the nearest (0), down (-1) or up (1)."""
    if way < 0:
        n = floor(x * 10000)
    elif way > 0:
        n = -floor(-x * 10000)
    else:
        n = floor(x * 10000 + Fraction(1, 2))
    return f"{n // 10000}.{n % 10000:04d}"


def report(label, m):
    print(f"{label}: {decimal(m.nominal, 0)}, certainly between {decimal(m.range.lo, -1)} and {decimal(m.range.hi, 1)}")


mass, speed, drop, g = (READINGS[k] for k in ("mass", "speed", "drop", "g"))
print("== readings ==")
report("mass (kg)", mass)
report("speed (m/s)", speed)
print("== formulas ==")
kinetic = mass * speed * speed / 2
report("kinetic energy, m v^2 / 2 (J)", kinetic)
potential = mass * g * drop
report("potential energy, m g h (J)", potential)
report("their sum (J)", kinetic + potential)
print(f"the kinetic energy exactly: {kinetic.nominal}")
