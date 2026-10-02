#!/usr/bin/env python3
"""
build_frontend_ir.py -- bundles self_hosting/lib/{lexer,parser,lower}.patlang
(expanding each file's own `include` lines relative to ITS OWN directory,
same fix as build_patc1.patlang's own bundling got this session) and lowers
the result to IR via the real patc1.exe, for GitHub #196's own first step:
a Python-compiled (not tree-walked) version of just the compiler's frontend.

Run from the repo root:
    python bootstrap/build_frontend_ir.py
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BUNDLE = [
    "self_hosting/lib/lexer.patlang",
    "self_hosting/lib/parser.patlang",
    "self_hosting/lib/lower.patlang",
]


def expand_includes(text, base_dir, depth=0):
    if depth > 16:
        return text
    out = []
    for line in text.splitlines():
        t = line.strip()
        if t.startswith("include ") and not t.startswith("#"):
            rel = t[len("include "):].strip().strip('"')
            path = os.path.normpath(os.path.join(base_dir, rel))
            with open(path, "r", encoding="utf-8", newline="") as f:
                inner = f.read()
            out.append(expand_includes(inner, os.path.dirname(path), depth + 1))
        else:
            out.append(line)
    return "\n".join(out) + "\n"


def main():
    pieces = []
    for rel in BUNDLE:
        path = os.path.join(ROOT, rel)
        with open(path, "r", encoding="utf-8", newline="") as f:
            raw = f.read()
        pieces.append(expand_includes(raw, os.path.dirname(path)))
    src = "\n".join(pieces)
    bundle_path = os.path.join(ROOT, "bootstrap", "frontend_bundle.patlang")
    with open(bundle_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print("wrote %s (%d chars)" % (bundle_path, len(src)))

    ir_path = os.path.join(ROOT, "bootstrap", "frontend.ir")
    if os.path.exists(ir_path):
        os.remove(ir_path)
    patc1 = os.path.join(ROOT, "patc1.exe")
    result = subprocess.run(
        [patc1, "lower", "bootstrap/frontend_bundle.patlang", "bootstrap/frontend.ir"],
        cwd=ROOT, capture_output=True, text=True,
    )
    print(result.stdout)
    print(result.stderr, file=sys.stderr)
    if not os.path.exists(ir_path):
        print("FAILED: frontend.ir was not produced")
        sys.exit(1)
    print("wrote %s" % ir_path)


if __name__ == "__main__":
    main()
