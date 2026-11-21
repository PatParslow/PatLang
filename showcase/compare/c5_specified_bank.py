"""The specified bank account of showcase/c5_specified_bank.patlang, in Python.

The PatLang program states the account as a schema (state, invariants,
operations with preconditions and effects) and hands it to an explorer in
its library, which visits every reachable state. Python has no such library
in its standard distribution, so the sketch writes the explorer for this one
schema: a breadth-first search over balances, the operations as functions,
the invariants checked after each step. Tools for this exist outside Python:
TLA+ and its model checker, or Alloy, each with a language of its own. The
implementation and its Gherkin feature then follow as in the PatLang program,
with asserts for its require and ensure clauses and a step matcher written
with re.

Prints the same lines as the PatLang program.
"""
import re
from collections import deque
from fractions import Fraction

AMOUNTS = [20, 50]
INVARIANTS = [("balance >= 0", lambda b: b >= 0), ("balance <= 100", lambda b: b <= 100)]


def operations(checked):
    """(name, enabled(balance, amount), effect(balance, amount))"""
    return [
        ("Deposit", lambda b, a: b + a <= 100, lambda b, a: b + a),
        ("Withdraw", (lambda b, a: b >= a) if checked else (lambda b, a: True), lambda b, a: b - a),
    ]


def explore(label, checked):
    print(f"== {label} ==")
    seen, transitions = {0: []}, 0
    todo = deque([0])
    while todo:
        b = todo.popleft()
        for name, enabled, effect in operations(checked):
            for a in AMOUNTS:
                if not enabled(b, a):
                    continue
                transitions += 1
                nb = effect(b, a)
                path = seen[b] + [(name, a)]
                for text, holds in INVARIANTS:
                    if not holds(nb):
                        print(f"  {name} reaches a state that breaks an invariant: {text}")
                        for i, (op, arg) in enumerate(path, start=1):
                            print(f"    step {i}: {op} with {{{arg}}}")
                        return
                if nb not in seen:
                    seen[nb] = path
                    todo.append(nb)
    print(f"  Explored every reachable state: {len(seen)} states, {transitions} transitions. No invariant or postcondition was violated.")


class Account:
    def __init__(self):
        self.balance = Fraction(0)

    def deposit(self, amount):
        assert amount > 0 and self.balance + amount <= 100
        before = self.balance
        self.balance += amount
        assert self.balance == before + amount and 0 <= self.balance <= 100
        return self.balance

    def withdraw(self, amount):
        assert amount > 0 and self.balance >= amount
        before = self.balance
        self.balance -= amount
        assert self.balance == before - amount and self.balance >= 0
        return self.balance


def show(x):
    return str(x.numerator) if x.denominator == 1 else str(x)


explore("the first schema: withdrawal unchecked", False)
explore("the corrected schema", True)

print("== the implementation, against its feature ==")
FEATURE = """Feature: an account

  Scenario: deposits add up exactly
    Given a new account
    When 20 is deposited
    And 101/4 is deposited
    Then the balance is 181/4

  Scenario: a withdrawal takes away exactly what was asked
    Given a new account
    When 50 is deposited
    And 1/3 is withdrawn
    Then the balance is 149/3"""

passed = failed = 0
ctx = {}


def st_balance(want):
    global passed, failed
    got = show(ctx["account"].balance)
    if got == want:
        passed += 1
        print("  ok: the balance")
    else:
        failed += 1
        print(f"  FAIL: the balance (got {got}, want {want})")


STEPS = [
    (r"a new account", lambda: ctx.__setitem__("account", Account())),
    (r"(\S+) is deposited", lambda n: ctx["account"].deposit(Fraction(n))),
    (r"(\S+) is withdrawn", lambda n: ctx["account"].withdraw(Fraction(n))),
    (r"the balance is (\S+)", st_balance),
]

for line in FEATURE.splitlines():
    line = line.strip()
    if line.startswith(("Feature:", "Scenario:")):
        print(line)
        continue
    words = line.split(" ", 1)
    if len(words) == 2 and words[0] in ("Given", "When", "Then", "And"):
        for pattern, f in STEPS:
            m = re.fullmatch(pattern, words[1])
            if m:
                f(*m.groups())
                break
print(f"tests: {passed} passed, {failed} failed")
print("ALL TESTS PASSED" if failed == 0 else "TESTS FAILED")
