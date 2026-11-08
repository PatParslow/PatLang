"""Builds a WebAssembly module from v2's IR (docs/spec/ir.md, "The WASM form").

    py -3 bootstrap/ir_wasm.py IN.ir OUT.wasm

The module runs under the host in self_hosting/v2/wasm/, in a browser or in
Node: each thread and each fibre runs on its own Worker over one shared
memory. Only Python's standard library is used.
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ir_reader import IRError, OP_FN, read_ir  # noqa: E402

# ---- the memory -------------------------------------------------------------

PAGE = 65536
HOST_AREA = 4096           # 4096..65535: what the host writes, the command line
STATE = 65536              # the runtime's state, 65536 zeroed bytes
DATA = 131072              # the constants
MAX_PAGES = 65536

I32, I64, F64 = 0x7F, 0x7E, 0x7C
MIN64 = -(1 << 63)


def uleb(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def sleb(n):
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        if (n == 0 and not b & 0x40) or (n == -1 and b & 0x40):
            out.append(b)
            return bytes(out)
        out.append(b | 0x80)


def vec(items):
    return uleb(len(items)) + b"".join(items)


def name(s):
    raw = s.encode("utf-8")
    return uleb(len(raw)) + raw


def section(sid, body):
    return bytes([sid]) + uleb(len(body)) + body


def signed64(n):
    n &= 0xFFFFFFFFFFFFFFFF
    return n - (1 << 64) if n >> 63 else n


# ---- control flow -------------------------------------------------------------


def structure(instrs, seg_of, nseg):
    """The structured layout of a function's segments, or None.

    A jump back to a segment is a br to a loop beginning at that segment and
    ending after the last segment that jumps back to it. A jump forward is a
    br to a block ending just before its target, beginning in the first
    segment that jumps there. A jump or branch arm to the very next segment,
    as an instruction's last, falls through. Where two of these cross, a
    loop's end moves later or a block's start earlier, until all nest; a
    block that begins before a loop and ends inside it cannot nest, and then
    there is no layout; v2's lowering never makes such a block. For each
    segment: the constructs that begin there, outermost first, as (kind,
    last segment, key), the key being a loop's first segment or a block's
    target."""
    loops, blocks = {}, {}

    def need(i, t):
        if t > i:
            blocks[t] = min(blocks.get(t, i), i)
        else:
            loops[t] = max(loops.get(t, i), i)

    seg = 0
    for k, ins in enumerate(instrs):
        last = k + 1 == len(instrs) or instrs[k + 1][0] == "label"
        op = ins[0]
        if op == "label":
            seg = seg_of[ins[1]]
        elif op == "jump":
            t = seg_of[ins[1]]
            if not (last and t == seg + 1):
                need(seg, t)
        elif op == "branch":
            t, f = seg_of[ins[2]], seg_of[ins[3]]
            if last and f == seg + 1:
                if t != seg + 1:
                    need(seg, t)
            elif last and t == seg + 1:
                need(seg, f)
            else:
                need(seg, t)
                need(seg, f)
    # [kind, start, last, key]
    items = [["loop", j, e, j] for j, e in sorted(loops.items())]
    items += [["block", s, t - 1, t] for t, s in sorted(blocks.items())]
    changed = True
    while changed:
        changed = False
        items.sort(key=lambda it: (it[1], it[2]))
        for x in range(len(items)):
            a = items[x]
            y = x + 1
            while y < len(items) and items[y][1] <= a[2]:
                c = items[y]
                if a[1] < c[1] <= a[2] < c[2]:
                    if a[0] == "loop" and c[0] == "loop":
                        a[2] = c[2]
                    elif c[0] == "block":
                        c[1] = a[1]
                    else:
                        return None
                    changed = True
                y += 1
    plan = [[] for _ in range(nseg)]
    for kind, start, last, key in items:
        plan[start].append((kind, last, key))
    for p in plan:
        p.sort(key=lambda it: (-it[1], 0 if it[0] == "block" else 1))
    return plan


# ---- slots to locals --------------------------------------------------------


def slot_access(ins):
    """(writes, reads): the slots an instruction gives a new value outright,
    and those it reads or changes in part (move's source, clear)."""
    op = ins[0]
    if op == "const":
        return [ins[1]], []
    if op in ("copy", "move"):
        return [ins[1]], [ins[2]]
    if op in ("clear", "retain", "release", "return", "branch"):
        return [], [ins[1]]
    if op in ("call", "prim", "closure"):
        return [ins[1]], ins[3]
    if op in ("extern", "externf"):
        return [ins[1]], ins[4]
    if op == "op":
        return [ins[1]], [ins[3], ins[4]]
    if op == "un":
        return [ins[1]], [ins[3]]
    if op in ("list", "callv"):
        return [ins[1]], ins[2]
    if op in ("label", "jump"):
        return [], []
    raise IRError("unknown instruction " + op)


def slot_locals(nparams, nslots, instrs):
    """Which local pair holds each slot, and how many pairs there are.

    A slot's range is the span of instructions from the first to the last at
    which it is live or named: liveness is over basic blocks (a new one at
    each label and after each jump, branch or return), reading a slot back
    through blocks that do not write it. A slot live where the function
    begins ranges from 0, as each parameter does, since locals start at zero.
    Slots whose ranges do not overlap share a pair: going through the
    instructions in order, slots whose ranges begin at an instruction take,
    in slot order, the pair last given back, or a new one; then slots whose
    ranges end there give theirs back, in slot order. Parameter k keeps
    pair k. A slot no instruction names has no pair (-1).

    Reading a slot back can lower its range's start, or raise its end past
    the last instruction naming it only through a jump back. So once a range
    starts at 0 and ends at or after every block jumping back, nothing more
    is read back for that slot; the ranges are the same either way."""
    n = len(instrs)
    starts = [0]
    for k in range(1, n):
        if instrs[k][0] == "label" or instrs[k - 1][0] in ("jump", "branch", "return"):
            starts.append(k)
    nb = len(starts)
    ends = [starts[i + 1] - 1 for i in range(nb - 1)] + [n - 1]
    block_of = {}
    for i in range(nb):
        if n and instrs[starts[i]][0] == "label":
            block_of[instrs[starts[i]][1]] = i
    preds = [[] for _ in range(nb)]
    back = -1                           # the furthest end of a block jumping back
    for i in range(nb):
        last = instrs[ends[i]] if n else ["label"]
        if last[0] == "jump":
            succ = [block_of[last[1]]]
        elif last[0] == "branch":
            succ = [block_of[last[2]], block_of[last[3]]]
        elif last[0] == "return":
            succ = []
        else:
            succ = [i + 1] if i + 1 < nb else []
        for t in succ:
            preds[t].append(i)
            if t <= i:
                back = max(back, ends[i])
    lo = [-1] * nslots
    hi = [-1] * nslots
    for s in range(nparams):
        lo[s] = 0
        hi[s] = 0
    written = [None] * nslots           # per slot, the blocks writing it
    exposed = []                        # (slot, block): read before any write there
    for i in range(nb):
        seen = set()
        for k in range(starts[i], ends[i] + 1):
            ws, rs = slot_access(instrs[k])
            for s in list(rs) + ws:
                if lo[s] < 0 or k < lo[s]:
                    lo[s] = k
                if k > hi[s]:
                    hi[s] = k
            for s in rs:
                if s not in seen:
                    exposed.append((s, i))
            for s in ws:
                seen.add(s)
                if written[s] is None:
                    written[s] = set()
                written[s].add(i)
    reached = [-1] * nb                 # the slot last found live into each block
    for s, i in exposed:
        if reached[i] == s or (lo[s] == 0 and hi[s] >= back):
            continue
        reached[i] = s
        ws = written[s] or ()
        work = [i]
        while work and not (lo[s] == 0 and hi[s] >= back):
            b = work.pop()
            lo[s] = min(lo[s], starts[b])
            for p in preds[b]:
                hi[s] = max(hi[s], ends[p])
                if p not in ws and reached[p] != s:
                    reached[p] = s
                    work.append(p)
    begin = [[] for _ in range(n + 1)]
    end = [[] for _ in range(n + 1)]
    for s in range(nslots):
        if hi[s] >= 0:
            begin[lo[s]].append(s)
            end[hi[s]].append(s)
    where = [-1] * nslots
    for s in range(nparams):
        where[s] = s
    count = nparams
    free = []
    for k in range(n + 1):
        for s in begin[k]:
            if s >= nparams:
                if free:
                    where[s] = free.pop()
                else:
                    where[s] = count
                    count += 1
        for s in end[k]:
            free.append(where[s])
    return where, count


# ---- one function's code ----------------------------------------------------


class Body:
    """The instructions of one function body."""

    def __init__(self):
        self.b = bytearray()

    def op(self, *bs):
        self.b.extend(bs)

    def i64(self, n):
        self.op(0x42)
        self.b.extend(sleb(signed64(n)))

    def i32(self, n):
        self.op(0x41)
        self.b.extend(sleb(n))

    def get(self, i):
        self.op(0x20)
        self.b.extend(uleb(i))

    def set(self, i):
        self.op(0x21)
        self.b.extend(uleb(i))

    def tee(self, i):
        self.op(0x22)
        self.b.extend(uleb(i))

    def mem(self, opcode, align, offset, prefix=None):
        if prefix is not None:
            self.op(prefix)
            self.b.extend(uleb(opcode))
        else:
            self.op(opcode)
        self.b.extend(uleb(align))
        self.b.extend(uleb(offset))

    def call(self, index):
        self.op(0x10)
        self.b.extend(uleb(index))

    def br(self, depth):
        self.op(0x0C)
        self.b.extend(uleb(depth))

    def br_if(self, depth):
        self.op(0x0D)
        self.b.extend(uleb(depth))


# opcodes
I64_EQZ, I64_EQ, I64_NE, I64_LT_S, I64_GT_S, I64_LE_S, I64_GE_S = 0x50, 0x51, 0x52, 0x53, 0x55, 0x57, 0x59
I32_EQZ, I32_AND, I32_OR, I32_WRAP, I64_EXTEND_U = 0x45, 0x71, 0x72, 0xA7, 0xAD
I64_ADD, I64_SUB, I64_MUL, I64_DIV_S, I64_REM_S = 0x7C, 0x7D, 0x7E, 0x7F, 0x81
I64_AND, I64_OR, I64_XOR, I64_SHL, I64_SHR_S, I64_SHR_U = 0x83, 0x84, 0x85, 0x86, 0x87, 0x88
F64_EQ, F64_LT, F64_GE = 0x61, 0x63, 0x66
F64_ADD, F64_SUB, F64_MUL, F64_DIV = 0xA0, 0xA1, 0xA2, 0xA3
I64_TRUNC_F64_S, F64_CONVERT_I64_S, I64_REINTERPRET, F64_REINTERPRET = 0xB0, 0xB9, 0xBD, 0xBF
LOAD64, LOAD8U, STORE64, STORE8 = 0x29, 0x31, 0x37, 0x3C
ATOMIC, RMW_ADD64 = 0xFE, 0x1F
BLOCK, LOOP, IF, ELSE, END, RETURN, DROP, UNREACHABLE = 0x02, 0x03, 0x04, 0x05, 0x0B, 0x0F, 0x1A, 0x00
VOID = 0x40
CMP = {"<": I64_LT_S, ">": I64_GT_S, "<=": I64_LE_S, ">=": I64_GE_S, "==": I64_EQ, "!=": I64_NE}
HEAP_BIT = 1 << 32


class Module:
    def __init__(self, plus_events, fns):
        self.plus_events = plus_events
        self.fns = fns
        self.types = []                 # (params, results)
        self.imports = []               # (lib, func, type index, float)
        self.import_at = {}
        self.data = bytearray()
        self.strings = {}
        self.index = {}                 # function name -> (function index, nparams)
        self.table = {}                 # function name -> table index

    def type_of(self, params, results):
        t = (tuple(params), tuple(results))
        if t not in self.types:
            self.types.append(t)
        return self.types.index(t)

    def fn_type(self, nparams):
        return self.type_of([I64] * (2 * nparams), [I64, I64])

    def imported(self, lib, func, n, floats):
        key = (lib, func, n, floats)
        if key not in self.import_at:
            vt = F64 if floats else I64
            self.import_at[key] = len(self.imports)
            self.imports.append((lib, func, self.type_of([vt] * n, [vt]), floats))
        return self.import_at[key]

    def string(self, text):
        raw = text.encode("utf-8")
        while len(self.data) % 8:
            self.data.append(0)
        at = DATA + len(self.data)
        self.data.extend(struct.pack("<qqqq", 0, 0, len(raw), len(text)))
        self.data.extend(raw)
        return at

    # the imports and types, before any function index or body: the imports'
    # types, then each function's, then each callv's, then the entries'
    def collect(self):
        self.imported("KERNEL32.DLL", "ExitProcess", 1, False)
        for fn in self.fns:
            for ins in fn[4]:
                if ins[0] in ("extern", "externf"):
                    self.imported(ins[2], ins[3], len(ins[4]), ins[0] == "externf")
        for fn in self.fns:
            self.fn_type(fn[2])
        for fn in self.fns:
            for ins in fn[4]:
                if ins[0] == "callv":
                    self.fn_type(len(ins[2]))
        self.type_of([], [])
        self.type_of([I64], [I64])

    def build(self):
        self.collect()
        base = len(self.imports)
        for k, fn in enumerate(self.fns):
            if fn[1] in self.index:
                raise IRError("two functions are both " + fn[1])
            self.index[fn[1]] = (base + k, fn[2])
            self.table[fn[1]] = k
        n = len(self.fns)
        self.main_index = base + n
        self.thread_index = base + n + 1
        self.init_index = base + n + 2
        self.thread_table = n
        bodies = [self.function(fn) for fn in self.fns]
        bodies.append(self.entry_main())
        bodies.append(self.entry_thread())
        bodies.append(self.entry_init())
        fn_types = [self.fn_type(fn[2]) for fn in self.fns]
        fn_types.append(self.type_of([], []))
        fn_types.append(self.type_of([I64], [I64]))
        fn_types.append(self.type_of([], []))
        return self.encode(fn_types, bodies)

    # ---- slots: in pair p (see slot_locals), the type word in local 2p and
    # the data word in local 2p+1 ----

    def function(self, fn):
        _, fname, nparams, nslots, instrs, _vars = fn
        where, npairs = slot_locals(nparams, nslots, instrs)
        self.T = lambda s: 2 * where[s]
        self.D = lambda s: 2 * where[s] + 1
        self.A = 2 * npairs
        self.X = self.A + 1
        b = Body()
        self.b = b
        # segments: code before the first label, then one per label
        seg_of = {}
        nseg = 1
        for ins in instrs:
            if ins[0] == "label":
                seg_of[ins[1]] = nseg
                nseg += 1
        self.seg_of = seg_of
        self.nseg = nseg
        self.seg = 0
        self.plan = structure(instrs, seg_of, nseg)
        if self.plan is None:
            raise IRError("control flow the WASM form cannot lay out, in " + fname)
        self.stack = []
        self.open_at(0)
        for k, ins in enumerate(instrs):
            self.last = k + 1 == len(instrs) or instrs[k + 1][0] == "label"
            self.instruction(fname, ins)
        self.close_after(nseg - 1)
        if self.stack:
            raise IRError("constructs left open in " + fname)
        b.op(UNREACHABLE)
        b.op(END)
        locals_ = []
        if npairs > nparams:
            locals_.append(uleb(2 * (npairs - nparams)) + bytes([I64]))
        locals_.append(uleb(1) + bytes([I32]))
        locals_.append(uleb(1) + bytes([I64]))
        return vec(locals_) + bytes(b.b)

    # ---- the structured layout (see structure()) ----

    def open_at(self, p):
        for kind, last, key in self.plan[p]:
            self.b.op(LOOP if kind == "loop" else BLOCK, VOID)
            self.stack.append((kind, key, last))

    def close_after(self, q):
        while self.stack and self.stack[-1][2] == q:
            self.b.op(END)
            self.stack.pop()
        for _kind, _key, last in self.stack:
            if last == q:
                raise IRError("constructs that do not nest")

    def depth(self, target):
        """The br depth from here to segment target: the block ending just
        before it, or the loop it heads."""
        kind = "block" if target > self.seg else "loop"
        for k in range(len(self.stack) - 1, -1, -1):
            if self.stack[k][0] == kind and self.stack[k][1] == target:
                return len(self.stack) - 1 - k
        raise IRError("no construct for a jump to segment %d" % target)

    def go(self, target):
        if not (self.last and target == self.seg + 1):
            self.b.br(self.depth(target))

    def go_if(self, t, f):
        """With the condition on the stack: to t when it is true, else to f."""
        b = self.b
        nxt = self.seg + 1
        if self.last and f == nxt:
            if t == nxt:
                b.op(DROP)
            else:
                b.br_if(self.depth(t))
        elif self.last and t == nxt:
            b.op(I32_EQZ)
            b.br_if(self.depth(f))
        else:
            b.br_if(self.depth(t))
            b.br(self.depth(f))

    def set_int(self, d):               # slot d = the int on the stack
        self.b.set(self.D(d))
        self.b.i64(2)
        self.b.set(self.T(d))

    def set_bool(self, d):              # slot d = the i32 0 or 1 on the stack
        self.b.op(I64_EXTEND_U)
        self.b.set(self.D(d))
        self.b.i64(1)
        self.b.set(self.T(d))

    def set_unit(self, d):
        self.b.i64(0)
        self.b.set(self.T(d))
        self.b.i64(0)
        self.b.set(self.D(d))

    def set_result(self, d):            # slot d = the (type, data) on the stack
        self.b.set(self.D(d))
        self.b.set(self.T(d))

    def push(self, s):
        self.b.get(self.T(s))
        self.b.get(self.D(s))

    def call(self, fname, slots, d):
        if fname not in self.index:
            raise IRError("a call to " + fname + ", which the IR lacks")
        at, nparams = self.index[fname]
        if nparams != len(slots):
            raise IRError("%s takes %d, called with %d" % (fname, nparams, len(slots)))
        for s in slots:
            self.push(s)
        self.b.call(at)
        if d is None:
            self.b.op(DROP, DROP)
        else:
            self.set_result(d)

    def call_ints(self, fname, values):
        """Calls fname with ints, each pushed by a function; drops the result."""
        at, nparams = self.index[fname]
        if nparams != len(values):
            raise IRError("%s takes %d" % (fname, nparams))
        for v in values:
            self.b.i64(2)
            v()
        self.b.call(at)
        self.b.op(DROP, DROP)

    def addr(self, s):                  # the i32 address in slot s's data word
        self.b.get(self.D(s))
        self.b.op(I32_WRAP)

    def addr2(self, a, o):              # the i32 address a + o
        self.b.get(self.D(a))
        self.b.get(self.D(o))
        self.b.op(I64_ADD, I32_WRAP)

    def heap(self, s):                  # i32: is slot s's heap bit set
        b = self.b
        b.get(self.T(s))
        b.i64(HEAP_BIT)
        b.op(I64_AND)
        b.i64(0)
        b.op(I64_NE)

    def count(self, which, s):
        b = self.b
        self.heap(s)
        b.op(IF, VOID)
        self.addr(s)
        b.i64(1 if which == "retain" else -1)
        b.mem(RMW_ADD64, 3, 0, prefix=ATOMIC)
        b.tee(self.X)
        b.i64(1)
        b.op(I64_LT_S if which == "retain" else I64_LE_S)
        b.op(IF, VOID)
        if which == "retain":
            self.call_ints_none("rt_fail_released_twice")
        else:
            self.call_ints("rt_release_last", [lambda: b.get(self.T(s)), lambda: b.get(self.D(s)),
                                               lambda: b.get(self.X)])
        b.op(END)
        b.op(END)

    def call_ints_none(self, fname):
        at, nparams = self.index[fname]
        if nparams != 0:
            raise IRError(fname + " takes arguments")
        self.b.call(at)
        self.b.op(DROP, DROP)

    def is_class(self, s, cls):         # i32: slot s's type word == cls
        self.b.get(self.T(s))
        self.b.i64(cls)
        self.b.op(I64_EQ)

    def op(self, op, d, a, c):
        b = self.b
        if op not in OP_FN:
            raise IRError("unknown operator " + op)
        b.op(BLOCK, VOID)               # done
        b.op(BLOCK, VOID)               # slow
        if op != "/":
            self.is_class(a, 2)
            self.is_class(c, 2)
            b.op(I32_AND, I32_EQZ)
            b.br_if(0)
            if op in ("+", "a+") and self.plus_events:
                b.i32(STATE)
                b.mem(LOAD64, 3, 2064)
                b.i64(0)
                b.op(I64_NE)
                b.br_if(0)
            if op in CMP:
                b.get(self.D(a))
                b.get(self.D(c))
                b.op(CMP[op])
                self.set_bool(d)
            elif op in ("band", "bor", "bxor", "shl", "shr"):
                b.get(self.D(a))
                b.get(self.D(c))
                b.op({"band": I64_AND, "bor": I64_OR, "bxor": I64_XOR, "shl": I64_SHL, "shr": I64_SHR_S}[op])
                self.set_int(d)
            elif op == "%":
                b.get(self.D(c))
                b.op(I64_EQZ)
                b.br_if(0)
                b.get(self.D(a))
                b.get(self.D(c))
                b.op(I64_REM_S)
                self.set_int(d)
            elif op in ("+", "q+", "a+", "-"):
                # overflow: for +, a and b agree in sign and r does not;
                # for -, a and b differ in sign and r differs from a
                b.get(self.D(a))
                b.get(self.D(c))
                b.op(I64_ADD if op != "-" else I64_SUB)
                b.set(self.X)
                if op == "-":
                    b.get(self.D(a))
                    b.get(self.D(c))
                    b.op(I64_XOR)
                    b.get(self.D(a))
                    b.get(self.X)
                    b.op(I64_XOR)
                else:
                    b.get(self.D(a))
                    b.get(self.X)
                    b.op(I64_XOR)
                    b.get(self.D(c))
                    b.get(self.X)
                    b.op(I64_XOR)
                b.op(I64_AND)
                b.i64(0)
                b.op(I64_LT_S)
                b.br_if(0)
                b.get(self.X)
                self.set_int(d)
            else:                       # *
                # b == -1 overflows only at a == MIN; otherwise r / b == a
                # unless it overflowed, b == 0 giving 0
                b.get(self.D(a))
                b.get(self.D(c))
                b.op(I64_MUL)
                b.set(self.X)
                b.get(self.D(c))
                b.i64(-1)
                b.op(I64_EQ)
                b.op(IF, VOID)
                b.get(self.D(a))
                b.i64(MIN64)
                b.op(I64_EQ)
                b.br_if(1)              # slow, past the if
                b.op(ELSE)
                b.get(self.D(c))
                b.i64(0)
                b.op(I64_NE)
                b.op(IF, VOID)
                b.get(self.X)
                b.get(self.D(c))
                b.op(I64_DIV_S)
                b.get(self.D(a))
                b.op(I64_NE)
                b.br_if(2)              # slow, past both ifs
                b.op(END)
                b.op(END)
                b.get(self.X)
                self.set_int(d)
            b.br(1)                     # done
        b.op(END)                       # slow
        self.call(OP_FN[op], [a, c], d)
        b.op(END)                       # done

    def un(self, op, d, a):
        b = self.b
        b.op(BLOCK, VOID)
        b.op(BLOCK, VOID)
        self.is_class(a, 1 if op == "not" else 2)
        b.op(I32_EQZ)
        b.br_if(0)
        if op == "-":
            b.get(self.D(a))
            b.i64(MIN64)
            b.op(I64_EQ)
            b.br_if(0)
            b.i64(0)
            b.get(self.D(a))
            b.op(I64_SUB)
            self.set_int(d)
        elif op == "bnot":
            b.get(self.D(a))
            b.i64(-1)
            b.op(I64_XOR)
            self.set_int(d)
        elif op == "not":
            b.get(self.D(a))
            b.i64(1)
            b.op(I64_XOR)
            b.set(self.D(d))
            b.i64(1)
            b.set(self.T(d))
        else:
            raise IRError("unknown unary operator " + op)
        b.br(1)
        b.op(END)
        self.call({"-": "op_neg", "bnot": "op_bnot", "not": "op_not"}[op], [a], d)
        b.op(END)

    def prim(self, pname, d, args):
        b = self.b
        if pname == "value_class":
            b.get(self.T(args[0]))
            b.i64(0xFFFFFFFF)
            b.op(I64_AND)
            return self.set_int(d)
        if pname == "value_data":
            b.get(self.D(args[0]))
            return self.set_int(d)
        if pname == "value_type_word":
            b.get(self.T(args[0]))
            return self.set_int(d)
        if pname == "value_make":
            b.get(self.D(args[0]))
            b.get(self.D(args[1]))
            return self.set_result(d)
        if pname == "value_live":
            a = args[0]
            # no bit above 33, and a class of 13 or less or 63 or more
            b.get(self.T(a))
            b.i64(34)
            b.op(I64_SHR_U, I64_EQZ)
            b.get(self.T(a))
            b.i64(0xFFFFFFFF)
            b.op(I64_AND)
            b.tee(self.X)
            b.i64(13)
            b.op(I64_LE_S)
            b.get(self.X)
            b.i64(63)
            b.op(I64_GE_S)
            b.op(I32_OR, I32_AND)
            b.op(IF, I32)
            self.heap(a)
            b.op(IF, I32)
            self.addr(a)
            b.mem(LOAD64, 3, 0)
            b.i64(1)
            b.op(I64_GE_S)
            b.op(ELSE)
            b.i32(1)
            b.op(END)
            b.op(ELSE)
            b.i32(0)
            b.op(END)
            return self.set_bool(d)
        if pname == "runtime_state":
            b.i64(STATE)
            return self.set_int(d)
        if pname == "thread_entry_address":
            b.i64(self.thread_table)
            return self.set_int(d)
        if pname == "atomic_add":
            self.addr(args[0])
            b.get(self.D(args[1]))
            b.mem(RMW_ADD64, 3, 0, prefix=ATOMIC)
            return self.set_int(d)
        if pname in ("mem_load_value", "mem_take_value"):
            self.addr2(args[0], args[1])
            b.set(self.A)
            self.at_y()
            b.mem(LOAD64, 3, 0)
            b.set(self.T(d))
            self.at_y()
            b.mem(LOAD64, 3, 8)
            b.set(self.D(d))
            if pname == "mem_load_value":
                return self.count("retain", d)
            self.at_y()
            b.i64(0)
            b.mem(STORE64, 3, 0)
            self.at_y()
            b.i64(0)
            b.mem(STORE64, 3, 8)
            return
        if pname in ("mem_store_value", "mem_init_value"):
            v = args[2]
            self.count("retain", v)
            self.addr2(args[0], args[1])
            b.set(self.A)
            if pname == "mem_store_value":
                self.at_y()
                b.mem(LOAD64, 3, 0)
                b.set(self.T(d))
                self.at_y()
                b.mem(LOAD64, 3, 8)
                b.set(self.D(d))
                self.count("release", d)
            self.at_y()
            b.get(self.T(v))
            b.mem(STORE64, 3, 0)
            self.at_y()
            b.get(self.D(v))
            b.mem(STORE64, 3, 8)
            return self.set_unit(d)
        if pname in ("mem_load", "mem_load_byte"):
            self.addr2(args[0], args[1])
            if pname == "mem_load":
                b.mem(LOAD64, 3, 0)
            else:
                b.mem(LOAD8U, 0, 0)
            return self.set_int(d)
        if pname in ("mem_store", "mem_store_byte"):
            self.addr2(args[0], args[1])
            b.get(self.D(args[2]))
            if pname == "mem_store":
                b.mem(STORE64, 3, 0)
            else:
                b.mem(STORE8, 0, 0)
            return self.set_unit(d)
        if pname == "int_to_float":
            b.get(self.D(args[0]))
            b.op(F64_CONVERT_I64_S, I64_REINTERPRET)
            return self.set_int(d)
        if pname == "float_to_int":
            # truncating, and the minimum int when out of range or NaN, as
            # cvttsd2si gives
            self.f64_of(args[0])
            self.f64_const(-9223372036854775808.0)
            b.op(F64_GE)
            self.f64_of(args[0])
            self.f64_const(9223372036854775808.0)
            b.op(F64_LT)
            b.op(I32_AND)
            b.op(IF, I64)
            self.f64_of(args[0])
            b.op(I64_TRUNC_F64_S)
            b.op(ELSE)
            b.i64(MIN64)
            b.op(END)
            return self.set_int(d)
        if pname in ("float_add", "float_sub", "float_mul", "float_div"):
            self.f64_of(args[0])
            self.f64_of(args[1])
            b.op({"float_add": F64_ADD, "float_sub": F64_SUB, "float_mul": F64_MUL, "float_div": F64_DIV}[pname])
            b.op(I64_REINTERPRET)
            return self.set_int(d)
        if pname in ("float_lt", "float_eq"):
            self.f64_of(args[0])
            self.f64_of(args[1])
            b.op(F64_LT if pname == "float_lt" else F64_EQ)
            b.op(I64_EXTEND_U)
            return self.set_int(d)
        if pname.startswith("word_"):
            ops = {"word_add": I64_ADD, "word_sub": I64_SUB, "word_mul": I64_MUL, "word_and": I64_AND,
                   "word_or": I64_OR, "word_xor": I64_XOR, "word_shl": I64_SHL, "word_shr": I64_SHR_U,
                   "word_div": I64_DIV_S, "word_rem": I64_REM_S}
            if pname not in ops:
                raise IRError("unknown primitive " + pname)
            b.get(self.D(args[0]))
            b.get(self.D(args[1]))
            b.op(ops[pname])
            return self.set_int(d)
        raise IRError("unknown primitive " + pname)

    def at_y(self):                     # the address kept in A
        self.b.get(self.A)

    def f64_of(self, s):
        self.b.get(self.D(s))
        self.b.op(F64_REINTERPRET)

    def f64_const(self, x):
        self.b.op(0x44)
        self.b.b.extend(struct.pack("<d", x))

    def const(self, d, kind, text):
        b = self.b
        text = str(text)
        if kind == "str":
            b.i64(8)
            b.set(self.T(d))
            b.i64(self.string(text))
            b.set(self.D(d))
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
        b.i64(cls)
        b.set(self.T(d))
        b.i64(bits)
        b.set(self.D(d))

    def fill(self, d, slots):
        b = self.b
        for k, s in enumerate(slots):
            self.count("retain", s)
            self.addr(d)
            b.get(self.T(s))
            b.mem(STORE64, 3, 32 + 16 * k)
            self.addr(d)
            b.get(self.D(s))
            b.mem(STORE64, 3, 40 + 16 * k)

    def alloc(self, fname, d, n):
        at, nparams = self.index[fname]
        self.b.i64(2)
        self.b.i64(n)
        self.b.call(at)
        self.set_result(d)

    def instruction(self, fname, ins):
        b = self.b
        op = ins[0]
        if op == "const":
            self.const(ins[1], ins[2], ins[3])
        elif op in ("copy", "move"):
            self.push(ins[2])
            self.set_result(ins[1])
            if op == "move":
                b.i64(0)
                b.set(self.T(ins[2]))
        elif op == "clear":
            b.i64(0)
            b.set(self.T(ins[1]))
        elif op == "call":
            self.call(ins[2], ins[3], ins[1])
        elif op == "op":
            self.op(ins[2], ins[1], ins[3], ins[4])
        elif op == "un":
            self.un(ins[2], ins[1], ins[3])
        elif op == "prim":
            self.prim(ins[2], ins[1], ins[3])
        elif op in ("extern", "externf"):
            floats = op == "externf"
            for s in ins[4]:
                b.get(self.D(s))
                if floats:
                    b.op(F64_REINTERPRET)
            b.call(self.imported(ins[2], ins[3], len(ins[4]), floats))
            if floats:
                b.op(I64_REINTERPRET)
            self.set_int(ins[1])
        elif op == "label":
            # falls into the next segment
            self.close_after(self.seg)
            self.seg = self.seg_of[ins[1]]
            self.open_at(self.seg)
        elif op == "jump":
            self.go(self.seg_of[ins[1]])
        elif op == "branch":
            s = ins[1]
            b.get(self.T(s))
            b.i64(2)
            b.op(I64_LE_S)
            b.op(IF, I32)
            b.get(self.D(s))
            b.i64(0)
            b.op(I64_NE)
            b.op(ELSE)
            at, _ = self.index["rt_truthy"]
            self.push(s)
            b.call(at)
            b.set(self.X)
            b.op(DROP)
            b.get(self.X)
            b.i64(0)
            b.op(I64_NE)
            b.op(END)
            self.go_if(self.seg_of[ins[2]], self.seg_of[ins[3]])
        elif op == "return":
            self.push(ins[1])
            b.op(RETURN)
        elif op in ("retain", "release"):
            self.count(op, ins[1])
        elif op == "list":
            self.alloc("rt_list_alloc", ins[1], len(ins[2]))
            self.fill(ins[1], ins[2])
        elif op == "closure":
            if ins[2] not in self.table:
                raise IRError("a closure of " + ins[2] + ", which the IR lacks")
            self.alloc("rt_closure_alloc", ins[1], len(ins[3]))
            self.addr(ins[1])
            b.i64(self.table[ins[2]])
            b.mem(STORE64, 3, 16)
            self.fill(ins[1], ins[3])
        elif op == "callv":
            slots = ins[2]
            for s in slots:
                self.push(s)
            self.addr(slots[0])
            b.mem(LOAD64, 3, 16)
            b.op(I32_WRAP)
            b.op(0x11)
            b.b.extend(uleb(self.fn_type(len(slots))))
            b.op(0x00)
            self.set_result(ins[1])
        else:
            raise IRError("unknown instruction " + op + " in " + fname)

    # ---- the entries ----

    def entry_main(self):
        b = Body()
        self.b = b
        for f in ("runtime_init", "__main"):
            at, nparams = self.index[f]
            if nparams:
                raise IRError(f + " takes arguments")
            b.call(at)
            b.op(DROP, DROP)
        b.i64(0)
        b.call(self.import_at[("KERNEL32.DLL", "ExitProcess", 1, False)])
        b.op(DROP)
        b.op(END)
        return vec([]) + bytes(b.b)

    def entry_thread(self):
        b = Body()
        at, nparams = self.index["rt_thread_main"]
        b.i64(2)
        b.get(0)
        b.call(at)
        b.op(DROP, DROP)
        b.i64(0)
        b.op(END)
        return vec([]) + bytes(b.b)

    def entry_init(self):
        b = Body()
        b.i32(DATA)
        b.i32(0)
        b.i32(len(self.data))
        b.op(0xFC)
        b.b.extend(uleb(8))
        b.b.extend(uleb(0))
        b.op(0x00)
        b.op(0xFC)
        b.b.extend(uleb(9))
        b.b.extend(uleb(0))
        b.op(END)
        return vec([]) + bytes(b.b)

    # ---- the module ----

    def encode(self, fn_types, bodies):
        out = bytearray(b"\0asm" + struct.pack("<I", 1))
        out += section(1, vec([b"\x60" + vec([bytes([p]) for p in ps]) + vec([bytes([r]) for r in rs])
                               for ps, rs in self.types]))
        pages = (DATA + len(self.data) + PAGE - 1) // PAGE
        imports = [name("env") + name("memory") + b"\x02\x03" + uleb(pages) + uleb(MAX_PAGES)]
        for lib, func, t, _ in self.imports:
            imports.append(name(lib) + name(func) + b"\x00" + uleb(t))
        out += section(2, vec(imports))
        out += section(3, vec([uleb(t) for t in fn_types]))
        ntable = len(self.fns) + 1
        out += section(4, vec([b"\x70\x00" + uleb(ntable)]))
        exports = [name("main") + b"\x00" + uleb(self.main_index),
                   name("thread_entry") + b"\x00" + uleb(self.thread_index),
                   name("init_memory") + b"\x00" + uleb(self.init_index),
                   name("table") + b"\x01" + uleb(0)]
        out += section(7, vec(exports))
        base = len(self.imports)
        elems = [uleb(base + k) for k in range(len(self.fns))] + [uleb(self.thread_index)]
        out += section(9, vec([b"\x00\x41\x00\x0B" + vec(elems)]))
        out += section(12, uleb(1))
        out += section(10, vec([uleb(len(body)) + body for body in bodies]))
        out += section(11, vec([b"\x01" + uleb(len(self.data)) + bytes(self.data)]))
        names = [uleb(base + k) + name(fn[1]) for k, fn in enumerate(self.fns)]
        names += [uleb(self.main_index) + name("main"), uleb(self.thread_index) + name("thread_entry"),
                  uleb(self.init_index) + name("init_memory")]
        sub = vec(names)
        out += section(0, name("name") + b"\x01" + uleb(len(sub)) + sub)
        return bytes(out)


def main(argv):
    if len(argv) != 3:
        print("usage: ir_wasm.py IN.ir OUT.wasm")
        return 2
    try:
        plus_events, fns = read_ir(argv[1])
        wasm = Module(plus_events, fns).build()
    except IRError as e:
        print("ir_wasm error: " + str(e))
        return 1
    with open(argv[2], "wb") as f:
        f.write(wasm)
    print("ir_wasm: " + argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
