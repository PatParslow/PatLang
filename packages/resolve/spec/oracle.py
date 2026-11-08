"""Reference for packages/resolve's features; run as `py -3 -I oracle.py ...`.

  gen N SEED DIR [tight]     write a universe of N packages p0..p<N-1> to DIR
  resolve DIR NAME [CONS]    resolve NAME (CONS like ">= 0.1.0, < 0.2.0", or "any")
                             and print what the PatLang resolver prints
  check DIR NAME OUTFILE     check a "resolved ..." line in OUTFILE against DIR's
                             manifests: the request and every chosen version's
                             dependencies are chosen and meet every constraint
  orders DIR FACTSFILE       check FACTSFILE's version_order lines: one per ordered
                             pair of DIR's versions and bounds, each correct

The resolver here is written without logic programming, from the same
description: a breadth-first agenda of packages from the request, each
given the newest version every requirer accepts, backtracking on failure,
and the first conflict met reported.
"""
import hashlib
import os
import random
import sys

OPS = {"=": "eq", ">=": "ge", ">": "gt", "<=": "le", "<": "lt"}
OP_TEXT = {v: k for k, v in OPS.items()}


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def holds(ver, op, bound):
    a, b = vkey(ver), vkey(bound)
    return {"eq": a == b, "ge": a >= b, "gt": a > b, "le": a <= b, "lt": a < b}[op]


def parse_constraints(text):
    out = []
    for part in text.split(","):
        part = part.strip()
        i = 0
        while i < len(part) and part[i] in "<>=":
            i += 1
        out.append((OPS[part[:i]], part[i:].strip()))
    return out


def read_universe(d):
    """{(name, version): [(dep, [(op, bound)...]), ...]} in manifest order."""
    univ = {}
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".pkg"):
            continue
        name = ver = None
        deps = []
        with open(os.path.join(d, fn), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                key, _, val = line.partition(" ")
                val = val.strip()
                if key == "package":
                    name = val
                elif key == "version":
                    ver = val
                elif key == "depends":
                    dep, _, rest = val.partition(" ")
                    deps.append((dep, parse_constraints(rest)))
        univ[(name, ver)] = deps
    return univ


def resolve(univ, name, cons):
    names = sorted({n for n, _ in univ})
    versions = {n: sorted([v for m, v in univ if m == n], key=vkey, reverse=True) for n in names}
    assigned = {}
    queued = set()
    reqs = {n: [] for n in names}
    agenda = []
    conflict = [None]
    root = [(name, cons if cons else [("ge", "0.0.0")])]

    def deps_of(p, v):
        return root if p == "@request" else univ[(p, v)]

    def record(dep, requirers):
        if conflict[0] is None:
            conflict[0] = (dep, list(requirers))

    def add_deps(p, v, trail):
        for dep, cs in deps_of(p, v):
            if dep not in versions:
                record(dep, [(p, v)])
                return False
            ok = [i for i, dv in enumerate(versions[dep]) if all(holds(dv, o, b) for o, b in cs)]
            reqs[dep].append((p, v, ok))
            trail.append(("req", dep))
            if dep in assigned:
                if assigned[dep] not in ok:
                    record(dep, [(r[0], r[1]) for r in reqs[dep]])
                    return False
            elif dep not in queued:
                queued.add(dep)
                agenda.append(dep)
                trail.append(("queue", dep))
        return True

    def undo(trail):
        for kind, dep in reversed(trail):
            if kind == "req":
                reqs[dep].pop()
            elif kind == "queue":
                queued.discard(dep)
                agenda.pop()

    def search(pos):
        if pos >= len(agenda):
            return True
        d = agenda[pos]
        cands = [i for i in range(len(versions[d])) if all(i in r[2] for r in reqs[d])]
        if not cands:
            record(d, [(r[0], r[1]) for r in reqs[d]])
            return False
        for c in cands:
            assigned[d] = c
            trail = []
            if add_deps(d, versions[d][c], trail) and search(pos + 1):
                return True
            undo(trail)
            del assigned[d]
        return False

    trail = []
    if add_deps("@request", "0.0.0", trail) and search(0):
        return "resolved " + ", ".join(f"{n} {versions[n][assigned[n]]}" for n in names if n in assigned)
    dep, requirers = conflict[0]
    lines = [f"conflict {dep}"]
    for p, v in requirers:
        cs = dict(deps_of(p, v))[dep]
        who = "the request" if p == "@request" else f"{p} {v}"
        lines.append(f"requirer {who}: " + ", ".join(f"{OP_TEXT[o]} {b}" for o, b in cs))
    avail = versions.get(dep, [])
    lines.append("available " + (", ".join(avail) if avail else "none"))
    return "\n".join(lines)


def gen(n, seed, d, tight):
    rng = random.Random(seed)
    pool = [f"{a}.{b}.{c}" for a in range(2) for b in range(5) for c in range(2)]
    os.makedirs(d, exist_ok=True)
    for fn in os.listdir(d):
        if fn.endswith(".pkg"):
            os.remove(os.path.join(d, fn))
    # Unless tight, each package has a witness version that every constraint
    # on it admits, so the witnesses together are a solution and the universe
    # resolves (often to newer versions than the witnesses).
    vers = []
    witness = []
    for i in range(n):
        vs = sorted(rng.sample(pool, rng.randint(1, 4)), key=vkey)
        vers.append(vs)
        witness.append(rng.choice(vs))
        for v in vs:
            deps = []
            if i > 0:
                others = list(range(max(0, i - 8), i - 1))
                picks = [i - 1] + rng.sample(others, min(len(others), rng.randint(0, 2)))
                for j in picks:
                    w = witness[j]
                    if tight:
                        lo = rng.choice(vers[j])
                        higher = [x for x in vers[j] if vkey(x) > vkey(lo)]
                    else:
                        lo = rng.choice([x for x in vers[j] if vkey(x) <= vkey(w)])
                        higher = [x for x in vers[j] if vkey(x) > vkey(w)]
                    cs = [f">= {lo}"]
                    if higher and rng.random() < (0.5 if tight else 0.3):
                        cs.append(f"< {rng.choice(higher)}")
                    deps.append(f"p{j} " + ", ".join(cs))
            name = f"p{i}"
            lines = [f"package {name}", f"version {v}", f"entry {name}.patlang", f"include {name}.patlang"]
            lines += [f"depends {x}" for x in deps]
            lines.append(f"file {name}.patlang sha256 " + hashlib.sha256((name + v).encode()).hexdigest())
            with open(os.path.join(d, f"{name}-{v}.pkg"), "w", newline="\n", encoding="ascii") as f:
                f.write("\n".join(lines) + "\n")
    print("ok")


def check(d, name, outfile):
    univ = read_universe(d)
    with open(outfile, encoding="utf-8") as f:
        first = f.readline().strip()
    if not first.startswith("resolved "):
        print("not resolved: " + first)
        return
    chosen = dict(x.split(" ") for x in first[len("resolved "):].split(", "))
    if name not in chosen:
        print("request not chosen")
        return
    for p, v in chosen.items():
        if (p, v) not in univ:
            print(f"{p} {v} is not in the universe")
            return
        for dep, cs in univ[(p, v)]:
            if dep not in chosen:
                print(f"{p} {v} needs {dep}, not chosen")
                return
            for o, b in cs:
                if not holds(chosen[dep], o, b):
                    print(f"{dep} {chosen[dep]} fails {p} {v}'s {OP_TEXT[o]} {b}")
                    return
    print("ok")


def orders(d, factsfile):
    univ = read_universe(d)
    known = set()
    for (p, v), deps in univ.items():
        known.add(v)
        for _, cs in deps:
            known.update(b for _, b in cs)
    want = set()
    for a in known:
        for b in known:
            o = "lt" if vkey(a) < vkey(b) else ("gt" if vkey(a) > vkey(b) else "eq")
            want.add(f"version_order {a} {b} {o}")
    with open(factsfile, encoding="utf-8") as f:
        got = [l.strip() for l in f if l.startswith("version_order ")]
    if len(got) != len(set(got)):
        print("duplicate version_order facts")
    elif set(got) != want:
        extra = sorted(set(got) - want)[:1]
        missing = sorted(want - set(got))[:1]
        print(f"differs: extra {extra} missing {missing}")
    else:
        print(f"ok {len(got)}")


def main(a):
    if a[0] == "gen":
        gen(int(a[1]), int(a[2]), a[3], len(a) > 4 and a[4] == "tight")
    elif a[0] == "resolve":
        cons = a[3] if len(a) > 3 and a[3] != "any" else ""
        print(resolve(read_universe(a[1]), a[2], parse_constraints(cons) if cons else []))
    elif a[0] == "check":
        check(a[1], a[2], a[3])
    elif a[0] == "orders":
        orders(a[1], a[2])
    else:
        raise SystemExit("unknown command " + a[0])


if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    main(sys.argv[1:])
