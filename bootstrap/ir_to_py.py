#!/usr/bin/env python3
"""
ir_to_py.py -- GitHub #196, approach (b): compile PatLang IR into real
Python SOURCE TEXT instead of tree-walking it at runtime, the same way
self_hosting/lib/codegen.patlang's emit_program_rs already does for Rust.
Scoped to the compiler's frontend (lexer/parser/lower) per that issue's
own scoping -- see bootstrap/build_frontend_ir.py for how frontend.ir is
produced.

WHY THIS IS FASTER: bootstrap_interp.py's run_function decodes every
single instruction's tag (a string compare against ~13 names) and its
operands at RUN TIME, on every execution, for every instruction. This
emits that decode ONCE, at translation time, as real Python statements
-- "stack.append(5)" instead of "if op == 'Const': stack.append(
interp_const(instr[1], instr[2]))". Confirmed empirically (this
session's own re-verification of GitHub #25 Piece 2): the tree-walking
interpreter processes tens of millions of instructions per minute even
on a small input, because EVERY one of those pays the full generic
dispatch cost.

NO GOTO IN PYTHON: PatLang's IR is flat and PC-indexed (every if/while/
match lowers to Jump/JumpIfFalse over a flat instruction array -- see
lower.patlang's own header). This splits each function's instructions
into BASIC BLOCKS (a block starts at pc 0 or at any jump TARGET, and
ends at a Jump/JumpIfFalse/Return or the next block's start) and emits
one real Python function per block -- straight-line code within a
block, no per-instruction dispatch at all -- wired together by a small
trampoline that only pays a dict-lookup-and-call cost at ACTUAL block
boundaries, which are far rarer than individual instructions.

LIVE PROGRESS, built in from the start, not bolted on after (the exact
trap this project's own standing rule warns about -- a status check that
only gets a turn between calls, never during one, isn't actually live):
the generated trampoline calls state.progress.tick(...) on every block
transition, reusing bootstrap_interp.py's own Progress class/throttling
so both the tree-walking interpreter and this compiled path report to
the exact same bootstrap/compile_status.json.

Usage:
    python ir_to_py.py <in.ir> <out.py>
"""
import json
import re
import sys

SAFE_NAME_RE = re.compile(r"[^A-Za-z0-9_]")


def safe_name(name):
    return "pf_" + SAFE_NAME_RE.sub("_", name)


def collect_block_starts(instrs):
    starts = {0}
    for i, instr in enumerate(instrs):
        op = instr[0]
        if op == "Jump":
            starts.add(instr[1])
        elif op == "JumpIfFalse":
            # Two distinct successors: the explicit target (cond false)
            # AND the fallthrough right after this instruction (cond
            # true) -- both are real jump destinations and need their
            # own block, same as a true Jump's target does. Missing the
            # fallthrough one here was a real bug (an "if true-branch"
            # continuation landed on a pc with no registered block at
            # all, confirmed via a genuine KeyError testing real PatLang
            # source through this translator for the first time).
            starts.add(instr[1])
            starts.add(i + 1)
    return starts


def split_blocks(instrs):
    """[(start_pc, [instr, ...]), ...], each block ending at the next
    block start or a Jump/JumpIfFalse/Return (whichever comes first)."""
    starts = sorted(collect_block_starts(instrs))
    starts_set = set(starts)
    blocks = []
    n = len(instrs)
    for start in starts:
        body = []
        pc = start
        while pc < n:
            instr = instrs[pc]
            body.append(instr)
            op = instr[0]
            if op in ("Jump", "JumpIfFalse", "Return"):
                pc += 1
                break
            pc += 1
            if pc in starts_set:
                break
        blocks.append((start, body, pc))  # pc here is the fallthrough target
    return blocks


def emit_instr(line, instr, next_pc):
    op = instr[0]
    if op == "Const":
        kind, text = instr[1], instr[2]
        if kind == "num":
            lit = float(text) if ("." in text or "e" in text or "E" in text) else int(text)
        elif kind == "bool":
            lit = text == "true"
        elif kind == "unit":
            lit = None
        else:  # "str"
            lit = text
        line("stack.append(%r)" % (lit,))
    elif op == "Load":
        line("stack.append(locals_.get(%r))" % instr[1])
    elif op == "Store":
        line("locals_[%r] = stack.pop()" % instr[1])
    elif op == "Bin":
        line("b = stack.pop(); a = stack.pop(); stack.append(rt.interp_bin(%r, a, b))" % instr[1])
    elif op == "Un":
        line("a = stack.pop(); stack.append(rt.interp_un(%r, a))" % instr[1])
    elif op == "CallHost":
        argc = instr[2]
        line("args = stack[len(stack)-%d:]; del stack[len(stack)-%d:]" % (argc, argc) if argc else "args = []")
        line("stack.append(rt.call_host(%r, args, state))" % instr[1])
    elif op == "BuildList":
        n = instr[1]
        line("items = stack[len(stack)-%d:]; del stack[len(stack)-%d:]" % (n, n) if n else "items = []")
        line("stack.append(list(items))")
    elif op == "Call":
        argc = instr[2]
        line("args = stack[len(stack)-%d:]; del stack[len(stack)-%d:]" % (argc, argc) if argc else "args = []")
        line("stack.append(FUNCS[%r](args, state))" % instr[1])
    elif op == "MakeClosure":
        captured_names = instr[2]
        n = len(captured_names)
        line("cap = stack[len(stack)-%d:]; del stack[len(stack)-%d:]" % (n, n) if n else "cap = []")
        line("stack.append(('__closure__', %r, list(cap)))" % instr[1])
    elif op == "CallValue":
        argc = instr[1]
        line("cargs = stack[len(stack)-%d:]; del stack[len(stack)-%d:]" % (argc, argc) if argc else "cargs = []")
        line("closure = stack.pop()")
        line("stack.append(FUNCS[closure[1]](list(closure[2]) + list(cargs), state))")
    elif op == "Jump":
        line("return (False, %d)" % instr[1])
    elif op == "JumpIfFalse":
        line("cond = stack.pop()")
        line("return (False, %d) if cond else (False, %d)" % (next_pc, instr[1]))
    elif op == "Return":
        line("return (True, (stack[-1] if stack else None))")
    else:
        raise ValueError("ir_to_py: unsupported instruction '%s'" % op)


def emit_function(out, func):
    _tag, name, params, instrs, _lines = func
    n_instrs = len(instrs)
    sname = safe_name(name)
    blocks = split_blocks(instrs)
    block_fn_names = {}
    for start, body, fallthrough in blocks:
        block_fn_names[start] = "_%s_b%d" % (sname, start)

    for start, body, fallthrough in blocks:
        out.append("def %s(stack, locals_, state):" % block_fn_names[start])
        wrote_any = False
        for i, instr in enumerate(body):
            pc_here = start + i
            next_pc = pc_here + 1
            lines_buf = []
            emit_instr(lambda s, _b=lines_buf: _b.append(s), instr, next_pc)
            for s in lines_buf:
                out.append("    " + s)
                wrote_any = True
        if body and body[-1][0] in ("Jump", "JumpIfFalse", "Return"):
            pass  # already ends in an explicit return/jump statement above
        elif fallthrough >= n_instrs:
            # Genuinely fell off the END of this function's own
            # instructions (run_function's own `pc >= len(instrs): return
            # None`) -- NOT the same as falling through into another
            # block of this SAME function, handled by the else below.
            out.append("    return (True, None)")
        else:
            # Falls straight through into another block's own start pc
            # with no explicit Jump -- continue the trampoline there,
            # don't end the function.
            out.append("    return (False, %d)" % fallthrough)
        if not body:
            out.append("    return (True, None)")
        out.append("")

    out.append("_BLOCKS_%s = {" % sname)
    for start, _body, _ft in blocks:
        out.append("    %d: %s," % (start, block_fn_names[start]))
    out.append("}")
    out.append("")
    out.append("def %s(_args, state):" % sname)
    out.append("    stack = []")
    out.append("    locals_ = dict(zip(%r, _args))" % (list(params),))
    out.append("    pc = 0")
    out.append("    blocks = _BLOCKS_%s" % sname)
    out.append("    while True:")
    out.append("        # Checked INSIDE the real dispatch loop, every block")
    out.append("        # transition -- not once outside it (see this file's")
    out.append("        # own header on why that distinction is load-bearing).")
    out.append("        state.progress.tick(func=%r, pc=pc)" % name)
    out.append("        is_ret, payload = blocks[pc](stack, locals_, state)")
    out.append("        if is_ret:")
    out.append("            return payload")
    out.append("        pc = payload")
    out.append("")
    out.append("")
    return sname


def translate(ir):
    _tag, entry, funcs, _events = ir
    out = [
        "# AUTO-GENERATED by bootstrap/ir_to_py.py -- do not hand-edit.",
        "# Compiled from PatLang IR (GitHub #196): a straight-line Python",
        "# function per basic block, wired by a small pc trampoline, instead",
        "# of tree-walking the IR structure at runtime.",
        "import os, sys",
        # bootstrap_interp.py is a plain sibling module (same directory),
        # not a package -- simplest for a script someone just drops next
        # to it on a fresh machine.
        "sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))",
        "import bootstrap_interp as rt",
        "",
    ]
    out.append("FUNCS = {}")
    out.append("")
    names = []
    for func in funcs:
        sname = emit_function(out, func)
        names.append((func[1], sname))
    out.append("FUNCS.update({")
    for name, sname in names:
        out.append("    %r: %s," % (name, sname))
    out.append("})")
    out.append("")
    out.append("ENTRY = %r" % entry)
    out.append("")
    out.append("def run(args, state):")
    out.append("    return FUNCS[ENTRY](args, state)")
    out.append("")
    return "\n".join(out)


def main():
    if len(sys.argv) != 3:
        print("usage: ir_to_py.py <in.ir> <out.py>")
        sys.exit(1)
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        ir = json.loads(f.read(), strict=False)
    py_src = translate(ir)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(py_src)
    print("wrote %s (%d funcs)" % (sys.argv[2], len(ir[2])))


if __name__ == "__main__":
    main()
