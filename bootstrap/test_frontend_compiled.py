#!/usr/bin/env python3
"""Compares frontend_compiled.py (GitHub #196, compiled) against
bootstrap_interp.py's own run_function (GitHub #25 Piece 2, tree-walking,
already independently verified this session) on the SAME IR, for a set
of increasingly complex PatLang source snippets -- RED/GREEN per this
project's own BDD discipline, just expressed as a direct comparison
rather than hand-written expected values, since the tree-walking
interpreter is itself already a trusted oracle for this exact IR."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bootstrap_interp as interp
import frontend_compiled as compiled

with open(os.path.join(os.path.dirname(__file__), "frontend.ir"), "r", encoding="utf-8") as f:
    IR = json.loads(f.read(), strict=False)
FUNCS = IR[2]

CASES = [
    "let x = 1 + 2\nprint(x)\n",
    "let s = \"hello\" + \" \" + \"world\"\nprint(s)\n",
    "let n = 0\nwhile n < 5 do\n  let n = n + 1\nend\nprint(n)\n",
    "if 3 > 2 then\n  print(\"yes\")\nelse\n  print(\"no\")\nend\n",
    "make a function called add takes a, b returns r\n  return a + b\nend\nprint(add(3, 4))\n",
    "let f = |x| do\n  return x * 2\nend\nprint(f(21))\n",
    "let xs = [1, 2, 3]\nprint(xs)\n",
]


def run_interp(fname, args, state):
    callee = interp.find_func(FUNCS, fname)
    return interp.run_function(FUNCS, callee, args, state)


def run_compiled(fname, args, state):
    return compiled.FUNCS[fname](args, state)


def to_jsonable(v):
    # tokens/ast/ir are lists-of-lists all the way down already -- safe
    # to compare via json.dumps for a byte-exact structural diff.
    return json.dumps(v, sort_keys=False)


fails = 0
for i, src in enumerate(CASES):
    # Each implementation gets its OWN state, but that ONE state is
    # shared across the whole tokenize->parse_program->lower_program
    # pipeline within it -- matching real usage (patc1_main.patlang's
    # own `lower` subcommand), where vec handles created by one stage
    # are still valid when a later stage reads them. Two independent,
    # per-call fresh states was a real test-harness bug, not a
    # translator bug (confirmed: it broke the ALREADY-TRUSTED tree-
    # walking interpreter the exact same way).
    state_i = interp.HostState([], FUNCS)
    state_c = interp.HostState([], FUNCS)

    toks_i = run_interp("tokenize", [src], state_i)
    toks_c = run_compiled("tokenize", [src], state_c)
    ok_tok = to_jsonable(toks_i) == to_jsonable(toks_c)

    ast_i = run_interp("parse_program", [toks_i], state_i)
    ast_c = run_compiled("parse_program", [toks_c], state_c)
    ok_ast = to_jsonable(ast_i) == to_jsonable(ast_c)

    ir_i = run_interp("lower_program", [ast_i], state_i)
    ir_c = run_compiled("lower_program", [ast_c], state_c)
    ok_ir = to_jsonable(ir_i) == to_jsonable(ir_c)

    status = "ok" if (ok_tok and ok_ast and ok_ir) else "FAIL"
    if status == "FAIL":
        fails += 1
    print("case %d: %s (tokenize=%s parse_program=%s lower_program=%s)" % (
        i, status, ok_tok, ok_ast, ok_ir))
    if not ok_tok:
        print("  interp tokens:", to_jsonable(toks_i)[:300])
        print("  compiled tokens:", to_jsonable(toks_c)[:300])
    if ok_tok and not ok_ast:
        print("  interp ast:", to_jsonable(ast_i)[:300])
        print("  compiled ast:", to_jsonable(ast_c)[:300])
    if ok_tok and ok_ast and not ok_ir:
        print("  interp ir:", to_jsonable(ir_i)[:300])
        print("  compiled ir:", to_jsonable(ir_c)[:300])

print()
print("TOTAL: %d/%d cases matched" % (len(CASES) - fails, len(CASES)))
sys.exit(1 if fails else 0)
