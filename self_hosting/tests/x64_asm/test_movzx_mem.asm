; Exercises movzx from sized memory operands (byte/dword) and dword reg source.
; Expected exit code: 250.
default rel
global main
extern ExitProcess

section .data
    align 8
databuf:
    dq 0
    db 200

section .text
main:
    and rsp, -16
    sub rsp, 32
    movzx rax, byte [rel databuf + 8]   ; 200
    mov ecx, 49
    movzx rdx, ecx                       ; zero-extend 32->64, still 49
    add rax, rdx                          ; 249
    mov rcx, 1
    add rax, rcx                          ; 250
    mov rcx, rax
    call ExitProcess
