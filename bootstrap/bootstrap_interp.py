#!/usr/bin/env python3
"""
bootstrap_interp.py -- a minimal, standalone Python interpreter for
PatLang's own IR (the same list-shaped instruction format lower_program()
in self_hosting/lib/lower.patlang produces), built to prove out GitHub
#25's Piece 2: someone on a fresh machine with no PatLang/Rust tooling
installed at all should be able to take a saved `.ir` file (produced,
on ANY machine that already has PatLang, via `patc1.exe lower <src> <out.ir>`)
and run it using nothing but a language they already have -- Python was
chosen here as the most nearly-universal option (see the
"patlang-ir-bootstrap-python-interpreter-start" memory note for why).

This is a direct Python port of self_hosting/lib/interp.patlang's own
`interp_run_function`/`interp_call_host` -- the SAME stack-machine walk,
the SAME instruction set (Const/Load/Store/Bin/Un/Jump/JumpIfFalse/
Return/CallHost/BuildList/Call/MakeClosure/CallValue) -- just written in
Python instead of PatLang, so it can run on a machine where NO PatLang
runtime exists yet. Values are plain Python int/float/str/bool/list;
"Unit" is represented as None. No family-tag scheme at all (that's an
x64-native-codegen-only concept for a compact machine-word
representation; a tree-walking Python interpreter has no reason to
reinvent it).

SCOPE, matching interp.patlang's own header conventions: this file
implements the host-function surface the self-hosted COMPILER's own
source (self_hosting/build/patc1_all.patlang, i.e. lexer+parser+lower+
codegen_x64+x64_build+json+ir_io+includes+patc1_main) actually calls
while driving a `lower`/`emit_x64` compile -- core/strings_ext/
collections_handles/files/io_misc/math, the same "feature complete for
the stateless utility chunks" scope interp.patlang itself names. The
COMPILER's own logic never needs oo/logic/contracts/networking/process
primitives (those exist as CODE inside interp.patlang's own dispatch
table, which is PART of the bundled source, but that code path is only
REACHED if the "interpret" subcommand itself is invoked at runtime --
compiling a program never calls into it) -- so those are deliberately
NOT implemented here yet, a real gap to fill only if this bootstrap path
is ever asked to also run `patc1 interpret` standalone, not attempted in
this pass.

Usage:
    python bootstrap_interp.py <program.ir> [args passed to the IR's own main...]

Matches patc1.exe's own CLI shape: patc1_main.patlang's `main` reads
argv() and dispatches on args[0] ("lower"/"emit_x64"/"emit_rust"/
"interpret"), so a genuine end-to-end bootstrap looks like:

    python bootstrap_interp.py patc1_all.ir lower some_program.patlang some_program.ir
    python bootstrap_interp.py patc1_all.ir emit_x64 some_program.ir some_program.asm
    nasm -f win64 -o some_program.obj some_program.asm
    gcc -o some_program.exe some_program.obj x64_runtime.obj ...
"""

import sys
import os
import json
import shutil
import math
import time
import subprocess


class PatLangError(Exception):
    """An interpreter-internal error (unknown instruction, missing
    function, unsupported host call) -- mirrors interp.patlang's own
    ["Err", message] propagation, just as a real Python exception since
    this driver has no reason to thread a Result value through Python's
    own call stack the way PatLang (no try/catch) has to."""


# ---------------------------------------------------------------------------
# Value helpers -- PatLang's "+" auto-coerces a non-string operand to text
# when the OTHER operand is a string (confirmed directly against both
# pat --ir-run and the x64 backend earlier this session: `"n=" + n` for an
# int n prints "n=5", not a TypeError) -- Python's own `+` has no such
# coercion, so Bin "+" needs this explicit helper rather than bare `a + b`.
# ---------------------------------------------------------------------------

def patlang_display(v):
    if v is None:
        return ""
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, float):
        if v.is_integer():
            return str(int(v))
        return repr(v)
    if isinstance(v, list):
        return "[" + ", ".join(patlang_display(x) for x in v) + "]"
    return str(v)


def bin_add(a, b):
    if isinstance(a, str) or isinstance(b, str):
        return patlang_display(a) + patlang_display(b)
    return a + b


def bin_div(a, b):
    # Named, deliberate scope limit (see this file's own header): no
    # numeric-tower Rational promotion here, unlike the real interpreter's
    # `1/3 -> 1/2`-style exact-fraction behavior for SOME int/int cases --
    # the compiler's own source only ever divides lengths/indices, never
    # needs an exact fraction, so plain float division (with an exact-
    # int fast path for the common "evenly divides" case) is enough for
    # THIS bootstrap's actual job.
    if isinstance(a, int) and isinstance(b, int) and b != 0 and a % b == 0:
        return a // b
    return a / b


def interp_bin(op, a, b):
    if op == "+":
        return bin_add(a, b)
    if op == "-":
        return a - b
    if op == "*":
        return a * b
    if op == "/":
        return bin_div(a, b)
    if op == "%":
        # PatLang's % truncates toward the DIVIDEND's sign (confirmed:
        # -10 % 3 == -1), unlike Python's own %, which floors toward the
        # DIVISOR's sign (-10 % 3 == 2 in plain Python) -- found adding
        # the bitwise operators below and re-checking every operator
        # here against the real semantics rather than assuming Python's
        # own meaning matched.
        if isinstance(a, int) and isinstance(b, int):
            r = a % b
            if r != 0 and (r < 0) != (a < 0):
                r -= b
            return r
        return math.fmod(a, b)
    if op == "==":
        return a == b
    if op == "!=":
        return a != b
    if op == "<":
        return a < b
    if op == ">":
        return a > b
    if op == "<=":
        return a <= b
    if op == ">=":
        return a >= b
    if op == "and":
        return bool(a) and bool(b)
    if op == "or":
        return bool(a) or bool(b)
    if op == "band":
        return a & b
    if op == "bor":
        return a | b
    if op == "bxor":
        return a ^ b
    if op == "shl":
        return a << b
    if op == "shr":
        return a >> b
    raise PatLangError("unsupported binary operator '%s'" % op)


def interp_un(op, a):
    if op == "-":
        return 0 - a
    if op == "not":
        return not a
    if op == "bnot":
        return ~a
    raise PatLangError("unsupported unary operator '%s'" % op)


def interp_const(kind, text):
    if kind == "num":
        if "." in text or "e" in text or "E" in text:
            return float(text)
        return int(text)
    if kind == "bool":
        return text == "true"
    return text  # "str"


# ---------------------------------------------------------------------------
# Host function surface -- handle-based collections (vec_*/sb_*) need real
# mutable identity (a caller expects sb_push to affect EVERY holder of the
# same handle), matching x64_runtime.patlang's own g_vec_table/g_sb_table
# convention; ordinary lists (list_push/list_set) stay copy-on-write,
# matching PatLang's own value semantics for plain lists.
# ---------------------------------------------------------------------------

# Live progress, checked FROM INSIDE the actual run_function instruction
# loop (and the generated code's own per-block loop, once that exists --
# see GitHub #196) -- not just declared once outside it and forgotten.
# That's a standing, previously-hit failure mode on the PatLang side of
# this project (a status handler registered but never actually polled
# during the real work, so a caller can't tell "slow" from "stuck"): the
# exact same risk applies here, and this session's own 50+ minute,
# totally silent decisive-verification run was a live demonstration of
# it. A plain, periodically-rewritten JSON status file is this tool's
# own equivalent of PatLang's signal_query -- anyone (another process,
# or a person) can read it at any time to see what's happening right
# now, with no live request/response server to build. Throttled by a
# cheap instruction-count modulo check (not a time.time() call on every
# single instruction) so it costs effectively nothing in the hot path.
PROGRESS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "compile_status.json")
PROGRESS_EVERY_N = 20000


class Progress:
    def __init__(self, path=PROGRESS_PATH, every_n=PROGRESS_EVERY_N, min_interval_s=0.25):
        self.path = path
        self.every_n = every_n
        self.min_interval_s = min_interval_s
        self.count = 0
        self.start = time.time()
        self.last_write = 0.0

    def tick(self, **fields):
        self.count += 1
        if self.count % self.every_n != 0:
            return
        now = time.time()
        if now - self.last_write < self.min_interval_s:
            return
        self.last_write = now
        fields["elapsed_s"] = round(now - self.start, 1)
        fields["instructions_seen"] = self.count
        try:
            tmp = self.path + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(fields, f)
            os.replace(tmp, self.path)
        except OSError:
            pass  # best-effort: a failed status write must never break the actual compile


class HostState:
    def __init__(self, argv_list, funcs):
        self.progress = Progress()
        self.vecs = {}
        self.next_vec = 0
        self.sbs = {}
        self.next_sb = 0
        self.argv_list = argv_list
        self.funcs = funcs
        # Real classes -- turned out to be genuinely needed (not just
        # interp.patlang's own unrelated feature surface): the compiler's
        # own top-level source now declares real classes (ObjCache/
        # CompileUnit/X64UnitLinker/Interpreter, from this session's own
        # OO refactor work), and `class X { ... }` syntax's class_def
        # CallHost runs the moment "main" starts, before any compile
        # work happens at all. classes: name -> (field_defaults, methods).
        # namespaces: ONE unified store (name -> {key: value}), matching
        # x64_runtime.patlang's own rt_ns_get/rt_ns_set design exactly --
        # "__vars" is just one conventional namespace name among many,
        # an object's own handle name is another; get/set_var both read/
        # write through this same table regardless of which.
        self.classes = {}
        self.namespaces = {}
        # Process lifecycle -- genuinely needed (not interp.patlang's
        # unrelated surface): the compiler's own per-function object-
        # cache/linker (ObjCache/CompileUnit/X64UnitLinker) launches
        # nasm non-blocking via spawn()/wait() to assemble units in
        # parallel, and x64_build.patlang's own exec_capture drives
        # nasm/gcc directly for the final link.
        self.procs = {}
        self.next_pid = 1
        # In-memory VFS -- genuinely reached (not interp.patlang's unrelated
        # surface): signals.patlang/mailbox.patlang (both bundled, the
        # latter transitively via signals.patlang's own include) check
        # vfs_exists/etc as part of their own driver bookkeeping even
        # when host_caps() ultimately selects the "fs" driver elsewhere.
        # A plain dict is enough -- this process never outlives one
        # compile, so nothing needs to persist it to real disk.
        self.vfs = {}

    def ns(self, name):
        return self.namespaces.setdefault(name, {})


def call_host(name, args, state):
    if name == "list_get":
        l, i = args
        i = int(i)
        if isinstance(l, str):
            return l[i] if 0 <= i < len(l) else ""
        return l[i] if 0 <= i < len(l) else None
    if name == "list_len":
        return len(args[0])
    if name == "list_push":
        # Mutate in place, matching NATIVE x64's own already-shipped,
        # already-audited behavior (confirmed: "native list_push mutates
        # in place when the block has spare capacity... despite a
        # codegen note saying it is copy-on-write" -- see this project's
        # own gotchas notes) -- NOT PatLang's documented "lists are
        # immutable by value" ideal, but the real, load-bearing behavior
        # every accumulator-loop in this codebase (x64_compile_unit.
        # patlang's own x64_chunk_to_bin, x64_asm.patlang, etc.) is
        # ALREADY written and audited to require, specifically BECAUSE
        # native x64 behaves this way. The original copy-and-return-new
        # version reintroduced the EXACT O(n^2) bug x64_chunk_to_bin's
        # own header comment documents as GitHub #75 ("turned this
        # encoder from seconds into did not finish in 38 minutes") --
        # confirmed here too: compiling a trivial 4-line program via
        # --x64 under this interpreter needed 900M+ block-transitions
        # and was still running after 15 minutes, with the per-item rate
        # visibly collapsing as the accumulator grew (668K/s -> 34K/s),
        # the textbook signature of a hidden O(n^2).
        args[0].append(args[1])
        return args[0]
    if name == "list_set":
        args[0][int(args[1])] = args[2]
        return args[0]
    if name == "type_of":
        v = args[0]
        if isinstance(v, bool):
            return "bool"
        if isinstance(v, int):
            return "int"
        if isinstance(v, float):
            return "float"
        if isinstance(v, str):
            return "string"
        if isinstance(v, list):
            return "list"
        return "unit"
    if name == "bit_get":
        v, i = args
        return (v >> i) & 1
    if name == "bit_set":
        v, i, b = args
        if b:
            return v | (1 << i)
        return v & ~(1 << i)
    if name == "bit_slice":
        v, lo, width = args
        return (v >> lo) & ((1 << width) - 1)
    if name == "bit_set_slice":
        v, lo, width, val = args
        mask = ((1 << width) - 1) << lo
        return (v & ~mask) | ((val << lo) & mask)
    if name == "char_code":
        s, i = args
        return ord(s[int(i)])
    if name == "substr":
        s, start, length = args
        start = int(start)
        length = int(length)
        return s[start:start + length]
    if name == "chr":
        return chr(int(args[0]))
    if name == "to_num":
        # Matches hosts.rs's host_to_num exactly: Int/Float/BigInt/
        # Rational pass through unchanged; a String is parsed; anything
        # else (Unit/None, Bool, List) falls back to 0 -- NOT an error.
        # bool is checked before int/float since Python's bool is a
        # subclass of int (isinstance(True, int) is True), which would
        # otherwise return True/False themselves instead of matching
        # Rust's real "anything non-numeric falls back to 0" fallback.
        s = args[0]
        if isinstance(s, bool):
            return 0
        if isinstance(s, (int, float)):
            return s
        if not isinstance(s, str):
            return 0
        try:
            if "." in s:
                return float(s)
            return int(s)
        except ValueError:
            return 0
    if name == "hash_string":
        # FNV-1a 64-bit, over UTF-8 bytes, 16 lowercase hex digits -- must
        # match hosts.rs's host_hash_string EXACTLY (hashes computed here
        # are compared against fingerprint files written by the real
        # native hash_string, e.g. x64_runtime.fingerprint/patc1.fingerprint).
        # A prior version of this used 32-bit FNV-1a parameters, which
        # produced a completely different digest for the same input --
        # every build-cache staleness check against a fingerprint written
        # by the real interpreter then spuriously failed every time,
        # regardless of whether the underlying files had actually
        # changed. Found re-verifying GitHub #25 Piece 2: the compiler's
        # own staleness gate reported x64_runtime.obj as stale even
        # immediately after a genuine, fresh rebuild.
        h = 0xcbf29ce484222325
        for b in args[0].encode("utf-8"):
            h = ((h ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
        return format(h, "016x")
    if name == "vec_new":
        handle = state.next_vec
        state.next_vec += 1
        state.vecs[handle] = []
        return handle
    if name == "vec_push":
        state.vecs[args[0]].append(args[1])
        return None
    if name == "vec_set":
        state.vecs[args[0]][int(args[1])] = args[2]
        return None
    if name == "vec_get":
        return state.vecs[args[0]][int(args[1])]
    if name == "vec_len":
        return len(state.vecs[args[0]])
    if name == "vec_to_list":
        return list(state.vecs[args[0]])
    if name == "str_intern":
        return args[0]
    if name == "sc_len":
        return len(args[0])
    if name == "sc_code":
        return ord(args[0][int(args[1])])
    if name == "sc_char":
        return args[0][int(args[1])]
    if name == "sb_new":
        handle = state.next_sb
        state.next_sb += 1
        state.sbs[handle] = []
        return handle
    if name == "sb_push":
        state.sbs[args[0]].append(patlang_display(args[1]))
        return None
    if name == "sb_str":
        return "".join(state.sbs[args[0]])
    if name == "read_file":
        # newline="" disables Python's universal-newline translation --
        # without it, a CRLF file (this repo's own convention on Windows,
        # confirmed via `file lexer.patlang`) reads back with every \r
        # silently stripped, while Rust's read_to_string (hosts.rs) reads
        # the raw bytes verbatim, \r\n intact. Any hash_string(read_file(...))
        # comparison against a fingerprint written by the real interpreter
        # then mismatches on byte count alone, regardless of hash_string's
        # own algorithm being correct -- found immediately after fixing
        # hash_string itself and still seeing the same staleness failure.
        with open(args[0], "r", encoding="utf-8", newline="") as f:
            return f.read()
    if name == "write_file":
        path = args[0]
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(args[1])
        return True
    if name == "getenv":
        return os.environ.get(args[0], "")
    if name == "write_file_bytes":
        # write_file_bytes(path, byte_list) -> True. Raw binary output
        # (a PE image, machine code) -- write_file's own UTF-8 text
        # mode can't represent arbitrary byte sequences at all, same
        # reason hosts.rs itself special-cases this one primitive.
        path, byte_list = args
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        out = bytearray()
        for i, b in enumerate(byte_list):
            n = int(b)
            if not (0 <= n <= 255):
                raise PatLangError("write_file_bytes: byte at index %d (%d) is out of range 0-255" % (i, n))
            out.append(n)
        with open(path, "wb") as f:
            f.write(bytes(out))
        return True
    if name == "touch_file":
        path = args[0]
        parent = os.path.dirname(path)
        if parent:
            os.makedirs(parent, exist_ok=True)
        open(path, "w", encoding="utf-8").close()
        return "OK " + os.path.abspath(path)
    if name == "file_exists":
        return "1" if os.path.exists(args[0]) else "0"
    if name == "list_dir":
        entries = []
        for entry in sorted(os.listdir(args[0])):
            full = os.path.join(args[0], entry)
            entries.append(entry + "/" if os.path.isdir(full) else entry)
        return entries
    if name == "rename_file":
        os.rename(args[0], args[1])
        return True
    if name == "copy_file":
        try:
            shutil.copyfile(args[0], args[1])
            return "OK " + os.path.abspath(args[1])
        except OSError as e:
            return "ERR: %s" % e
    if name == "now_ms":
        return int(time.time() * 1000)
    if name == "byte_length":
        return len(args[0].encode("utf-8"))
    if name == "read_line":
        line = sys.stdin.readline()
        return line.rstrip("\r\n") if line else ""
    if name == "argv":
        return list(state.argv_list)
    if name == "print":
        print(patlang_display(args[0]) if args else "")
        return None
    if name == "len":
        return len(args[0])
    if name == "sqrt":
        return math.sqrt(args[0])
    if name == "pow":
        return math.pow(args[0], args[1])
    if name == "sin":
        return math.sin(args[0])
    if name == "cos":
        return math.cos(args[0])
    if name == "tan":
        return math.tan(args[0])
    if name == "asin":
        return math.asin(args[0])
    if name == "acos":
        return math.acos(args[0])
    if name == "atan":
        return math.atan(args[0])
    if name == "atan2":
        return math.atan2(args[0], args[1])
    if name == "log":
        return math.log(args[0])
    if name == "exp":
        return math.exp(args[0])
    if name == "floor":
        return math.floor(args[0])
    if name == "ceil":
        return math.ceil(args[0])
    if name == "round":
        return round(args[0])
    if name == "trunc":
        return math.trunc(args[0])
    if name == "abs":
        return abs(args[0])
    if name == "to_fixed":
        return format(args[0], ".%df" % int(args[1]))
    if name == "numeric_kind":
        return "float" if isinstance(args[0], float) else "int"
    if name == "class_def":
        cname, parent, field_defaults, methods, traits = args
        state.classes[cname] = (field_defaults, methods)
        return None
    if name == "new":
        cname, handle = args
        ns = state.ns(handle)
        entry = state.classes.get(cname)
        if entry:
            for pair in entry[0]:
                ns[pair[0]] = pair[1]
        ns["type"] = cname
        return handle
    if name == "get":
        store, key = args
        return state.ns(store).get(key)
    if name == "set_var":
        # Overloaded on arg count, matching the real host: 2 args writes
        # the "__vars" namespace, 3 args writes a specific object's own
        # namespace (obj.field = value sugar lowers to this 3-arg form
        # via send(...,"set",...) instead -- see the "send" case below --
        # but set_var(obj,key,val) is ALSO a valid direct call).
        if len(args) == 2:
            key, val = args
            state.ns("__vars")[key] = val
        else:
            obj, key, val = args
            state.ns(obj)[key] = val
        return None
    if name == "send":
        recv = args[0]
        method = args[1]
        rest = list(args[2:])
        if method == "set":
            state.ns(recv)[rest[0]] = rest[1]
            return None
        if method == "push":
            # send(recv, "push", field, val): append to a List field --
            # a GENERIC built-in on any named object (hosts.rs:2394-2400),
            # not specific to any particular class/"type" field, so this
            # must be checked before the class-method lookup below, same
            # order as "set" is. "Dict" (new("Dict", name)) is not a real
            # registered class anywhere in this bundle -- it's just a
            # conventionally-named, unregistered object used as a map,
            # and send(dict_obj, "push", k, v) on one hits exactly this
            # path, never a class-method dispatch.
            field = rest[0]
            cur = state.ns(recv).get(field, [])
            state.ns(recv)[field] = cur + [rest[1]]
            return None
        cname = state.ns(recv).get("type")
        entry = state.classes.get(cname)
        closure = None
        if entry:
            for pair in entry[1]:
                if pair[0] == method:
                    closure = pair[1]
                    break
        if closure is None:
            raise PatLangError("send: no method '%s' on class '%s'" % (method, cname))
        func_name = closure[1]
        captured = list(closure[2])
        callee = find_func(state.funcs, func_name)
        if callee is None:
            raise PatLangError("send: method target function '%s' not found" % func_name)
        # Real quirk found via this bootstrap work, NOT specific to
        # Python -- confirmed present in patc1.exe's own real lowered IR
        # too: a method declared with an EXPLICIT `self` in its own
        # "takes self, ..." list (as several of this session's own new
        # classes -- ObjCache/CompileUnit/X64UnitLinker -- do) gets
        # "self" prepended a SECOND time by ClassDecl's own lowering,
        # producing a closure whose params list is
        # ["self","self",...rest]. The real x64 backend evidently
        # tolerates this already (these classes have worked correctly
        # under --x64 all session); matching that here means supplying
        # `recv` once for every LEADING "self" param rather than
        # assuming exactly one.
        leading_self = 0
        while leading_self < len(callee[2]) and callee[2][leading_self] == "self":
            leading_self += 1
        leading_self = max(1, leading_self)
        return run_function(state.funcs, callee, captured + [recv] * leading_self + rest, state)
    if name == "exec_capture":
        try:
            result = subprocess.run(
                list(args), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, errors="replace",
            )
            return result.stdout
        except OSError as e:
            return "ERR: %s" % e
    if name == "spawn":
        pid = state.next_pid
        state.next_pid += 1
        state.procs[pid] = subprocess.Popen(
            list(args), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        return pid
    if name == "wait":
        return state.procs[args[0]].wait()
    if name == "is_alive":
        return state.procs[args[0]].poll() is None
    if name == "kill":
        state.procs[args[0]].kill()
        return None
    if name == "sleep_ms":
        time.sleep(args[0] / 1000.0)
        return None
    if name == "vfs_exists":
        return "1" if args[0] in state.vfs else "0"
    if name == "vfs_read":
        if args[0] not in state.vfs:
            raise PatLangError("vfs_read: not found: %s" % args[0])
        return state.vfs[args[0]]
    if name == "vfs_write":
        state.vfs[args[0]] = args[1] if isinstance(args[1], str) else str(args[1])
        return True
    if name == "vfs_delete":
        return state.vfs.pop(args[0], None) is not None
    if name == "vfs_list":
        prefix = args[0]
        return sorted(k for k in state.vfs if k.startswith(prefix))
    if name == "read_file_bytes":
        # read_file_bytes(path, offset, length) -> List of Int (0-255),
        # fail-soft (hosts.rs: any open/seek/read error, or a file shorter
        # than offset+length, returns fewer bytes or [] rather than
        # raising) -- used for binary-format inspection (e.g. a PE
        # header's Subsystem field) without reading a whole executable
        # just to look at a handful of bytes.
        path, offset, length = args
        try:
            with open(path, "rb") as f:
                f.seek(int(offset))
                return list(f.read(int(length)))
        except OSError:
            return []
    if name == "host_caps":
        # Honest about what THIS interpreter actually has, matching the
        # pattern native x64's own host_caps() follows (hosts.rs:3531-3534
        # is the real interpreter's list; this is not that -- no world_swap
        # here, since there's no way to swap worlds in a single-shot
        # script, and no tcp/threads since those aren't implemented
        # below). Real file I/O and real subprocess spawn are genuinely
        # supported (see "spawn"/"exec_capture"/"read_file"/"write_file"
        # elsewhere in this dispatch), so those are listed for real.
        return ["subprocess", "fs"]
    if name == "register_event_handler":
        # No-op, deliberately: self_hosting/lib/build_progress.patlang
        # (added 2026-09-06, after this bootstrap was first verified)
        # registers a top-level `when x64_status do ... end` handler so
        # an EXTERNAL process can signal_query a long-running build's
        # progress while it's happening. This interpreter's own compile
        # runs single-shot and synchronously -- nothing else is running
        # concurrently to ever send it that query -- so the handler
        # genuinely never needs to fire; the registration call itself
        # just needs to not crash. Revisit with a real implementation
        # only if this bootstrap path is ever asked to run as a
        # long-lived, externally-queryable process.
        return None
    raise PatLangError(
        "host function '%s' not supported by bootstrap_interp.py -- "
        "this is deliberately scoped to the compiler's own lex/parse/"
        "lower/codegen needs, not the full interp.patlang surface "
        "(see this file's own header)" % name
    )


# ---------------------------------------------------------------------------
# The stack machine itself -- a direct Python port of interp.patlang's own
# Interpreter class (self_hosting/lib/interp.patlang), same instruction
# set, same semantics.
# ---------------------------------------------------------------------------

def find_func(funcs, name):
    for f in funcs:
        if f[1] == name:
            return f
    return None


def run_function(funcs, func, arg_values, state):
    params = func[2]
    instrs = func[3]
    locals_ = dict(zip(params, arg_values))
    stack = []
    pc = 0
    while True:
        if pc >= len(instrs):
            return None
        # Checked HERE, inside the real per-instruction loop -- not once
        # before/after it. A handler that only gets a turn between calls,
        # never during one, is not actually live while the real work is
        # happening (this project's own standing rule, previously learned
        # the hard way on the PatLang/signal_poll side; the same trap
        # applies here just as easily).
        state.progress.tick(func=func[1], pc=pc, stack_depth=len(stack))
        instr = instrs[pc]
        op = instr[0]
        if op == "Const":
            stack.append(interp_const(instr[1], instr[2]))
            pc += 1
        elif op == "Load":
            stack.append(locals_.get(instr[1]))
            pc += 1
        elif op == "Store":
            locals_[instr[1]] = stack.pop()
            pc += 1
        elif op == "Bin":
            b = stack.pop()
            a = stack.pop()
            stack.append(interp_bin(instr[1], a, b))
            pc += 1
        elif op == "Un":
            a = stack.pop()
            stack.append(interp_un(instr[1], a))
            pc += 1
        elif op == "Jump":
            pc = instr[1]
        elif op == "JumpIfFalse":
            cond = stack.pop()
            pc = pc + 1 if cond else instr[1]
        elif op == "Return":
            return stack[-1] if stack else None
        elif op == "CallHost":
            argc = instr[2]
            args = stack[len(stack) - argc:] if argc else []
            del stack[len(stack) - argc:]
            stack.append(call_host(instr[1], args, state))
            pc += 1
        elif op == "BuildList":
            n = instr[1]
            items = stack[len(stack) - n:] if n else []
            del stack[len(stack) - n:]
            stack.append(list(items))
            pc += 1
        elif op == "Call":
            argc = instr[2]
            args = stack[len(stack) - argc:] if argc else []
            del stack[len(stack) - argc:]
            callee = find_func(funcs, instr[1])
            if callee is None:
                raise PatLangError("user function '%s' not found" % instr[1])
            stack.append(run_function(funcs, callee, args, state))
            pc += 1
        elif op == "MakeClosure":
            captured_names = instr[2]
            n = len(captured_names)
            captured = stack[len(stack) - n:] if n else []
            del stack[len(stack) - n:]
            stack.append(("__closure__", instr[1], list(captured)))
            pc += 1
        elif op == "CallValue":
            argc = instr[1]
            call_args = stack[len(stack) - argc:] if argc else []
            del stack[len(stack) - argc:]
            closure = stack.pop()
            func_name = closure[1]
            all_args = list(closure[2]) + list(call_args)
            callee = find_func(funcs, func_name)
            if callee is None:
                raise PatLangError("closure target function '%s' not found" % func_name)
            stack.append(run_function(funcs, callee, all_args, state))
            pc += 1
        else:
            raise PatLangError("'%s' not recognized (not part of the current IR instruction set)" % op)


def interpret_ir(ir, argv_list):
    entry = ir[1]
    funcs = ir[2]
    main_func = find_func(funcs, entry)
    if main_func is None:
        raise PatLangError("entry function '%s' not found" % entry)
    state = HostState(argv_list, funcs)
    return run_function(funcs, main_func, [], state)


def main():
    if len(sys.argv) < 2:
        print("usage: python bootstrap_interp.py <program.ir> [args passed to the IR's own main...]")
        sys.exit(1)
    import json
    ir_path = sys.argv[1]
    with open(ir_path, "r", encoding="utf-8") as f:
        # strict=False: json.patlang's own json_escape doesn't escape
        # every control character (a separate, real, not-yet-fixed gap
        # in self_hosting/lib/json.patlang) -- tolerate it here rather
        # than block on fixing that first.
        ir = json.loads(f.read(), strict=False)
    interpret_ir(ir, sys.argv[2:])


if __name__ == "__main__":
    main()
