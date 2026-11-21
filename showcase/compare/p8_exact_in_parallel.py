"""The exact parallel sums of showcase/p8_exact_in_parallel.patlang, in Python.

Python has exact fractions (fractions.Fraction) and arbitrary-size integers,
and its Fraction addition is the same algorithm as PatLang's (it reduces by
the gcd of the denominators first). The difference is the parallelism: a
thread does not run Python code in parallel while another holds the
interpreter lock, so the sketch uses a process pool, which sends each range
to another process and each partial sum back, pickled. PatLang's parallel_map
runs the ranges on threads that share the program's memory.

Prints the same lines as the PatLang program.
"""
from fractions import Fraction
from multiprocessing import Pool


def partial_sum(rng):
    lo, hi = rng
    s = Fraction(0)
    for k in range(lo, hi):
        s += Fraction(1, k)
    return s


def partial_sum_float(rng):
    lo, hi = rng
    s = 0.0
    for k in range(lo, hi):
        s += 1.0 / k
    return s


def split(n, parts):
    return [(1 + n * p // parts, 1 + n * (p + 1) // parts) for p in range(parts)]


def total(items):
    s = items[0]
    for x in items[1:]:
        s += x
    return s


def b(x):
    return "true" if x else "false"


if __name__ == "__main__":
    n = 3000
    parts = [1, 2, 4, 8]
    with Pool(8) as pool:
        print(f"== H({n}) exactly ==")
        answers = []
        for p in parts:
            h = total(pool.map(partial_sum, split(n, p)))
            answers.append(h)
            print(f"split into {p}: a fraction whose numerator has {len(str(h.numerator))} digits")
        print(f"all four splits give the same fraction: {b(all(a == answers[0] for a in answers))}")
        print(f"H({n}) is about {float(answers[0])!r}")
        print("== the same sums in floats ==")
        floats = []
        for p in parts:
            f = total(pool.map(partial_sum_float, split(n, p)))
            floats.append(f)
            print(f"split into {p}: {f!r}")
        print(f"all four float splits agree: {b(all(f == floats[0] for f in floats))}")
