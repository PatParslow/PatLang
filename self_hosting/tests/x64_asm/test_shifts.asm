; Exercises shl/shr/sar with immediate counts.
; Expected exit code: 77.
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 1
    shl rax, 4      ; 16
    mov rbx, 160
    shr rbx, 3      ; 20
    mov rcx, -32
    sar rcx, 2      ; -8 (arithmetic shift, sign-preserving)
    add rax, rbx    ; 36
    add rax, rcx    ; 28  (36 + -8)
    add rax, 49     ; 77
    mov rcx, rax
    call ExitProcess
