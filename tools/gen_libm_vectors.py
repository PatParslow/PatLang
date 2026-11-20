"""Test vectors for v2's math functions (self_hosting/v2/runtime/libm.patlang).

    py -3 -I tools/gen_libm_vectors.py > self_hosting/v2/spec/libm_vectors.txt

Each line is a function name, its inputs and the correctly rounded result,
every double written as its IEEE 754 bits read as a signed 64-bit integer
(which a PatLang int holds as it is). A result that is a NaN is written as
"nan": any NaN meets it.

Finite results come from mpmath at 300 bits, rounded to the nearest double;
special inputs (NaN, infinities, zeros, a domain error) take the values C99
Annex F gives. The inputs are fixed by a seeded generator, so the file is the
same on every run.
"""
import math
import random
import struct

import mpmath

mpmath.mp.prec = 300
RNG = random.Random(20261119)


def bits(x):
    return struct.unpack("<q", struct.pack("<d", x))[0]


def out(x):
    if isinstance(x, float) and math.isnan(x):
        return "nan"
    return str(bits(x))


def rounded(v):
    """An mpf to the nearest double, ties to even, subnormals included."""
    if mpmath.isnan(v):
        return float("nan")
    if mpmath.isinf(v):
        return float("inf") if v > 0 else float("-inf")
    return float(mpmath.mpf(v))


def spread(lo_exp, hi_exp, n, signed=True):
    xs = []
    for _ in range(n):
        m = RNG.uniform(1.0, 2.0)
        e = RNG.randint(lo_exp, hi_exp)
        x = math.ldexp(m, e)
        if signed and RNG.random() < 0.5:
            x = -x
        xs.append(x)
    return xs


SPECIALS = [0.0, -0.0, float("inf"), float("-inf"), float("nan"), 5e-324, -5e-324,
            2.2250738585072014e-308, 1.7976931348623157e308, -1.7976931348623157e308]

lines = []


def emit(name, args, result):
    lines.append(" ".join([name] + [str(bits(a)) for a in args] + [out(result)]))


def unary(name, fn_mp, inputs, special):
    for x in inputs:
        if math.isnan(x) or math.isinf(x) or x == 0.0 or special(x) is not None:
            r = special(x)
            if r is None:
                r = rounded(fn_mp(mpmath.mpf(x)))
            emit(name, [x], r)
        else:
            emit(name, [x], rounded(fn_mp(mpmath.mpf(x))))


# ---- the trigonometric functions ----
trig_inputs = SPECIALS + spread(-30, 4, 300) + spread(5, 60, 80) + spread(61, 1023, 60)
trig_inputs += [1e22, -1e22, 1e300, 2.0 ** 1000, math.pi, math.pi / 2, math.pi / 4, 3 * math.pi / 2]
for k in range(1, 40):
    trig_inputs.append(k * math.pi / 2)
    trig_inputs.append(math.nextafter(k * math.pi / 2, 0.0))


def trig_special(x):
    if math.isnan(x) or math.isinf(x):
        return float("nan")
    return None


def sin_special(x):
    if x == 0.0:
        return x
    return trig_special(x)


def cos_special(x):
    if x == 0.0:
        return 1.0
    return trig_special(x)


unary("sin", mpmath.sin, trig_inputs, sin_special)
unary("cos", mpmath.cos, trig_inputs, cos_special)
unary("tan", mpmath.tan, trig_inputs, sin_special)

# ---- the inverse trigonometric functions ----
inv_inputs = SPECIALS + spread(-60, -1, 300) + [1.0, -1.0, 0.5, -0.5, math.nextafter(1.0, 0.0), 1.5, -2.0]


def asin_special(x):
    if math.isnan(x) or abs(x) > 1:
        return float("nan")
    if x == 0.0:
        return x
    return None


def acos_special(x):
    if math.isnan(x) or abs(x) > 1:
        return float("nan")
    return None


unary("asin", mpmath.asin, inv_inputs, asin_special)
unary("acos", mpmath.acos, inv_inputs, acos_special)


def atan_special(x):
    if math.isnan(x):
        return float("nan")
    if math.isinf(x):
        return math.copysign(math.pi / 2, x)
    if x == 0.0:
        return x
    return None


unary("atan", mpmath.atan, SPECIALS + spread(-60, 60, 400), atan_special)

for _ in range(400):
    y = spread(-40, 40, 1)[0]
    x = spread(-40, 40, 1)[0]
    emit("atan2", [y, x], rounded(mpmath.atan2(mpmath.mpf(y), mpmath.mpf(x))))
for y in [0.0, -0.0, 1.0, -1.0, float("inf"), float("-inf"), float("nan")]:
    for x in [0.0, -0.0, 1.0, -1.0, float("inf"), float("-inf"), float("nan")]:
        emit("atan2", [y, x], math.atan2(y, x))

# ---- exp and log ----
exp_inputs = SPECIALS + [RNG.uniform(-745.2, 709.8) for _ in range(400)] + spread(-60, 0, 80)
exp_inputs += [709.78, 709.79, -745.1, -745.2, -708.4, 1.0, -1.0]


def exp_special(x):
    if math.isnan(x):
        return float("nan")
    if x == float("inf"):
        return x
    if x == float("-inf"):
        return 0.0
    if x == 0.0:
        return 1.0
    if x > 709.8:
        return float("inf")
    return None


unary("exp", mpmath.exp, exp_inputs, exp_special)

log_inputs = SPECIALS + spread(-1074, 1023, 400, signed=False) + [1.0, math.nextafter(1.0, 2.0), math.nextafter(1.0, 0.0), 2.0, math.e, 10.0, -1.0]
log_inputs += [1.0 + RNG.uniform(-0.01, 0.01) for _ in range(60)]


def log_special(x):
    if math.isnan(x) or x < 0:
        return float("nan")
    if x == 0.0:
        return float("-inf")
    if x == float("inf"):
        return x
    return None


unary("log", mpmath.log, log_inputs, log_special)

# ---- pow ----
def c_pow(b, e):
    """pow as C99 Annex F gives it, where Python raises instead."""
    try:
        return math.pow(b, e)
    except ValueError:
        if b == 0.0 and e < 0:
            odd = math.isfinite(e) and e == int(e) and int(e) % 2 == 1
            return math.copysign(float("inf"), b) if odd else float("inf")
        return float("nan")
    except OverflowError:
        odd = math.isfinite(e) and e == int(e) and int(e) % 2 == 1
        return -float("inf") if (b < 0 and odd) else float("inf")


pow_specials = [0.0, -0.0, 1.0, -1.0, 2.0, -2.0, 0.5, -0.5, 3.0, -3.0, float("inf"), float("-inf"), float("nan")]
for b in pow_specials:
    for e in pow_specials:
        emit("pow", [b, e], c_pow(b, e))
for _ in range(400):
    b = abs(spread(-20, 20, 1)[0])
    e = RNG.uniform(-60, 60)
    r = mpmath.power(mpmath.mpf(b), mpmath.mpf(e))
    emit("pow", [b, e], rounded(r))
for _ in range(120):
    b = spread(-4, 4, 1)[0]
    e = float(RNG.randint(-60, 60))
    emit("pow", [b, e], rounded(mpmath.power(mpmath.mpf(b), int(e))))
for b in [10.0, 2.0, 0.1, 1.0000001]:
    for e in [308.0, -308.0, 1024.0, -1075.0, 1e10, 0.5]:
        emit("pow", [b, e], rounded(mpmath.power(mpmath.mpf(b), mpmath.mpf(e))))

# ---- fmod: exact ----
for _ in range(300):
    x = spread(-40, 40, 1)[0]
    y = spread(-40, 40, 1)[0]
    emit("fmod", [x, y], math.fmod(x, y))
for x in [0.0, -0.0, 1.0, float("inf"), float("nan"), 5e-324]:
    for y in [0.0, 1.0, -1.0, float("inf"), float("nan"), 5e-324]:
        try:
            r = math.fmod(x, y)
        except ValueError:
            r = float("nan")
        emit("fmod", [x, y], r)

# ---- exact: sqrt, floor, ceil, trunc, round (half away from zero) ----
exact_inputs = SPECIALS + spread(-1074, 1023, 200) + [0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 0.49999999999999994, 4503599627370495.5, -4503599627370495.5]
for x in exact_inputs:
    emit("sqrt", [x], math.sqrt(x) if not (x < 0) else float("nan"))
    emit("floor", [x], math.floor(x) * 1.0 if math.isfinite(x) else x)
    emit("ceil", [x], math.ceil(x) * 1.0 if math.isfinite(x) else x)
    emit("trunc", [x], float(math.trunc(x)) if math.isfinite(x) else x)
    if math.isfinite(x):
        r = math.floor(abs(x) + 0.5) if abs(x) < 2 ** 52 else abs(x)
        if abs(x) < 2 ** 52 and (abs(x) + 0.5) - 0.5 != abs(x) and abs(x) % 1 != 0.5:
            r = math.floor(abs(x)) if abs(x) % 1 < 0.5 else math.floor(abs(x)) + 1
        emit("round", [x], math.copysign(float(r), x))
    else:
        emit("round", [x], x)

# keep -0.0 signs right for the exact ones: floor/ceil/trunc/round of a negative
# number that rounds to zero is -0.0 (C99), which math.floor's int loses
fixed = []
for line in lines:
    parts = line.split()
    if parts[0] in ("floor", "ceil", "trunc", "round") and parts[-1] == str(bits(0.0)):
        x = struct.unpack("<d", struct.pack("<q", int(parts[1])))[0]
        if math.copysign(1.0, x) < 0:
            parts[-1] = str(bits(-0.0))
    fixed.append(" ".join(parts))

print("# generated by tools/gen_libm_vectors.py: function, inputs, correctly rounded result (IEEE bits as signed int64)")
print("\n".join(fixed))
