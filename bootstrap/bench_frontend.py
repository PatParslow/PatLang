#!/usr/bin/env python3
"""Benchmarks compiled (ir_to_py.py output) vs tree-walking (bootstrap_
interp.py) lexing+parsing+lowering of a real, large input -- the self-
hosted compiler's own bundled source -- for GitHub #196."""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootstrap_interp as interp
import frontend_compiled as compiled

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(os.path.dirname(__file__), "frontend.ir"), "r", encoding="utf-8") as f:
    IR = json.loads(f.read(), strict=False)
FUNCS = IR[2]

with open(os.path.join(ROOT, "self_hosting", "build", "patc1_all.patlang"), "r", encoding="utf-8", newline="") as f:
    SRC = f.read()

print("input: %d chars" % len(SRC))


def run_interp(fname, args, state):
    callee = interp.find_func(FUNCS, fname)
    return interp.run_function(FUNCS, callee, args, state)


def run_compiled(fname, args, state):
    return compiled.FUNCS[fname](args, state)


def time_pipeline(run, label):
    state = interp.HostState([], FUNCS)
    t0 = time.time()
    toks = run("tokenize", [SRC], state)
    t1 = time.time()
    ast = run("parse_program", [toks], state)
    t2 = time.time()
    ir = run("lower_program", [ast], state)
    t3 = time.time()
    print("%s: tokenize=%.2fs parse_program=%.2fs lower_program=%.2fs total=%.2fs" % (
        label, t1 - t0, t2 - t1, t3 - t2, t3 - t0))
    return t3 - t0


# Tree-walking is confirmed (this session) to process on the order of
# tens of millions of instructions per MINUTE even on a small input --
# on 1.8MB of real source this would take a genuinely long time (the
# whole motivation for #196), so only time it with an explicit opt-in,
# not by default.
if "--interp" in sys.argv:
    t_interp = time_pipeline(run_interp, "interp (tree-walking)")
else:
    t_interp = None
    print("skipping tree-walking timing (pass --interp to include it -- expect many minutes)")

t_compiled = time_pipeline(run_compiled, "compiled (basic-block Python)")

if t_interp:
    print("speedup: %.1fx" % (t_interp / t_compiled))
