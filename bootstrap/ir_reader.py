"""Builds a Windows x64 executable from v2's IR (docs/spec/ir.md).

    py -3 bootstrap/ir_reader.py IN.ir OUT.exe

The IR comes from `v2.exe SRC.patlang OUT.ir --ir`. Only Python's standard
library is used, so a machine with Python and no PatLang can build v2 itself
from the compiler's IR.
"""
import struct
import sys

# ---- the text form ---------------------------------------------------------


class IRError(Exception):
    pass


def parse_value(line, i):
    """The value starting at line[i] (bytes), and the index after it."""
    c = line[i]
    if c == 0x5B:  # [
        items = []
        i += 1
        if line[i] == 0x5D:
            return items, i + 1
        while True:
            v, i = parse_value(line, i)
            items.append(v)
            if line[i] == 0x5D:
                return items, i + 1
            if line[i] != 0x20:
                raise IRError("expected a space or ] at byte %d" % i)
            i += 1
    if c == 0x22:  # "
        out = bytearray()
        i += 1
        while line[i] != 0x22:
            if line[i] == 0x5C:
                out.append(int(line[i + 1:i + 3], 16))
                i += 3
            else:
                out.append(line[i])
                i += 1
        return out.decode("utf-8"), i + 1
    j = i
    if line[j] == 0x2D:
        j += 1
    while j < len(line) and 0x30 <= line[j] <= 0x39:
        j += 1
    if j == i:
        raise IRError("unexpected byte %r at %d" % (chr(c), i))
    return int(line[i:j]), j


def read_ir(path):
    with open(path, "rb") as f:
        lines = f.read().split(b"\n")
    if lines[0] != b"v2-ir 1":
        raise IRError("not v2 IR, format 1: " + repr(lines[0][:40]))
    head = lines[1].split(b" ")
    if head[0] != b"plus_events":
        raise IRError("line 2 is not plus_events")
    plus_events = head[1] == b"1"
    fns = []
    for line in lines[2:]:
        if line:
            v, end = parse_value(line, 0)
            if end != len(line) or v[0] != "Fn":
                raise IRError("a function line has more than one value")
            fns.append(v)
    return plus_events, fns


# ---- encoding ---------------------------------------------------------------

RAX, RCX, RDX, RBX, RSP, RBP, RSI, RDI, R8, R9 = range(10)


def sym(name):
    """A function's symbol, as x64.patlang's xv_sym spells it."""
    out = ["f_"]
    for ch in name:
        c = ord(ch)
        if 48 <= c <= 57 or 65 <= c <= 90 or 97 <= c <= 122 or c == 95:
            out.append(ch)
        else:
            out.append("_x%d_" % c)
    return "".join(out)


def u64(n):
    return n & 0xFFFFFFFFFFFFFFFF


class Code:
    """The .text bytes, with fixups: rel32 fields to symbols, labels, data,
    the runtime state and import slots, each resolved at link time."""

    def __init__(self):
        self.b = bytearray()
        self.symbols = {}      # name -> offset in .text
        self.fixups = []       # (offset of rel32 field, kind, target)
        self.labels = {}       # label id -> offset, for the current function
        self.local = []        # (offset, label id) for the current function
        self.next_label = 0

    # labels within one function
    def new_label(self):
        self.next_label += 1
        return self.next_label

    def place(self, label):
        self.labels[label] = len(self.b)

    def end_function(self):
        for at, label in self.local:
            if label not in self.labels:
                raise IRError("jump to a label the function lacks")
            struct.pack_into("<i", self.b, at, self.labels[label] - (at + 4))
        self.labels = {}
        self.local = []

    def emit(self, *bs):
        self.b.extend(bs)

    def rel32(self, kind, target):
        self.fixups.append((len(self.b), kind, target))
        self.b.extend(b"\0\0\0\0")

    def rel_label(self, label):
        self.local.append((len(self.b), label))
        self.b.extend(b"\0\0\0\0")

    # instruction forms
    def rex(self, w, reg, base):
        r = 0x40 | (8 if w else 0) | (4 if reg >= 8 else 0) | (1 if base >= 8 else 0)
        if r != 0x40 or w:
            self.emit(r)

    def modrm_mem(self, reg, base, disp):
        """[base+disp32]; base rsp takes a SIB byte."""
        self.emit(0x80 | ((reg & 7) << 3) | (base & 7))
        if (base & 7) == RSP:
            self.emit(0x24)
        self.b.extend(struct.pack("<i", disp))

    def op_rm(self, opcode, reg, base, disp, w=True, prefix=()):
        self.emit(*prefix)
        self.rex(w, reg, base)
        self.emit(*opcode)
        self.modrm_mem(reg, base, disp)

    def op_rr(self, opcode, reg, rm, w=True, prefix=()):
        self.emit(*prefix)
        self.rex(w, reg, rm)
        self.emit(*opcode)
        self.emit(0xC0 | ((reg & 7) << 3) | (rm & 7))

    def load(self, r, base, disp):          # mov r, [base+disp]
        self.op_rm((0x8B,), r, base, disp)

    def store(self, base, disp, r):         # mov [base+disp], r
        self.op_rm((0x89,), r, base, disp)

    def mov_imm(self, r, n):                # mov r, imm64
        self.rex(True, 0, r)
        self.emit(0xB8 + (r & 7))
        self.b.extend(struct.pack("<Q", u64(n)))

    def push_mem(self, base, disp):         # push qword [base+disp]
        self.op_rm((0xFF,), 6, base, disp, w=False)

    def push(self, r):
        self.emit(0x50 + r)

    def alu(self, op, dst, src):            # add/sub/and/or/xor/cmp dst, src
        self.op_rr(({"add": 0x01, "sub": 0x29, "and": 0x21, "or": 0x09, "xor": 0x31, "cmp": 0x39, "test": 0x85}[op],), src, dst)

    def alu_imm(self, op, r, n):            # op r, imm32
        self.rex(True, 0, r)
        self.emit(0x81, 0xC0 | ({"add": 0, "or": 1, "and": 4, "sub": 5, "cmp": 7}[op] << 3) | (r & 7))
        self.b.extend(struct.pack("<i", n))

    def imul(self, dst, src):
        self.op_rr((0x0F, 0xAF), dst, src)

    def shift_cl(self, kind, r):            # shl/shr/sar r, cl
        self.op_rr((0xD3,), {"shl": 4, "shr": 5, "sar": 7}[kind], r)

    def unary(self, kind, r):               # not/neg r
        self.op_rr((0xF7,), {"not": 2, "neg": 3}[kind], r)

    def cqo_idiv_rcx(self):
        self.emit(0x48, 0x99, 0x48, 0xF7, 0xF9)

    def lock_xadd(self, base, r):           # lock xadd [base], r
        self.emit(0xF0)
        self.op_rm((0x0F, 0xC1), r, base, 0)

    def jcc(self, cc, label):
        self.emit(0x0F, 0x80 | cc)
        self.rel_label(label)

    def jmp(self, label):
        self.emit(0xE9)
        self.rel_label(label)

    def call_sym(self, name):
        self.emit(0xE8)
        self.rel32("text", name)

    def call_import(self, lib, func):       # call [rip+IAT slot]
        self.emit(0xFF, 0x15)
        self.rel32("iat", (lib, func))

    def lea_rip(self, r, kind, target):     # lea r, [rip+target]
        self.rex(True, r, 0)
        self.emit(0x8D, 0x05 | ((r & 7) << 3))
        self.rel32(kind, target)

    def movq_x_r(self, x, r):               # movq xmmX, r
        self.op_rr((0x0F, 0x6E), x, r, prefix=(0x66,))

    def movq_r_x(self, r, x):               # movq r, xmmX
        self.op_rr((0x0F, 0x7E), x, r, prefix=(0x66,))


JL, JGE, JE, JNE, JLE, JG, JO, JZ, JP = 0xC, 0xD, 0x4, 0x5, 0xE, 0xF, 0x0, 0x4, 0xA
JBE = 0x6
CMP_JUMP = {"<": JL, ">": JG, "<=": JLE, ">=": JGE, "==": JE, "!=": JNE}
# The highest built-in class value_live accepts: ir_last_builtin_class in
# self_hosting/v2/ir.patlang, 18 being bytes.
LAST_BUILTIN_CLASS = 18
OP_FN = {"+": "op_add", "q+": "op_add_quiet", "a+": "op_add_taken", "-": "op_sub", "*": "op_mul",
         "/": "op_div", "%": "op_mod", "<": "op_lt", ">": "op_gt", "<=": "op_le", ">=": "op_ge",
         "==": "op_eq", "!=": "op_ne", "band": "op_band", "bor": "op_bor", "bxor": "op_bxor",
         "shl": "op_shl", "shr": "op_shr"}


# ---- one function -----------------------------------------------------------


class FnGen:
    def __init__(self, code, data, plus_events, imports):
        self.c = code
        self.data = data
        self.plus_events = plus_events
        self.imports = imports

    def t(self, s):
        return -(16 * s + 16)

    def d(self, s):
        return -(16 * s + 8)

    def load_t(self, r, s):
        self.c.load(r, RBP, self.t(s))

    def load_d(self, r, s):
        self.c.load(r, RBP, self.d(s))

    def set_value(self, s, treg, dreg):
        self.c.store(RBP, self.t(s), treg)
        self.c.store(RBP, self.d(s), dreg)

    def store_int(self, s):                 # slot s = the int in rax
        self.c.mov_imm(RCX, 2)
        self.set_value(s, RCX, RAX)

    def store_bool(self, s):                # slot s = the bool in rax
        self.c.mov_imm(RCX, 1)
        self.set_value(s, RCX, RAX)

    def store_unit(self, s):
        self.c.mov_imm(RAX, 0)
        self.set_value(s, RAX, RAX)

    def call(self, name, slots, d):
        for s in reversed(slots):
            self.c.push_mem(RBP, self.d(s))
            self.c.push_mem(RBP, self.t(s))
        self.c.call_sym(sym(name))
        if slots:
            self.c.alu_imm("add", RSP, 16 * len(slots))
        self.set_value(d, RAX, RDX)

    def count(self, which, s):
        """retain or release s when its heap bit is set."""
        c = self.c
        skip = c.new_label()
        self.load_t(RAX, s)
        c.mov_imm(RCX, 1 << 32)
        c.alu("test", RAX, RCX)
        c.jcc(JZ, skip)
        self.load_d(RCX, s)
        if which == "retain":
            c.mov_imm(RAX, 1)
            c.lock_xadd(RCX, RAX)
            c.alu_imm("cmp", RAX, 1)
            c.jcc(JGE, skip)
            c.call_sym(sym("rt_fail_released_twice"))
        else:
            c.mov_imm(RAX, -1)
            c.lock_xadd(RCX, RAX)
            c.alu_imm("cmp", RAX, 1)
            c.jcc(JG, skip)
            c.mov_imm(RCX, 2)
            c.push(RAX)
            c.push(RCX)
            c.push_mem(RBP, self.d(s))
            c.push(RCX)
            c.push_mem(RBP, self.t(s))
            c.push(RCX)
            c.call_sym(sym("rt_release_last"))
            c.alu_imm("add", RSP, 48)
        c.place(skip)

    def both_ints(self, a, b, slow):
        c = self.c
        for s in (a, b):
            self.load_t(RAX, s)
            c.alu_imm("cmp", RAX, 2)
            c.jcc(JNE, slow)

    def op(self, op, d, a, b):
        c = self.c
        slow, done = c.new_label(), c.new_label()
        if op in ("band", "bor", "bxor", "shl", "shr", "%"):
            self.both_ints(a, b, slow)
            self.load_d(RAX, a)
            self.load_d(RCX, b)
            if op in ("band", "bor", "bxor"):
                c.alu({"band": "and", "bor": "or", "bxor": "xor"}[op], RAX, RCX)
            elif op == "shl":
                c.shift_cl("shl", RAX)
            elif op == "shr":
                c.shift_cl("sar", RAX)
            else:
                c.alu("test", RCX, RCX)
                c.jcc(JZ, slow)
                c.cqo_idiv_rcx()
                c.op_rr((0x89,), RDX, RAX)   # mov rax, rdx
            self.store_int(d)
            c.jmp(done)
        elif op in ("+", "q+", "a+", "-", "*") or op in CMP_JUMP:
            self.both_ints(a, b, slow)
            if op in ("+", "a+") and self.plus_events:
                c.lea_rip(RAX, "bss", "v2_runtime_state")
                c.load(RAX, RAX, 2064)
                c.alu("test", RAX, RAX)
                c.jcc(JNE, slow)
            self.load_d(RAX, a)
            self.load_d(RCX, b)
            if op in CMP_JUMP:
                yes = c.new_label()
                c.alu("cmp", RAX, RCX)
                c.mov_imm(RAX, 1)
                c.jcc(CMP_JUMP[op], yes)
                c.mov_imm(RAX, 0)
                c.place(yes)
                self.store_bool(d)
            else:
                if op == "-":
                    c.alu("sub", RAX, RCX)
                elif op == "*":
                    c.imul(RAX, RCX)
                else:
                    c.alu("add", RAX, RCX)
                c.jcc(JO, slow)
                self.store_int(d)
            c.jmp(done)
        c.place(slow)
        self.call(OP_FN[op], [a, b], d)
        c.place(done)

    def un(self, op, d, a):
        c = self.c
        slow, done = c.new_label(), c.new_label()
        self.load_t(RAX, a)
        c.alu_imm("cmp", RAX, 1 if op == "not" else 2)
        c.jcc(JNE, slow)
        self.load_d(RAX, a)
        if op == "-":
            c.unary("neg", RAX)
            c.jcc(JO, slow)
            self.store_int(d)
        elif op == "bnot":
            c.unary("not", RAX)
            self.store_int(d)
        else:
            c.mov_imm(RCX, 1)
            c.alu("xor", RAX, RCX)
            self.store_bool(d)
        c.jmp(done)
        c.place(slow)
        self.call({"-": "op_neg", "bnot": "op_bnot", "not": "op_not"}[op], [a], d)
        c.place(done)

    def addr(self, args):                   # rax = args[0] + args[1], data words
        self.load_d(RAX, args[0])
        self.load_d(RCX, args[1])
        self.c.alu("add", RAX, RCX)

    def prim(self, name, d, args):
        c = self.c
        if name in ("ct_secret", "ct_public", "ct_reveal", "ct_declassify"):
            # marks for the constant-time check, doing nothing
            return self.store_unit(d)
        if name == "value_live":
            bad, known, good, store = c.new_label(), c.new_label(), c.new_label(), c.new_label()
            word = c.new_label()
            self.load_t(RAX, args[0])
            c.op_rr((0x89,), RAX, RCX)        # mov rcx, rax
            c.rex(True, 0, RCX)
            c.emit(0xC1, 0xE9, 34)            # shr rcx, 34
            c.alu("test", RCX, RCX)
            c.jcc(JNE, word)
            c.mov_imm(RCX, 0xFFFFFFFF)
            c.alu("and", RCX, RAX)
            c.alu_imm("cmp", RCX, LAST_BUILTIN_CLASS)
            c.jcc(JLE, known)
            c.alu_imm("cmp", RCX, 63)
            c.jcc(JL, bad)
            c.place(known)
            c.mov_imm(RCX, 1 << 32)
            c.alu("test", RAX, RCX)
            c.jcc(JZ, good)
            self.load_d(RCX, args[0])
            c.load(RCX, RCX, 0)
            c.alu_imm("cmp", RCX, 1)
            c.jcc(JL, bad)
            c.place(good)
            c.mov_imm(RAX, 1)
            c.jmp(store)
            # a modint modulo 2^k held as a word (spec 2.1): the type word
            # with k's bits (40 to 46) cleared is 15 alone, and k is 1 to 64
            c.place(word)
            c.mov_imm(RCX, ~(127 << 40))
            c.alu("and", RCX, RAX)
            c.alu_imm("cmp", RCX, 15)
            c.jcc(JNE, bad)
            c.op_rr((0x89,), RAX, RCX)        # mov rcx, rax
            c.rex(True, 0, RCX)
            c.emit(0xC1, 0xE9, 40)            # shr rcx, 40
            c.alu("test", RCX, RCX)
            c.jcc(JE, bad)
            c.alu_imm("cmp", RCX, 64)
            c.jcc(JBE, good)
            c.place(bad)
            c.mov_imm(RAX, 0)
            c.place(store)
            return self.store_bool(d)
        if name == "value_class":
            self.load_t(RAX, args[0])
            c.mov_imm(RCX, 0xFFFFFFFF)
            c.alu("and", RAX, RCX)
            return self.store_int(d)
        if name == "value_data":
            self.load_d(RAX, args[0])
            return self.store_int(d)
        if name == "value_type_word":
            self.load_t(RAX, args[0])
            return self.store_int(d)
        if name == "value_make":
            self.load_d(RAX, args[0])
            self.load_d(RDX, args[1])
            return self.set_value(d, RAX, RDX)
        if name == "runtime_state":
            c.lea_rip(RAX, "bss", "v2_runtime_state")
            return self.store_int(d)
        if name == "thread_entry_address":
            c.lea_rip(RAX, "text", "v2_thread_entry")
            return self.store_int(d)
        if name == "atomic_add":
            self.load_d(RAX, args[0])
            self.load_d(RCX, args[1])
            c.lock_xadd(RAX, RCX)
            c.op_rr((0x89,), RCX, RAX)        # mov rax, rcx
            return self.store_int(d)
        if name in ("mem_load_value", "mem_take_value"):
            self.addr(args)
            c.load(RCX, RAX, 0)
            c.store(RBP, self.t(d), RCX)
            c.load(RCX, RAX, 8)
            c.store(RBP, self.d(d), RCX)
            if name == "mem_load_value":
                return self.count("retain", d)
            c.mov_imm(RCX, 0)
            c.store(RAX, 0, RCX)
            c.store(RAX, 8, RCX)
            return
        if name in ("mem_store_value", "mem_init_value"):
            self.count("retain", args[2])
            if name == "mem_store_value":
                self.addr(args)
                c.load(RCX, RAX, 0)
                c.store(RBP, self.t(d), RCX)
                c.load(RCX, RAX, 8)
                c.store(RBP, self.d(d), RCX)
                self.count("release", d)
            self.addr(args)
            self.load_t(RCX, args[2])
            c.store(RAX, 0, RCX)
            self.load_d(RCX, args[2])
            c.store(RAX, 8, RCX)
            return self.store_unit(d)
        if name in ("mem_load", "mem_load_byte", "mem_store", "mem_store_byte"):
            self.addr(args)
            if name == "mem_load":
                c.load(RAX, RAX, 0)
                return self.store_int(d)
            if name == "mem_load_byte":
                c.op_rm((0x0F, 0xB6), RAX, RAX, 0)   # movzx rax, byte [rax]
                return self.store_int(d)
            self.load_d(RCX, args[2])
            if name == "mem_store":
                c.store(RAX, 0, RCX)
            else:
                c.op_rm((0x88,), RCX, RAX, 0, w=False)  # mov [rax], cl
            return self.store_unit(d)
        if name in ("int_to_float", "float_to_int"):
            self.load_d(RAX, args[0])
            if name == "int_to_float":
                c.op_rr((0x0F, 0x2A), 0, RAX, prefix=(0xF2,))   # cvtsi2sd xmm0, rax
                c.movq_r_x(RAX, 0)
            else:
                c.movq_x_r(0, RAX)
                c.op_rr((0x0F, 0x2C), RAX, 0, prefix=(0xF2,))   # cvttsd2si rax, xmm0
            return self.store_int(d)
        if name.startswith("float_"):
            self.load_d(RAX, args[0])
            c.movq_x_r(0, RAX)
            self.load_d(RAX, args[1])
            c.movq_x_r(1, RAX)
            if name == "float_lt":
                c.op_rr((0x0F, 0x2E), 1, 0, w=False, prefix=(0x66,))   # ucomisd xmm1, xmm0
                c.mov_imm(RAX, 0)
                c.emit(0x0F, 0x97, 0xC0)                                # seta al
                return self.store_int(d)
            if name == "float_eq":
                skip = c.new_label()
                c.op_rr((0x0F, 0x2E), 0, 1, w=False, prefix=(0x66,))   # ucomisd xmm0, xmm1
                c.mov_imm(RAX, 0)
                c.jcc(JNE, skip)
                c.jcc(JP, skip)                                         # unordered: a NaN
                c.mov_imm(RAX, 1)
                c.place(skip)
                return self.store_int(d)
            op = {"float_add": 0x58, "float_sub": 0x5C, "float_mul": 0x59, "float_div": 0x5E}[name]
            c.op_rr((0x0F, op), 0, 1, w=False, prefix=(0xF2,))
            c.movq_r_x(RAX, 0)
            return self.store_int(d)
        if name.startswith("word_"):
            self.load_d(RAX, args[0])
            self.load_d(RCX, args[1])
            kind = name[5:]
            if kind in ("add", "sub", "and", "or", "xor"):
                c.alu(kind, RAX, RCX)
            elif kind == "mul":
                c.imul(RAX, RCX)
            elif kind in ("shl", "shr"):
                c.shift_cl(kind, RAX)
            elif kind in ("div", "rem"):
                c.cqo_idiv_rcx()
                if kind == "rem":
                    c.op_rr((0x89,), RDX, RAX)
            else:
                raise IRError("unknown primitive " + name)
            return self.store_int(d)
        raise IRError("unknown primitive " + name)

    def extern(self, lib, func, d, args, frame_bytes, floats):
        c = self.c
        self.imports.setdefault(lib, [])
        if func not in self.imports[lib]:
            self.imports[lib].append(func)
        n = len(args)
        space = 32 + (8 * (n - 4) if n > 4 else 0)
        if space % 16:
            space += 8
        c.alu_imm("and", RSP, -16)
        c.alu_imm("sub", RSP, space)
        for k in range(4, n):
            self.load_d(RAX, args[k])
            c.store(RSP, 32 + 8 * (k - 4), RAX)
        regs = [RCX, RDX, R8, R9]
        for k in range(min(n, 4)):
            if floats:
                self.load_d(RAX, args[k])
                c.movq_x_r(k, RAX)
            else:
                self.load_d(regs[k], args[k])
        c.call_import(lib, func)
        if floats:
            c.movq_r_x(RAX, 0)
        c.op_rm((0x8D,), RSP, RBP, -frame_bytes)   # lea rsp, [rbp-frame_bytes]
        self.store_int(d)

    def string(self, text):
        raw = text.encode("utf-8")
        while len(self.data) % 8:
            self.data.append(0)
        at = len(self.data)
        self.data.extend(struct.pack("<qqqq", 0, 0, len(raw), len(text)))
        self.data.extend(raw)
        return at

    def const(self, d, kind, text):
        c = self.c
        text = str(text)
        if kind == "str":
            at = self.string(text)
            c.mov_imm(RAX, 8)
            c.store(RBP, self.t(d), RAX)
            c.lea_rip(RAX, "data", at)
            c.store(RBP, self.d(d), RAX)
            return
        if kind == "float":
            bits = struct.unpack("<Q", struct.pack("<d", float(text)))[0]
            cls = 3
        elif kind == "unit":
            bits, cls = 0, 0
        elif kind in ("int", "bool"):
            bits = int(text)
            if not -(1 << 63) <= bits < (1 << 64):
                raise IRError("a constant wider than a word: " + text)
            cls = 2 if kind == "int" else 1
        else:
            raise IRError("unknown constant kind " + kind)
        c.mov_imm(RAX, cls)
        c.store(RBP, self.t(d), RAX)
        c.mov_imm(RAX, bits)
        c.store(RBP, self.d(d), RAX)

    def alloc_and_fill(self, alloc, d, slots):
        c = self.c
        c.mov_imm(RAX, len(slots))
        c.push(RAX)
        c.mov_imm(RAX, 2)
        c.push(RAX)
        c.call_sym(sym(alloc))
        c.alu_imm("add", RSP, 16)
        self.set_value(d, RAX, RDX)
        return self.fill(d, slots)

    def fill(self, d, slots, base=32):
        """Each slot's value, with a reference of its own, at d's block +
        base + 16k: a list's items from 32, a closure's captured values from 48."""
        c = self.c
        for k, s in enumerate(slots):
            self.count("retain", s)
            self.load_d(RAX, d)
            self.load_t(RCX, s)
            c.store(RAX, base + 16 * k, RCX)
            self.load_d(RCX, s)
            c.store(RAX, base + 8 + 16 * k, RCX)

    def function(self, fn):
        _, name, nparams, nslots, instrs, _vars = fn
        c = self.c
        s = sym(name)
        if s in c.symbols:
            raise IRError("two functions are both " + name)
        c.symbols[s] = len(c.b)
        frame_bytes = 16 * nslots
        c.push(RBP)
        c.op_rr((0x89,), RSP, RBP)          # mov rbp, rsp
        left = frame_bytes
        while left > 4096:
            c.alu_imm("sub", RSP, 4096)
            c.load(RAX, RSP, 0)
            left -= 4096
        if frame_bytes > 0:
            c.alu_imm("sub", RSP, left)
        for p in range(nparams):
            c.load(RAX, RBP, 16 + 16 * p)
            c.store(RBP, self.t(p), RAX)
            c.load(RAX, RBP, 24 + 16 * p)
            c.store(RBP, self.d(p), RAX)
        labels = {}

        def label(n):
            if n not in labels:
                labels[n] = c.new_label()
            return labels[n]

        for ins in instrs:
            op = ins[0]
            if op == "const":
                self.const(ins[1], ins[2], ins[3])
            elif op in ("copy", "move"):
                self.load_t(RAX, ins[2])
                c.store(RBP, self.t(ins[1]), RAX)
                self.load_d(RAX, ins[2])
                c.store(RBP, self.d(ins[1]), RAX)
                if op == "move":
                    c.mov_imm(RAX, 0)
                    c.store(RBP, self.t(ins[2]), RAX)
            elif op == "clear":
                c.mov_imm(RAX, 0)
                c.store(RBP, self.t(ins[1]), RAX)
            elif op == "call":
                self.call(ins[2], ins[3], ins[1])
            elif op == "op":
                self.op(ins[2], ins[1], ins[3], ins[4])
            elif op == "un":
                self.un(ins[2], ins[1], ins[3])
            elif op == "prim":
                self.prim(ins[2], ins[1], ins[3])
            elif op in ("extern", "externf"):
                self.extern(ins[2], ins[3], ins[1], ins[4], frame_bytes, op == "externf")
            elif op == "label":
                c.place(label(ins[1]))
            elif op == "jump":
                c.jmp(label(ins[1]))
            elif op == "branch":
                slow, test = c.new_label(), c.new_label()
                self.load_t(RAX, ins[1])
                c.alu_imm("cmp", RAX, 2)
                c.jcc(JG, slow)
                self.load_d(RAX, ins[1])
                c.jmp(test)
                c.place(slow)
                c.push_mem(RBP, self.d(ins[1]))
                c.push_mem(RBP, self.t(ins[1]))
                c.call_sym(sym("rt_truthy"))
                c.alu_imm("add", RSP, 16)
                c.op_rr((0x89,), RDX, RAX)    # mov rax, rdx
                c.place(test)
                c.alu("test", RAX, RAX)
                c.jcc(JZ, label(ins[3]))
                c.jmp(label(ins[2]))
            elif op == "unwound":              # the unwinding mark: type word 16
                self.load_t(RAX, ins[1])
                c.alu_imm("cmp", RAX, 16)
                c.jcc(JZ, label(ins[2]))
            elif op == "unwind":
                c.mov_imm(RAX, 16)
                c.mov_imm(RDX, 0)
                c.emit(0xC9, 0xC3)            # leave; ret
            elif op == "return":
                self.load_t(RAX, ins[1])
                self.load_d(RDX, ins[1])
                c.emit(0xC9, 0xC3)            # leave; ret
            elif op in ("retain", "release"):
                self.count(op, ins[1])
            elif op == "list":
                self.alloc_and_fill("rt_list_alloc", ins[1], ins[2])
            elif op == "closure":
                c.mov_imm(RAX, len(ins[3]))
                c.push(RAX)
                c.mov_imm(RAX, 2)
                c.push(RAX)
                c.call_sym(sym("rt_closure_alloc"))
                c.alu_imm("add", RSP, 16)
                self.set_value(ins[1], RAX, RDX)
                self.load_d(RCX, ins[1])
                c.lea_rip(RAX, "text", sym(ins[2]))
                c.store(RCX, 16, RAX)
                # how many parameters it takes, and whether the last is named rest
                c.mov_imm(RAX, ins[4])
                c.store(RCX, 32, RAX)
                c.mov_imm(RAX, ins[5])
                c.store(RCX, 40, RAX)
                self.fill(ins[1], ins[3], 48)
            elif op == "callv":
                # as xv_callv: a closure taking another number of parameters,
                # or whose last is named rest, gets the same arguments through
                # rt_closure_call_N, which fits them (spec 1.13); an
                # unchecked call (closure_call_unchecked) calls it as it is
                slots = ins[2]
                given = len(slots) - 1
                for sl in reversed(slots):
                    c.push_mem(RBP, self.d(sl))
                    c.push_mem(RBP, self.t(sl))
                self.load_d(RAX, slots[0])
                if len(ins) > 3 and ins[3] == 1:
                    c.load(RAX, RAX, 16)
                else:
                    fit, go = c.new_label(), c.new_label()
                    c.load(RCX, RAX, 32)
                    c.mov_imm(RDX, given)
                    c.alu("cmp", RCX, RDX)
                    c.jcc(JNE, fit)
                    c.load(RCX, RAX, 40)
                    c.mov_imm(RDX, 0)
                    c.alu("cmp", RCX, RDX)
                    c.jcc(JNE, fit)
                    c.load(RAX, RAX, 16)
                    c.jmp(go)
                    c.place(fit)
                    if given > 8:
                        raise IRError("a closure call of %d arguments, more than 8" % given)
                    fitter = "rt_closure_call_%d" % given
                    c.lea_rip(RAX, "text", sym(fitter))
                    c.place(go)
                c.emit(0xFF, 0xD0)            # call rax
                c.alu_imm("add", RSP, 16 * len(slots))
                self.set_value(ins[1], RAX, RDX)
            else:
                raise IRError("unknown instruction " + op + " in " + name)
        c.end_function()


def entry(c, imports):
    """The program's entry and the thread entry (docs/spec/ir.md)."""
    imports.setdefault("KERNEL32.DLL", [])
    if "ExitProcess" not in imports["KERNEL32.DLL"]:
        imports["KERNEL32.DLL"].append("ExitProcess")
    c.symbols["main"] = len(c.b)
    c.push(RBP)
    c.op_rr((0x89,), RSP, RBP)
    c.call_sym(sym("runtime_init"))
    c.call_sym(sym("__main"))
    c.alu_imm("and", RSP, -16)
    c.alu_imm("sub", RSP, 32)
    c.mov_imm(RCX, 0)
    c.call_import("KERNEL32.DLL", "ExitProcess")
    c.symbols["v2_thread_entry"] = len(c.b)
    c.push(RBP)
    c.op_rr((0x89,), RSP, RBP)
    c.push(RCX)
    c.mov_imm(RAX, 2)
    c.push(RAX)
    c.call_sym(sym("rt_thread_main"))
    c.mov_imm(RAX, 0)
    c.emit(0xC9, 0xC3)


# ---- the executable ---------------------------------------------------------

IMAGE_BASE = 0x140000000
SECTION_ALIGN = 0x1000
FILE_ALIGN = 0x200
BSS_SIZE = 65536


def align(n, a):
    return (n + a - 1) // a * a


def build_idata(imports, rva):
    """The import directory, lookup tables, address tables, names; and each
    function's address-table slot."""
    libs = list(imports)
    desc_size = 20 * (len(libs) + 1)
    out = bytearray(desc_size)
    lookups, slots = {}, {}
    # lookup and address tables, one entry per function plus a zero
    tables_at = len(out)
    layout = []
    at = tables_at
    for lib in libs:
        n = len(imports[lib]) + 1
        layout.append((lib, at, at + 8 * n))
        at += 16 * n
    out.extend(bytes(at - len(out)))
    names_at = {}
    for lib in libs:
        names_at[lib] = len(out)
        out.extend(lib.encode("ascii") + b"\0")
    hints = {}
    for lib in libs:
        for func in imports[lib]:
            if len(out) % 2:
                out.append(0)
            hints[(lib, func)] = len(out)
            out.extend(b"\0\0" + func.encode("ascii") + b"\0")
    for i, (lib, ilt, iat) in enumerate(layout):
        for k, func in enumerate(imports[lib]):
            entry = rva + hints[(lib, func)]
            struct.pack_into("<Q", out, ilt + 8 * k, entry)
            struct.pack_into("<Q", out, iat + 8 * k, entry)
            slots[(lib, func)] = rva + iat + 8 * k
        struct.pack_into("<IIIII", out, 20 * i, rva + ilt, 0, 0, rva + names_at[lib], rva + iat)
    iat_end = layout[-1][2] + 8 * (len(imports[layout[-1][0]]) + 1) if layout else 0
    return out, slots, desc_size, (rva + tables_at, iat_end - tables_at)


def link(c, data, imports, out_path):
    text_rva = SECTION_ALIGN
    data_rva = text_rva + align(max(len(c.b), 1), SECTION_ALIGN)
    bss_rva = data_rva + align(max(len(data), 1), SECTION_ALIGN)
    idata_rva = bss_rva + align(BSS_SIZE, SECTION_ALIGN)
    idata, slots, desc_size, iat_dir = build_idata(imports, idata_rva)
    image_size = idata_rva + align(len(idata), SECTION_ALIGN)
    missing = set()
    for at, kind, target in c.fixups:
        if kind == "text":
            if target not in c.symbols:
                missing.add(target)
                continue
            dest = text_rva + c.symbols[target]
        elif kind == "data":
            dest = data_rva + target
        elif kind == "bss":
            dest = bss_rva
        else:
            dest = slots[target]
        struct.pack_into("<i", c.b, at, dest - (text_rva + at + 4))
    if missing:
        raise IRError("undefined symbols: " + ", ".join(sorted(missing)))

    headers = bytearray()
    headers += b"MZ" + bytes(58) + struct.pack("<I", 64)
    headers += b"PE\0\0"
    headers += struct.pack("<HHIIIHH", 0x8664, 4, 0, 0, 0, 240, 0x22)
    text_raw = align(len(c.b), FILE_ALIGN)
    data_raw = align(len(data), FILE_ALIGN)
    idata_raw = align(len(idata), FILE_ALIGN)
    headers_size = align(1024, FILE_ALIGN)
    opt = struct.pack("<HBBIIIII", 0x20B, 0, 0, text_raw, data_raw + idata_raw, BSS_SIZE,
                      text_rva + c.symbols["main"], text_rva)
    opt += struct.pack("<QIIHHHHHHIIIIHHQQQQII", IMAGE_BASE, SECTION_ALIGN, FILE_ALIGN,
                       6, 0, 0, 0, 6, 0, 0, image_size, headers_size, 0, 3, 0x100,
                       256 * 1024 * 1024, 4096, 1024 * 1024, 4096, 0, 16)
    dirs = [(0, 0)] * 16
    dirs[1] = (idata_rva, desc_size)
    dirs[12] = iat_dir
    for va, size in dirs:
        opt += struct.pack("<II", va, size)
    headers += opt
    file_at = headers_size

    def section(name, vsize, rva, raw, flags):
        nonlocal file_at
        ptr = file_at if raw else 0
        file_at += raw
        return struct.pack("<8sIIIIIIHHI", name, max(vsize, SECTION_ALIGN), rva, raw, ptr, 0, 0, 0, 0, flags)

    headers += section(b".text", len(c.b), text_rva, text_raw, 0x60000020)
    headers += section(b".data", len(data), data_rva, data_raw, 0xC0000040)
    headers += section(b".bss", BSS_SIZE, bss_rva, 0, 0xC0000080)
    headers += section(b".idata", len(idata), idata_rva, idata_raw, 0xC0000040)
    headers += bytes(headers_size - len(headers))

    with open(out_path, "wb") as f:
        f.write(headers)
        for blob, raw in ((c.b, text_raw), (data, data_raw), (idata, idata_raw)):
            f.write(blob)
            f.write(bytes(raw - len(blob)))


def main(argv):
    if len(argv) != 3:
        print("usage: ir_reader.py IN.ir OUT.exe")
        return 2
    try:
        plus_events, fns = read_ir(argv[1])
        code, data, imports = Code(), bytearray(), {}
        entry(code, imports)
        gen = FnGen(code, data, plus_events, imports)
        for fn in fns:
            gen.function(fn)
        link(code, data, imports, argv[2])
    except IRError as e:
        print("ir_reader error: " + str(e))
        return 1
    print("ir_reader: " + argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
