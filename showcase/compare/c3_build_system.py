"""The build system of showcase/c3_build_system.patlang, in Python.

The dependencies are a dict, and "needs, directly or not" is a recursive
generator, which Python writes as briefly as the two rules the PatLang
program has; a query the other way ("what needs util?") would be another
function, where the rules answer it as they stand. The waves run on a
process pool (threads would not run the checksums in parallel). The record
of what is built is a file of lines, appended and flushed after each target,
which the next run reads back: Python has no durable queue in its standard
library, and this is the usual substitute.

Prints the same lines as the PatLang program.
"""
import os
import tempfile
from concurrent.futures import ProcessPoolExecutor

DEPENDS = {"app": ["ui", "core", "net"], "ui": ["core"], "net": ["core"], "core": ["util"], "tests": ["app", "util"]}
TARGETS = ["util", "core", "net", "ui", "app", "tests"]
RECORD = os.path.join(tempfile.gettempdir(), "showcase_c3_built.txt")


def needs(t):
    """What t needs, in the order the PatLang rules give it: direct first."""
    yield from DEPENDS.get(t, [])
    for x in DEPENDS.get(t, []):
        yield from needs(x)


def ready(built):
    return [t for t in TARGETS if t not in built and all(d in built for d in DEPENDS.get(t, []))]


def checksum(text):
    c = 0
    for i, byte in enumerate(text.encode(), start=1):
        c = (c + byte * i) % 9973
    return c


def build_one(job):
    target, dep_sums = job
    return target, checksum(target + ":" + ",".join(dep_sums))


def sums_on_disk():
    if not os.path.exists(RECORD):
        return []
    with open(RECORD) as f:
        return [(t, int(c)) for t, c in (line.split() for line in f)]


def build(pool, sums, stop_after_waves):
    built = [t for t, _ in sums]
    wave = 0
    while True:
        todo = ready(built)
        if not todo:
            if wave == 0:
                print("  nothing to build: every target is up to date")
            return built
        if wave == stop_after_waves:
            print("  interrupted before building " + ", ".join(todo))
            return built
        jobs = [(t, [str(c) for d in DEPENDS.get(t, []) for n, c in sums if n == d]) for t in todo]
        for target, c in pool.map(build_one, jobs):
            with open(RECORD, "a") as f:
                f.write(f"{target} {c}\n")
                f.flush()
                os.fsync(f.fileno())
            sums.append((target, c))
            built.append(target)
        print(f"  wave {wave + 1}: built " + ", ".join(todo))
        wave += 1


if __name__ == "__main__":
    if os.path.exists(RECORD):
        os.remove(RECORD)
    names = []
    for d in needs("app"):
        if d not in names:
            names.append(d)
    print("== what app needs, directly or not ==")
    print("  " + ", ".join(names))
    with ProcessPoolExecutor() as pool:
        print("== a build, interrupted after two waves ==")
        build(pool, sums_on_disk(), 2)
        print(f"  recorded on disk: {len(sums_on_disk())} targets")
        print("== the build run again: it starts from what is on disk ==")
        build(pool, sums_on_disk(), -1)
        everything = sums_on_disk()
        print(f"  recorded on disk: {len(everything)} targets")
        print("  checksums: [" + ", ".join(f"[{t}, {c}]" for t, c in everything) + "]")
        print("== and once more, with nothing left to do ==")
        build(pool, sums_on_disk(), -1)
    os.remove(RECORD)
