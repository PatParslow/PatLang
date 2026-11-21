"""The contract coverage of showcase/p13_contracts_as_data.patlang, in Python.

Python's assert is a statement that leaves no record when it passes, so the
sketch writes a decorator that does: each clause is a text and a lambda, and
a clause that holds is added to a set. The ensure clauses need the values
from before the call, which the decorator has to be told how to take
(before=). The icontract package, installed beside Python, has decorators of
this kind, with clauses as lambdas whose text it reads from the source.
PatLang records every require and ensure that passes as a fact, with nothing
added to the functions, and the program asks with an ordinary query.

Prints the same lines as the PatLang program.
"""
import functools

HELD = set()  # (function, clause)


def contract(requires=(), ensures=(), before=None):
    def wrap(f):
        @functools.wraps(f)
        def checked(*args):
            for text, test in requires:
                assert test(*args), text
                HELD.add((f.__name__, "require:" + text))
            old = before(*args) if before else None
            result = f(*args)
            for text, test in ensures:
                assert test(result, old, *args), text
                HELD.add((f.__name__, "ensure:" + text))
            return result
        return checked
    return wrap


class Stock:
    def __init__(self):
        self.counts = {}


def count_of(s, item):
    return s.counts.get(item, 0)


@contract(requires=[("n > 0", lambda s, item, n: n > 0)],
          ensures=[("total == before + n", lambda total, before, s, item, n: total == before + n)],
          before=lambda s, item, n: count_of(s, item))
def receive(s, item, n):
    s.counts[item] = count_of(s, item) + n
    return count_of(s, item)


@contract(requires=[("n > 0 and n <= count_of(s, item)", lambda s, item, n: 0 < n <= count_of(s, item))],
          ensures=[("total == before - n and total >= 0", lambda total, before, s, item, n: total == before - n and total >= 0)],
          before=lambda s, item, n: count_of(s, item))
def dispatch(s, item, n):
    s.counts[item] = count_of(s, item) - n
    return count_of(s, item)


@contract(requires=[("count_of(s, item) > 0", lambda s, item: count_of(s, item) > 0)],
          ensures=[("count_of(s, item) == 0", lambda lost, before, s, item: count_of(s, item) == 0)])
def write_off(s, item):
    lost = count_of(s, item)
    s.counts[item] = 0
    return lost


DECLARED = [
    ("receive", "require:n > 0"),
    ("receive", "ensure:total == before + n"),
    ("dispatch", "require:n > 0 and n <= count_of(s, item)"),
    ("dispatch", "ensure:total == before - n and total >= 0"),
    ("write_off", "require:count_of(s, item) > 0"),
    ("write_off", "ensure:count_of(s, item) == 0"),
]


def coverage_report():
    covered = 0
    for fn, clause in DECLARED:
        mark = "never checked"
        if (fn, clause) in HELD:
            mark, covered = "checked", covered + 1
        print(f"  {fn}: {clause}  -- {mark}")
    print(f"  {covered} of {len(DECLARED)} clauses checked")


s = Stock()
receive(s, "bolts", 40)
receive(s, "nuts", 25)
dispatch(s, "bolts", 15)

print("== coverage after receiving and dispatching ==")
coverage_report()
print("== the functions checked so far, asked directly ==")
names = []
for fn, _ in DECLARED:
    if any(f == fn for f, _ in HELD) and fn not in names:
        names.append(fn)
print("  " + ", ".join(names))
print("== after a write-off ==")
write_off(s, "nuts")
coverage_report()
