import ctypes
from ctypes import wintypes as w
import sys, subprocess

kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)

DEBUG_PROCESS = 0x00000001
DEBUG_ONLY_THIS_PROCESS = 0x00000002
CREATE_NEW_CONSOLE = 0x00000010
INFINITE = 0xFFFFFFFF

DBG_CONTINUE = 0x00010002
DBG_EXCEPTION_NOT_HANDLED = 0x80010001

CREATE_PROCESS_DEBUG_EVENT = 3
EXIT_PROCESS_DEBUG_EVENT = 5
EXCEPTION_DEBUG_EVENT = 1
CREATE_THREAD_DEBUG_EVENT = 2
EXIT_THREAD_DEBUG_EVENT = 4
LOAD_DLL_DEBUG_EVENT = 6
UNLOAD_DLL_DEBUG_EVENT = 7
OUTPUT_DEBUG_STRING_EVENT = 8
RIP_EVENT = 9

EXCEPTION_SINGLE_STEP = 0x80000004
EXCEPTION_ACCESS_VIOLATION = 0xC0000005
EXCEPTION_STACK_OVERFLOW = 0xC00000FD

CONTEXT_FULL_AMD64 = 0x00100000 | 0x00000001 | 0x00000002 | 0x00000004
CONTEXT_DEBUG_REGISTERS_AMD64 = 0x00100000 | 0x00000010

class M128A(ctypes.Structure):
    _fields_ = [("Low", ctypes.c_ulonglong), ("High", ctypes.c_longlong)]

class XMM_SAVE_AREA32(ctypes.Structure):
    _fields_ = [
        ("ControlWord", w.WORD), ("StatusWord", w.WORD), ("TagWord", ctypes.c_byte),
        ("Reserved1", ctypes.c_byte), ("ErrorOpcode", w.WORD), ("ErrorOffset", w.DWORD),
        ("ErrorSelector", w.WORD), ("Reserved2", w.WORD), ("DataOffset", w.DWORD),
        ("DataSelector", w.WORD), ("Reserved3", w.WORD), ("MxCsr", w.DWORD),
        ("MxCsr_Mask", w.DWORD), ("FloatRegisters", M128A * 8), ("XmmRegisters", M128A * 16),
        ("Reserved4", ctypes.c_byte * 96),
    ]

class CONTEXT(ctypes.Structure):
    _fields_ = [
        ("P1Home", ctypes.c_ulonglong), ("P2Home", ctypes.c_ulonglong),
        ("P3Home", ctypes.c_ulonglong), ("P4Home", ctypes.c_ulonglong),
        ("P5Home", ctypes.c_ulonglong), ("P6Home", ctypes.c_ulonglong),
        ("ContextFlags", w.DWORD), ("MxCsr", w.DWORD),
        ("SegCs", w.WORD), ("SegDs", w.WORD), ("SegEs", w.WORD), ("SegFs", w.WORD),
        ("SegGs", w.WORD), ("SegSs", w.WORD), ("EFlags", w.DWORD),
        ("Dr0", ctypes.c_ulonglong), ("Dr1", ctypes.c_ulonglong),
        ("Dr2", ctypes.c_ulonglong), ("Dr3", ctypes.c_ulonglong),
        ("Dr6", ctypes.c_ulonglong), ("Dr7", ctypes.c_ulonglong),
        ("Rax", ctypes.c_ulonglong), ("Rcx", ctypes.c_ulonglong),
        ("Rdx", ctypes.c_ulonglong), ("Rbx", ctypes.c_ulonglong),
        ("Rsp", ctypes.c_ulonglong), ("Rbp", ctypes.c_ulonglong),
        ("Rsi", ctypes.c_ulonglong), ("Rdi", ctypes.c_ulonglong),
        ("R8", ctypes.c_ulonglong), ("R9", ctypes.c_ulonglong),
        ("R10", ctypes.c_ulonglong), ("R11", ctypes.c_ulonglong),
        ("R12", ctypes.c_ulonglong), ("R13", ctypes.c_ulonglong),
        ("R14", ctypes.c_ulonglong), ("R15", ctypes.c_ulonglong),
        ("Rip", ctypes.c_ulonglong),
        ("FltSave", XMM_SAVE_AREA32),
        ("VectorRegister", M128A * 26), ("VectorControl", ctypes.c_ulonglong),
        ("DebugControl", ctypes.c_ulonglong), ("LastBranchToRip", ctypes.c_ulonglong),
        ("LastBranchFromRip", ctypes.c_ulonglong), ("LastExceptionToRip", ctypes.c_ulonglong),
        ("LastExceptionFromRip", ctypes.c_ulonglong),
    ]

class EXCEPTION_RECORD(ctypes.Structure):
    pass
EXCEPTION_RECORD._fields_ = [
    ("ExceptionCode", w.DWORD), ("ExceptionFlags", w.DWORD),
    ("ExceptionRecord", ctypes.POINTER(EXCEPTION_RECORD)),
    ("ExceptionAddress", ctypes.c_void_p), ("NumberParameters", w.DWORD),
    ("ExceptionInformation", ctypes.c_ulonglong * 15),
]

class EXCEPTION_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("ExceptionRecord", EXCEPTION_RECORD), ("dwFirstChance", w.DWORD)]

class CREATE_PROCESS_DEBUG_INFO(ctypes.Structure):
    _fields_ = [
        ("hFile", w.HANDLE), ("hProcess", w.HANDLE), ("hThread", w.HANDLE),
        ("lpBaseOfImage", ctypes.c_void_p), ("dwDebugInfoFileOffset", w.DWORD),
        ("nDebugInfoSize", w.DWORD), ("lpThreadLocalBase", ctypes.c_void_p),
        ("lpStartAddress", ctypes.c_void_p), ("lpImageName", ctypes.c_void_p),
        ("fUnicode", w.WORD),
    ]

class CREATE_THREAD_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("hThread", w.HANDLE), ("lpThreadLocalBase", ctypes.c_void_p),
                ("lpStartAddress", ctypes.c_void_p)]

class EXIT_PROCESS_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("dwExitCode", w.DWORD)]

class DEBUG_EVENT_UNION(ctypes.Union):
    _fields_ = [
        ("Exception", EXCEPTION_DEBUG_INFO),
        ("CreateProcessInfo", CREATE_PROCESS_DEBUG_INFO),
        ("CreateThread", CREATE_THREAD_DEBUG_INFO),
        ("ExitProcess", EXIT_PROCESS_DEBUG_INFO),
        ("pad", ctypes.c_byte * 200),
    ]

class DEBUG_EVENT(ctypes.Structure):
    _fields_ = [
        ("dwDebugEventCode", w.DWORD), ("dwProcessId", w.DWORD),
        ("dwThreadId", w.DWORD), ("u", DEBUG_EVENT_UNION),
    ]

class STARTUPINFO(ctypes.Structure):
    _fields_ = [
        ("cb", w.DWORD), ("lpReserved", ctypes.c_wchar_p), ("lpDesktop", ctypes.c_wchar_p),
        ("lpTitle", ctypes.c_wchar_p), ("dwX", w.DWORD), ("dwY", w.DWORD),
        ("dwXSize", w.DWORD), ("dwYSize", w.DWORD), ("dwXCountChars", w.DWORD),
        ("dwYCountChars", w.DWORD), ("dwFillAttribute", w.DWORD), ("dwFlags", w.DWORD),
        ("wShowWindow", w.WORD), ("cbReserved2", w.WORD), ("lpReserved2", ctypes.c_void_p),
        ("hStdInput", w.HANDLE), ("hStdOutput", w.HANDLE), ("hStdError", w.HANDLE),
    ]

class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [("hProcess", w.HANDLE), ("hThread", w.HANDLE),
                ("dwProcessId", w.DWORD), ("dwThreadId", w.DWORD)]

kernel32.CreateProcessW.argtypes = [w.LPCWSTR, w.LPWSTR, ctypes.c_void_p, ctypes.c_void_p,
    w.BOOL, w.DWORD, ctypes.c_void_p, w.LPCWSTR, ctypes.POINTER(STARTUPINFO), ctypes.POINTER(PROCESS_INFORMATION)]
kernel32.CreateProcessW.restype = w.BOOL

kernel32.WaitForDebugEvent.argtypes = [ctypes.POINTER(DEBUG_EVENT), w.DWORD]
kernel32.WaitForDebugEvent.restype = w.BOOL
kernel32.ContinueDebugEvent.argtypes = [w.DWORD, w.DWORD, w.DWORD]
kernel32.ContinueDebugEvent.restype = w.BOOL
kernel32.GetThreadContext.argtypes = [w.HANDLE, ctypes.POINTER(CONTEXT)]
kernel32.GetThreadContext.restype = w.BOOL
kernel32.SetThreadContext.argtypes = [w.HANDLE, ctypes.POINTER(CONTEXT)]
kernel32.SetThreadContext.restype = w.BOOL
kernel32.OpenThread.restype = w.HANDLE
kernel32.CloseHandle.argtypes = [w.HANDLE]
kernel32.ReadProcessMemory.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]

RETARGET = None

def read_u64(hProcess, addr):
    buf = ctypes.create_string_buffer(8)
    nread = ctypes.c_size_t(0)
    kernel32.ReadProcessMemory(hProcess, ctypes.c_void_p(addr), buf, 8, ctypes.byref(nread))
    return int.from_bytes(buf.raw, 'little')

def main():
    global RETARGET
    exe = sys.argv[1]
    watch_addr = int(sys.argv[2], 0)
    if len(sys.argv) > 3 and sys.argv[3].startswith('retarget='):
        RETARGET = int(sys.argv[3].split('=', 1)[1], 0)
        prog_args = sys.argv[4:]
    else:
        prog_args = sys.argv[3:]

    cmdline = ' '.join('"%s"' % a if ' ' in a else a for a in [exe] + prog_args)
    si = STARTUPINFO()
    si.cb = ctypes.sizeof(STARTUPINFO)
    pi = PROCESS_INFORMATION()

    buf = ctypes.create_unicode_buffer(cmdline)
    ok = kernel32.CreateProcessW(None, buf, None, None, False,
        DEBUG_PROCESS | DEBUG_ONLY_THIS_PROCESS, None, None, ctypes.byref(si), ctypes.byref(pi))
    if not ok:
        print("CreateProcess failed, err=", ctypes.get_last_error())
        return

    print(f"Launched pid={pi.dwProcessId}, watching write@0x{watch_addr:x}")
    main_tid = pi.dwThreadId
    hMainThread = pi.hThread
    armed = False
    de = DEBUG_EVENT()
    hits = 0
    while True:
        if not kernel32.WaitForDebugEvent(ctypes.byref(de), 120000):
            print("WaitForDebugEvent timeout/fail")
            break
        code = de.dwDebugEventCode
        cont = DBG_CONTINUE
        if code == CREATE_PROCESS_DEBUG_EVENT:
            cpi = de.u.CreateProcessInfo
            if cpi.hFile:
                kernel32.CloseHandle(cpi.hFile)
            if not armed and de.dwThreadId == main_tid:
                ctx = CONTEXT()
                ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS_AMD64
                kernel32.GetThreadContext(hMainThread, ctypes.byref(ctx))
                ctx.Dr0 = watch_addr
                # DR7: L0=bit0, RW0=bits16-17 (01=write), LEN0=bits18-19 (10=8bytes... but Windows only allows 00/01/11 for LEN; use 4-byte len=01(2bits value 2? ) -- use 4 bytes (bin 11? actually LEN encoding: 00=1,01=2,10=8(reserved on some),11=4)
                # Use RW=01 (write), LEN=11 (4 bytes) on the low 4 bytes of the length header (still catches any write there)
                dr7 = 1  # L0
                dr7 |= (0b01 << 16)  # RW0 = write
                dr7 |= (0b10 << 18)  # LEN0 = 8 bytes
                ctx.Dr7 = dr7
                kernel32.SetThreadContext(hMainThread, ctypes.byref(ctx))
                armed = True
                print("Hardware watchpoint armed on main thread.")
        elif code == EXCEPTION_DEBUG_EVENT:
            rec = de.u.Exception.ExceptionRecord
            excode = rec.ExceptionCode
            if excode == EXCEPTION_SINGLE_STEP:
                hThread = kernel32.OpenThread(0x1FFFFF, False, de.dwThreadId)
                ctx = CONTEXT()
                ctx.ContextFlags = CONTEXT_FULL_AMD64 | CONTEXT_DEBUG_REGISTERS_AMD64
                kernel32.GetThreadContext(hThread, ctypes.byref(ctx))
                if ctx.Dr6 & 0x1:
                    hits += 1
                    print(f"[HIT {hits}] WRITE watchpoint fired! RIP=0x{ctx.Rip:x} RAX=0x{ctx.Rax:x} RBP=0x{ctx.Rbp:x} RSP=0x{ctx.Rsp:x}")
                    # dump bytes around RIP for later objdump correlation
                    buf2 = ctypes.create_string_buffer(16)
                    nread = ctypes.c_size_t(0)
                    kernel32.ReadProcessMemory(pi.hProcess, ctypes.c_void_p(ctx.Rip), buf2, 16, ctypes.byref(nread))
                    print("  bytes at RIP:", buf2.raw[:nread.value].hex())
                    val_now = read_u64(pi.hProcess, ctx.Dr0)
                    print(f"  value at watched addr NOW = 0x{val_now:x} ({val_now})")
                    if RETARGET is not None and hits == 1:
                        new_addr = ctx.Rbp + RETARGET
                        print(f"  retargeting watch to RBP{RETARGET:+d} = 0x{new_addr:x} (8-byte watch)")
                        ctx.Dr0 = new_addr
                        dr7 = 1
                        dr7 |= (0b01 << 16)  # RW0 = write
                        dr7 |= (0b10 << 18)  # LEN0 = 8 bytes
                        ctx.Dr7 = dr7
                    elif RETARGET is not None and hits > 1:
                        val = read_u64(pi.hProcess, ctx.Dr0)
                        print(f"  value now at watched addr 0x{ctx.Dr0:x} = 0x{val:x}")
                    ctx.Dr6 = 0
                    kernel32.SetThreadContext(hThread, ctypes.byref(ctx))
                kernel32.CloseHandle(hThread)
                cont = DBG_CONTINUE
                if hits > 60:
                    print("Too many hits, stopping.")
                    kernel32.TerminateProcess(pi.hProcess, 1)
            elif excode == EXCEPTION_ACCESS_VIOLATION:
                hits += 1
                fault_ip = ctypes.cast(rec.ExceptionAddress, ctypes.c_void_p).value
                rw = rec.ExceptionInformation[0]
                bad_addr = rec.ExceptionInformation[1]
                rw_str = {0: "READ", 1: "WRITE", 8: "EXEC"}.get(rw, str(rw))
                print(f"ACCESS VIOLATION ({rw_str}) at RIP=0x{fault_ip:x} accessing 0x{bad_addr:x}")
                hThread = kernel32.OpenThread(0x1FFFFF, False, de.dwThreadId)
                ctx = CONTEXT()
                ctx.ContextFlags = CONTEXT_FULL_AMD64
                kernel32.GetThreadContext(hThread, ctypes.byref(ctx))
                print(f"  RAX=0x{ctx.Rax:x} RBX=0x{ctx.Rbx:x} RCX=0x{ctx.Rcx:x} RDX=0x{ctx.Rdx:x}")
                print(f"  RSI=0x{ctx.Rsi:x} RDI=0x{ctx.Rdi:x} RBP=0x{ctx.Rbp:x} RSP=0x{ctx.Rsp:x}")
                print(f"  R10=0x{ctx.R10:x} R11=0x{ctx.R11:x} R12=0x{ctx.R12:x} R13=0x{ctx.R13:x} R14=0x{ctx.R14:x} R15=0x{ctx.R15:x}")
                buf2 = ctypes.create_string_buffer(16)
                nread = ctypes.c_size_t(0)
                kernel32.ReadProcessMemory(pi.hProcess, ctypes.c_void_p(fault_ip), buf2, 16, ctypes.byref(nread))
                print("  bytes at RIP:", buf2.raw[:nread.value].hex())
                walk_rbp = ctx.Rbp
                for depth in range(8):
                    ret = read_u64(pi.hProcess, walk_rbp + 8)
                    print(f"  frame[{depth}] rbp=0x{walk_rbp:x} return=0x{ret:x}")
                    next_rbp = read_u64(pi.hProcess, walk_rbp)
                    if next_rbp <= walk_rbp or next_rbp == 0:
                        break
                    walk_rbp = next_rbp
                kernel32.CloseHandle(hThread)
                if hits > 2:
                    kernel32.TerminateProcess(pi.hProcess, 1)
                cont = DBG_EXCEPTION_NOT_HANDLED
            elif excode == EXCEPTION_STACK_OVERFLOW:
                hThread = kernel32.OpenThread(0x1FFFFF, False, de.dwThreadId)
                ctx = CONTEXT()
                ctx.ContextFlags = CONTEXT_FULL_AMD64
                kernel32.GetThreadContext(hThread, ctypes.byref(ctx))
                print(f"STACK OVERFLOW! RIP=0x{ctx.Rip:x} RBP=0x{ctx.Rbp:x} RSP=0x{ctx.Rsp:x}")
                buf2 = ctypes.create_string_buffer(16)
                nread = ctypes.c_size_t(0)
                kernel32.ReadProcessMemory(pi.hProcess, ctypes.c_void_p(ctx.Rip), buf2, 16, ctypes.byref(nread))
                print("  bytes at RIP:", buf2.raw[:nread.value].hex())
                walk_rbp = ctx.Rbp
                seen = {}
                for depth in range(20):
                    ret = read_u64(pi.hProcess, walk_rbp + 8)
                    if ret in seen:
                        print(f"  frame[{depth}] rbp=0x{walk_rbp:x} return=0x{ret:x} (REPEAT of frame {seen[ret]} -- recursion cycle found)")
                        break
                    seen[ret] = depth
                    print(f"  frame[{depth}] rbp=0x{walk_rbp:x} return=0x{ret:x}")
                    next_rbp = read_u64(pi.hProcess, walk_rbp)
                    if next_rbp <= walk_rbp or next_rbp == 0:
                        break
                    walk_rbp = next_rbp
                kernel32.CloseHandle(hThread)
                kernel32.TerminateProcess(pi.hProcess, 1)
                cont = DBG_EXCEPTION_NOT_HANDLED
            else:
                cont = DBG_EXCEPTION_NOT_HANDLED if de.u.Exception.dwFirstChance == 0 else DBG_CONTINUE
        elif code == EXIT_PROCESS_DEBUG_EVENT:
            print("Process exited, code=", de.u.ExitProcess.dwExitCode)
            kernel32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, DBG_CONTINUE)
            break
        elif code == CREATE_THREAD_DEBUG_EVENT:
            kernel32.CloseHandle(de.u.CreateThread.hThread)

        kernel32.ContinueDebugEvent(de.dwProcessId, de.dwThreadId, cont)

if __name__ == "__main__":
    main()
