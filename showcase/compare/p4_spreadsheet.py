"""The spreadsheet of showcase/p4_spreadsheet.patlang, in Python.

Python has no events in the language, so the cells carry an observer list
and each edit calls the observers itself: set and redefine each end with a
call to self._announce. The PatLang Cell's methods say "raises changed" in
their declarations and contain no such call. Exact values come from
fractions.Fraction, which Python does well; the literals need wrapping
(Fraction(125, 12)), where PatLang's 125 / 12 is already exact.

Prints the same lines as the PatLang program.
"""
from fractions import Fraction


class Events:
    """A minimal event bus: what `when` and `emit` give the PatLang program."""

    def __init__(self):
        self.handlers = {}

    def when(self, name, f):
        self.handlers.setdefault(name, []).append(f)

    def emit(self, name, data):
        for f in self.handlers.get(name, []):
            f(data)


class Cell:
    def __init__(self, events, name, value):
        self.events, self.name, self.value = events, name, value
        self.inputs, self.formula = [], None

    def _announce(self, *data):
        self.events.emit("changed", [self, *data])

    def set(self, v):
        self.value = v
        self._announce(v, v)
        return v

    def redefine(self, inputs, f):
        self.old_inputs, self.old_formula = self.inputs, self.formula
        self.inputs, self.formula = inputs, f
        self._announce(inputs, f, self.value)
        return self.value

    def undo_redefine(self):
        self.inputs, self.formula = self.old_inputs, self.old_formula
        return self.value


def fmt(x):
    """A value as PatLang prints it: a whole fraction as an int."""
    if isinstance(x, Fraction) and x.denominator == 1:
        return str(x.numerator)
    return str(x)


class Sheet:
    def __init__(self, events):
        self.events, self.cells = events, []

    def find(self, name):
        for c in self.cells:
            if c.name == name:
                return c
        raise KeyError(name)

    def cell(self, name, value):
        c = Cell(self.events, name, value)
        self.cells.append(c)
        return c

    def recompute(self, c):
        c.value = c.formula([self.find(n).value for n in c.inputs])
        return c.value

    def formula_cell(self, name, inputs, f):
        c = self.cell(name, 0)
        c.inputs, c.formula = inputs, f
        self.recompute(c)
        return c

    def visit(self, name, done, order, path):
        for c in self.cells:
            if name in c.inputs:
                if c.name in path:
                    return path + [c.name]
                if c.name not in done:
                    cycle = self.visit(c.name, done, order, path + [c.name])
                    if cycle:
                        return cycle
        done.append(name)
        order.append(name)
        return []

    def recalc(self, name):
        done, order = [], []
        cycle = self.visit(name, done, order, [name])
        if cycle:
            self.find(name).undo_redefine()
            self.events.emit("cycle", cycle)
            return cycle
        names = []
        for n in reversed(order):
            c = self.find(n)
            if c.inputs:
                self.recompute(c)
                names.append(f"{c.name}={fmt(c.value)}")
        self.events.emit("recalculated", names)
        return names

    def show(self):
        return "  ".join(f"{c.name}={fmt(c.value)}" for c in self.cells)


events = Events()
sheet = Sheet(events)
audit = []

def record(d):
    """d is the cell, the method's arguments, then its result."""
    if len(d) == 3:
        audit.append(f"{d[0].name} set to {fmt(d[1])}")
    else:
        audit.append(f"{d[0].name} given a formula over {', '.join(d[1])}")


events.when("changed", record)
events.when("changed", lambda d: sheet.recalc(d[0].name))
events.when("recalculated", lambda names: print("  recalculated: " + ", ".join(names)))
events.when("cycle", lambda path: print("  refused, a cycle: " + " -> ".join(path)))

net = sheet.cell("net", Fraction(10))
vat = sheet.formula_cell("vat", ["net"], lambda v: v[0] / 5)
gross = sheet.formula_cell("gross", ["net", "vat"], lambda v: v[0] + v[1])
share = sheet.formula_cell("share", ["gross"], lambda v: v[0] / 3)

print("== the sheet ==")
print(sheet.show())

print("== net set to 125/12 ==")
net.set(Fraction(125, 12))
print(sheet.show())

print("== VAT changed to a sixth ==")
vat.redefine(["net"], lambda v: v[0] / 6)
print(sheet.show())

print("== net redefined from share: a cycle ==")
net.redefine(["share"], lambda v: v[0] * 2)
print(sheet.show())

print("== net set to 20: the refused formula is gone, so this recalculates ==")
net.set(Fraction(20))
print(sheet.show())

print("== the audit trail, every edit asked for ==")
print("\n".join(audit))
