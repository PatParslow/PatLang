#!/bin/bash
# Phase 4 test: a real msvcrt.dll libm call through a multi-DLL import
# table (kernel32 + msvcrt), verified against a genuine numeric result
# (sqrt(64)=8), not just "didn't crash" -- and a separate structural
# stress test building the FULL real per-DLL import inventory (52
# kernel32 + 17 ws2_32 + 22 user32 + 9 gdi32 + 14 msvcrt functions,
# 114 total across 5 DLLs) to prove the linker's per-DLL
# descriptor/ILT/IAT construction scales beyond the single-DLL,
# handful-of-functions shape every earlier test used.
#
# Every name below was verified against the real DLL's export table
# (objdump -p) before use -- three were wrong in an earlier draft of
# this list (round/trunc aren't exported by msvcrt.dll at all --
# codegen_x64.patlang implements those via native SSE, not a DLL call;
# GlobalAlloc/GlobalLock/GlobalUnlock/GlobalSize are KERNEL32 exports,
# not USER32; GetDC/ReleaseDC are USER32 exports, not GDI32) and each
# produced a real STATUS_ENTRYPOINT_NOT_FOUND (0xC0000139) loader
# failure at runtime, not a build-time or objdump-visible error.
set -u
cd "$(dirname "$0")"
REPO="F:/PatLang"
PAT="$REPO/rust-runtime/target/release/pat.exe"
NASM="C:/Program Files/NASM/nasm.exe"
FAIL=0

echo "=== test_multidll_libm: real sqrt() call via msvcrt.dll ==="
"$NASM" -Ox -f win64 -o tmp_multidll.obj test_multidll_libm.asm
gcc -o tmp_multidll_ref.exe tmp_multidll.obj -Wl,--subsystem,console -lkernel32 -luser32 -lgdi32 -lws2_32
./tmp_multidll_ref.exe
ref_code=$?
echo "reference exit code: $ref_code"

cat > tmp_multidll_driver.patlang <<EOF
include "$REPO/self_hosting/lib/x64_pe_link.patlang"
let chunk = x64_assemble_chunk(read_file("$REPO/self_hosting/tests/x64_asm/test_multidll_libm.asm"))
let import_spec = [["KERNEL32.DLL", ["ExitProcess"]], ["MSVCRT.DLL", ["sqrt"]]]
let result = x64_link([chunk], import_spec, "main", "tmp_multidll_new.exe")
print(result)
EOF
"$PAT" --ir-run tmp_multidll_driver.patlang
./tmp_multidll_new.exe
new_code=$?
echo "new toolchain exit code: $new_code"

if [ "$ref_code" == "8" ] && [ "$new_code" == "8" ]; then
  echo "PASS: both report sqrt(64)=8"
else
  echo "FAIL: reference=$ref_code new=$new_code (expected 8, 8)"
  FAIL=1
fi

echo ""
echo "=== Structural: full real import inventory, 5 DLLs, 114 functions ==="
cat > tmp_full_inventory.asm <<'ASMEOF'
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rcx, 0
    call ExitProcess
ASMEOF

cat > tmp_full_driver.patlang <<EOF
include "$REPO/self_hosting/lib/x64_pe_link.patlang"
let chunk = x64_assemble_chunk(read_file("F:/PatLang/self_hosting/tests/x64_asm/tmp_full_inventory.asm"))
let import_spec = [
  ["KERNEL32.DLL", ["GetStdHandle", "WriteFile", "ExitProcess", "CreateFileA", "GetFileSize", "CloseHandle", "ReadFile", "CreateProcessA", "CreatePipe", "SetHandleInformation", "WaitForSingleObject", "GetCommandLineA", "GetExitCodeProcess", "TerminateProcess", "Sleep", "GetTickCount64", "CopyFileA", "MoveFileExA", "FindFirstFileA", "FindNextFileA", "FindClose", "GetConsoleMode", "SetConsoleMode", "SetConsoleOutputCP", "SetConsoleCP", "GetCurrentDirectoryA", "SetCurrentDirectoryA", "CreatePseudoConsole", "ResizePseudoConsole", "ClosePseudoConsole", "InitializeProcThreadAttributeList", "UpdateProcThreadAttribute", "CreateProcessW", "PeekNamedPipe", "GetLastError", "CreateThread", "ExitThread", "InitializeCriticalSection", "EnterCriticalSection", "LeaveCriticalSection", "TlsAlloc", "TlsGetValue", "TlsSetValue", "AcquireSRWLockExclusive", "ReleaseSRWLockExclusive", "SleepConditionVariableSRW", "WakeConditionVariable", "GetModuleHandleW", "GlobalAlloc", "GlobalLock", "GlobalUnlock", "GlobalSize"]],
  ["WS2_32.DLL", ["WSAStartup", "WSAGetLastError", "socket", "bind", "listen", "accept", "connect", "send", "recv", "closesocket", "shutdown", "getaddrinfo", "freeaddrinfo", "getsockname", "ioctlsocket", "htons", "ntohs"]],
  ["USER32.DLL", ["RegisterClassExW", "CreateWindowExW", "ShowWindow", "UpdateWindow", "DefWindowProcW", "PeekMessageW", "TranslateMessage", "DispatchMessageW", "BeginPaint", "EndPaint", "InvalidateRect", "GetClientRect", "DestroyWindow", "GetKeyState", "OpenClipboard", "CloseClipboard", "EmptyClipboard", "SetClipboardData", "GetClipboardData", "SetWindowTextA", "GetDC", "ReleaseDC"]],
  ["GDI32.DLL", ["CreateCompatibleDC", "CreateDIBSection", "SelectObject", "BitBlt", "TextOutA", "SetTextColor", "SetBkMode", "DeleteObject", "StretchDIBits"]],
  ["MSVCRT.DLL", ["sqrt", "pow", "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "log", "exp", "ceil", "floor", "fabs"]]
]
let result = x64_link([chunk], import_spec, "main", "tmp_full_inventory.exe")
print(result)
EOF
"$PAT" --ir-run tmp_full_driver.patlang
./tmp_full_inventory.exe
full_code=$?
echo "full-inventory exit code: $full_code (expected 0)"
if [ "$full_code" != "0" ]; then
  echo "FAIL: full-inventory build didn't run cleanly"
  FAIL=1
else
  echo "PASS: full 5-DLL/114-function import table builds and runs"
fi

rm -f tmp_multidll.obj tmp_multidll_ref.exe tmp_multidll_new.exe tmp_multidll_driver.patlang tmp_full_inventory.asm tmp_full_inventory.exe tmp_full_driver.patlang
exit $FAIL
