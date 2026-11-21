"""The currency converter of showcase/p11_spec_in_its_own_words.patlang, in Python.

The rate notation is parsed at run time with a regular expression, where the
PatLang program defines it as syntax, expanded before the program runs into
calls that record facts. The Gherkin feature runs on a step matcher written
here with re. A Python project would use behave or
pytest-bdd, packages installed beside Python, which keep the feature in a
.feature file of its own; PatLang's Gherkin runner is in its standard
library, and the feature can sit in the program it specifies. Exact amounts
come from fractions.Fraction.

Prints the same lines as the PatLang program.
"""
import re
from fractions import Fraction

RATES_TEXT = """
    GBP => EUR 117 per 100
    EUR => USD 108 per 100
    USD => JPY 15000 per 100
"""
RATES = {}
for line in RATES_TEXT.strip().splitlines():
    m = re.fullmatch(r"\s*([A-Z]{3}) => ([A-Z]{3}) (\d+) per (\d+)\s*", line)
    RATES[(m[1], m[2])] = Fraction(int(m[3]), int(m[4]))


def rate_between(a, b):
    if a == b:
        return Fraction(1)
    if (a, b) in RATES:
        return RATES[(a, b)]
    if (b, a) in RATES:
        return 1 / RATES[(b, a)]
    for (x, mid), r in RATES.items():
        if x == a and (mid, b) in RATES:
            return r * RATES[(mid, b)]
    return Fraction(0)


def convert(amount, a, b):
    r = rate_between(a, b)
    assert r != 0
    return amount * r


def show(x):
    return str(x.numerator) if x.denominator == 1 else str(x)


SPEC = """Feature: converting between currencies

  Scenario: a direct rate
    Given an amount of 3 GBP
    When it is converted to EUR
    Then the result is 351/100

  Scenario: a rate the other way is the reciprocal
    Given an amount of 117 EUR
    When it is converted to GBP
    Then the result is 100

  Scenario: two hops
    Given an amount of 100 GBP
    When it is converted to USD
    Then the result is 3159/25

  Scenario: there and back loses nothing
    Given an amount of 7 EUR
    When it is converted to USD
    Then converting back to EUR gives the amount again"""

passed = failed = 0


def expect(label, got, want):
    global passed, failed
    if got == want:
        passed += 1
        print(f"  ok: {label}")
    else:
        failed += 1
        print(f"  FAIL: {label} (got {got}, want {want})")


def st_amount(ctx, n, cur):
    ctx["amount"], ctx["from"] = Fraction(int(n)), cur


def st_convert(ctx, cur):
    ctx["to"] = cur
    ctx["result"] = convert(ctx["amount"], ctx["from"], cur)


def st_result(ctx, want):
    expect("the converted amount", show(ctx["result"]), want)


def st_back(ctx, cur):
    back = convert(ctx["result"], ctx["to"], cur)
    expect("back in the currency it started in", cur, ctx["from"])
    expect("converted back", back, ctx["amount"])


STEPS = [
    (r"an amount of (\S+) (\S+)", st_amount),
    (r"it is converted to (\S+)", st_convert),
    (r"the result is (\S+)", st_result),
    (r"converting back to (\S+) gives the amount again", st_back),
]

ctx = {}
for line in SPEC.splitlines():
    line = line.strip()
    if line.startswith(("Feature:", "Scenario:")):
        if line.startswith("Scenario:"):
            ctx = {}
        print(line)
        continue
    words = line.split(" ", 1)
    if len(words) == 2 and words[0] in ("Given", "When", "Then", "And"):
        for pattern, f in STEPS:
            m = re.fullmatch(pattern, words[1])
            if m:
                f(ctx, *m.groups())
                break
print(f"tests: {passed} passed, {failed} failed")
print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
