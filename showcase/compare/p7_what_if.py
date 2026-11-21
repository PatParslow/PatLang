"""The what-if catalogue of showcase/p7_what_if.patlang, in Python.

The facts are a list of (course, prerequisite) pairs, and "before" is a
transitive closure written as a function. Each proposal is tried on a copy of
the list, and a broken rule is an exception caught around the try. That
isolates the data and the failure. A PatLang world isolates more: its facts,
its files and its output, so code that writes a file or prints inside a world
leaves nothing behind. Python gets that only from a separate process.

Where the PatLang program says its world stopped with code 3, this one names
the exception; its expected output is showcase/compare/expected/p7_what_if.txt.
"""
import copy

CATALOGUE = [
    ("algorithms", "programming"),
    ("databases", "programming"),
    ("compilers", "algorithms"),
    ("compilers", "theory"),
    ("theory", "discrete_maths"),
]


def all_before(needs, course):
    """What course needs, directly or not, each once, in the order found."""
    found = []
    todo = [course]
    while todo:
        at = todo.pop(0)
        for a, b in needs:
            if a == at and b not in found:
                found.append(b)
                todo.append(b)
    return found


def course_in_cycle(needs):
    for start, _ in needs:
        seen, todo = [], [start]
        while todo:
            at = todo.pop(0)
            for a, b in needs:
                if a == at:
                    if b == start:
                        return start
                    if b not in seen:
                        seen.append(b)
                        todo.append(b)
    return ""


def try_change(needs, added):
    trial = copy.deepcopy(needs) + added
    looped = course_in_cycle(trial)
    if looped:
        return ["a course needs itself: " + looped]
    assert len(all_before(trial, "compilers")) <= 4
    return []


print("== the catalogue ==")
print("compilers needs, directly or not: [" + ", ".join(all_before(CATALOGUE, "compilers")) + "]")
print("== proposals, each in its own world ==")
proposals = [
    ("databases needs algorithms", [("databases", "algorithms")]),
    ("programming needs compilers", [("programming", "compilers")]),
    ("discrete_maths needs databases", [("discrete_maths", "databases")]),
]
for name, added in proposals:
    try:
        problems = try_change(CATALOGUE, added)
    except AssertionError:
        print(f"{name}: stopped inside its try (AssertionError), the program carries on")
        continue
    print(f"{name}: fine" if not problems else f"{name}: refused, " + "; ".join(problems))
print("== the program's catalogue afterwards ==")
print("does programming need compilers here? " + ("true" if ("programming", "compilers") in CATALOGUE else "false"))
print("compilers needs, directly or not: [" + ", ".join(all_before(CATALOGUE, "compilers")) + "]")
