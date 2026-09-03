; Exercises a multi-DLL import table (kernel32 + msvcrt) and a real
; msvcrt.dll libm call (sqrt), verifying the actual numeric result --
; not just "didn't crash". sqrt(64.0) = 8.0 exactly (a perfect square,
; so no floating-point rounding ambiguity in the truncated-to-int check).
; Expected exit code: 8.
default rel
global main
extern ExitProcess
extern sqrt

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 64
    cvtsi2sd xmm0, rax
    call sqrt
    cvttsd2si rax, xmm0
    mov rcx, rax
    call ExitProcess
