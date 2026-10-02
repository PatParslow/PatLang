#!/usr/bin/env python3
"""Compares patc1_all_compiled.py (GitHub #196, compiled, full bundle)
against bootstrap_interp.py's own run_function (tree-walking, already
verified this session) on the SAME patc1_all.ir, running the compiler's
own `main` with a few different argv -- starting with `lower` alone
(fast: no codegen_x64/asm/link), before attempting the slow `--x64` path."""
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootstrap_interp as interp
import patc1_all_compiled as compiled

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(os.path.dirname(__file__), "patc1_all.ir"), "r", encoding="utf-8") as f:
    IR = json.loads(f.read(), strict=False)
FUNCS = IR[2]
ENTRY = IR[1]


def run_one(run_main_entry, argv, tmp_out, label):
    if os.path.exists(tmp_out):
        os.remove(tmp_out)
    os.chdir(ROOT)
    state = interp.HostState(argv, FUNCS)
    t0 = time.time()
    run_main_entry(argv, state)
    elapsed = time.time() - t0
    produced = os.path.exists(tmp_out)
    content = None
    if produced:
        with open(tmp_out, "r", encoding="utf-8", newline="") as f:
            content = f.read()
    print("%s: %.2fs, produced=%s, len=%s" % (label, elapsed, produced, len(content) if content else None))
    return content


def interp_entry(argv, state):
    callee = interp.find_func(FUNCS, ENTRY)
    return interp.run_function(FUNCS, callee, argv, state)


def compiled_entry(argv, state):
    return compiled.FUNCS[ENTRY](argv, state)


tmp_patlang = "bootstrap/_patc1_test_tmp.patlang"
with open(os.path.join(ROOT, tmp_patlang), "w", encoding="utf-8", newline="\n") as f:
    f.write(open(os.path.join(ROOT, "bootstrap", "hello_bootstrap.patlang"), "r", encoding="utf-8", newline="").read())

out_interp = "bootstrap/_patc1_test_interp.ir"
out_compiled = "bootstrap/_patc1_test_compiled.ir"

c1 = run_one(interp_entry, ["lower", tmp_patlang, out_interp], os.path.join(ROOT, out_interp), "interp lower")
c2 = run_one(compiled_entry, ["lower", tmp_patlang, out_compiled], os.path.join(ROOT, out_compiled), "compiled lower")

ok = c1 is not None and c2 is not None and c1 == c2
print("MATCH:", ok)
if not ok:
    print("interp[:300] =", repr(c1)[:300] if c1 else None)
    print("compiled[:300] =", repr(c2)[:300] if c2 else None)

for p in (tmp_patlang, out_interp, out_compiled):
    full = os.path.join(ROOT, p)
    if os.path.exists(full):
        os.remove(full)

sys.exit(0 if ok else 1)
