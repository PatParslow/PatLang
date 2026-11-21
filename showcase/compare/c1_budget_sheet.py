"""The budget sheet of showcase/c1_budget_sheet.patlang, in Python.

Exact money is fractions.Fraction, which Python does well. The line's
change event becomes a list of callbacks the setter calls, and the contracts
become asserts at the start and end of each function, which python -O
removes. The refused transfer is an exception caught around it; PatLang runs
it in a world, so whatever the failing code had done (files, facts, output)
would go with it too.

Where the PatLang program says the world stopped, this one names the
exception; its expected output is showcase/compare/expected/c1_budget_sheet.txt.
"""
from fractions import Fraction
from math import floor


class Line:
    def __init__(self, budget, name, amount):
        self.budget, self.name, self.amount = budget, name, amount

    def set(self, v):
        self.amount = v
        for f in self.budget.on_change:
            f(self)
        return v


class Budget:
    def __init__(self):
        self.lines, self.total, self.changes, self.on_change = [], 0, 0, []


def add_line(b, name, amount):
    line = Line(b, name, Fraction(amount))
    b.lines.append(line)
    b.total += line.amount
    return line


def line(b, name):
    for l in b.lines:
        if l.name == name:
            return l
    raise KeyError(name)


def sum_lines(b):
    return sum((l.amount for l in b.lines), Fraction(0))


def transfer(b, frm, to, amount):
    assert amount > 0
    before = sum_lines(b)
    line(b, frm).set(line(b, frm).amount - amount)
    line(b, to).set(line(b, to).amount + amount)
    total = sum_lines(b)
    assert total == before
    return total


def split(b, frm, into):
    assert len(into) > 0
    amount = line(b, frm).amount
    share = amount / len(into)
    before = sum_lines(b)
    line(b, frm).set(0)
    for name in into:
        line(b, name).set(line(b, name).amount + share)
    assert share * len(into) == amount and sum_lines(b) == before
    return share


def show_num(x):
    x = Fraction(x)
    return str(x.numerator) if x.denominator == 1 else str(x)


def money(x):
    pennies = floor(Fraction(x) * 100 + Fraction(1, 2))
    return f"{pennies // 100}.{pennies % 100:02d}"


def show(b):
    for l in b.lines:
        print(f"  {l.name}: {money(l.amount)}  (exactly {show_num(l.amount)})")
    print(f"  total {money(b.total)}, after {b.changes} changes")


budget = Budget()


def on_change(_line):
    budget.changes += 1
    budget.total = sum_lines(budget)


budget.on_change.append(on_change)
for name, amount in [("rent", 900), ("food", 300), ("savings", 100), ("fun", 0), ("gifts", 0), ("repairs", 0)]:
    add_line(budget, name, amount)

print("== the budget ==")
show(budget)
print("== 50 moved from food to fun ==")
transfer(budget, "food", "fun", 50)
show(budget)
print("== savings split three ways ==")
share = split(budget, "savings", ["fun", "gifts", "repairs"])
print(f"  each share is {show_num(share)}, and three shares are {show_num(share * 3)}")
show(budget)
print("== a transfer of -20, tried in a world of its own ==")
try:
    transfer(budget, "fun", "food", -20)
    outcome = "finished"
except AssertionError:
    outcome = "raised AssertionError"
print(f"  the try {outcome}; the total is still {money(sum_lines(budget))}, after {budget.changes} changes")
