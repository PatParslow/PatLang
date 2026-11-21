"""The loan schedule of showcase/p1_loan_schedule.patlang, in Python.

Python does this well: fractions.Fraction is exact, and decimal.Decimal rounds
money the way banks do. The differences are where exactness comes from (an
import and a constructor at each literal, where PatLang's 6/100 is already
exact) and what a contract is (an assert, removed by python -O, where PatLang's
ensure is part of the function and can be kept in a build).

Prints the same lines as the PatLang program.
"""
from decimal import Decimal
from fractions import Fraction
from math import floor


def monthly_payment(principal, yearly_rate, months):
    assert principal > 0 and months > 0
    r = yearly_rate / 12
    growth = (1 + r) ** months
    payment = principal * r * growth / (growth - 1)
    assert payment * months > principal
    return payment


def exact_balance_after(principal, yearly_rate, months):
    r = yearly_rate / 12
    payment = monthly_payment(principal, yearly_rate, months)
    balance = principal
    for _ in range(months):
        balance = balance + balance * r - payment
    assert balance == 0
    return balance


def nearest(x):
    return floor(x + Fraction(1, 2))


def money(pennies):
    return f"{pennies // 100}.{pennies % 100:02d}"


def decimal(x, places):
    scale = 10 ** places
    n = nearest(x * scale)
    return f"{n // scale}.{n % scale:0{places}d}"


def print_schedule(principal, yearly_rate, months):
    r = yearly_rate / 12
    payment = nearest(monthly_payment(principal, yearly_rate, months) * 100)
    balance = principal * 100
    total_paid = total_interest = 0
    for m in range(1, months + 1):
        interest = nearest(balance * r)
        pay = balance + interest if m == months else payment
        balance = balance + interest - pay
        total_paid += pay
        total_interest += interest
        print(f"  month {m}: interest {money(interest)}, paid {money(pay)}, owed {money(balance)}")
    print(f"  paid {money(total_paid)} in all, of which interest {money(total_interest)}")
    assert balance == 0 and total_paid == principal * 100 + total_interest
    return total_paid


def float_balance_after(principal, yearly_rate, months):
    r = yearly_rate / 12.0
    growth = 1.0
    for _ in range(months):  # as the PatLang program does, so the floats match
        growth = growth * (1.0 + r)
    payment = principal * r * growth / (growth - 1.0)
    balance = principal
    for _ in range(months):
        balance = balance + balance * r - payment
    return balance


principal = 10000
rate = Fraction(6, 100)
months = 12

def b(x):
    """A bool as PatLang prints one."""
    return "true" if x else "false"


print("== the rate ==")
print(f"6/100 is {rate}, a rational")
print(f"1/10 + 2/10 == 3/10: {b(Fraction(1, 10) + Fraction(2, 10) == Fraction(3, 10))}")
print(f"0.1 + 0.2 == 0.3: {b(0.1 + 0.2 == 0.3)}")

print("== the exact payment ==")
exact = monthly_payment(principal, rate, months)
print(f"monthly payment, to 12 places: {decimal(exact, 12)}")
print(f"owed after 12 exact payments: {exact_balance_after(principal, rate, months)}")

print("== the schedule, in pennies ==")
print_schedule(principal, rate, months)

print("== the same in floats ==")
left = float_balance_after(10000.0, 0.06, 12)
# PatLang prints a float's shortest round-trip digits without an exponent
print(f"owed after 12 float payments: {format(Decimal(repr(left)), 'f')}")
print(f"is it zero? {b(left == 0.0)}")
