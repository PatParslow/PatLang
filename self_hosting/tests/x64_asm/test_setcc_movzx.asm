; Exercises cmp + setcc (al) + movzx (8/16/32-bit sources).
; Expected exit code: 6 (1+1+1+1+1+1).
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 0
    mov rbx, 10
    mov rcx, 5
    cmp rbx, rcx
    setg al
    movzx rdx, al
    add rax, rdx        ; +1 (10 > 5)

    cmp rbx, rcx
    setge al
    movzx rdx, al
    add rax, rdx        ; +1 (10 >= 5)

    cmp rcx, rbx
    setl al
    movzx rdx, al
    add rax, rdx        ; +1 (5 < 10)

    cmp rcx, rbx
    setle al
    movzx rdx, al
    add rax, rdx        ; +1 (5 <= 10)

    cmp rbx, rbx
    sete al
    movzx rdx, al
    add rax, rdx        ; +1 (10 == 10)

    cmp rbx, rcx
    setne al
    movzx rdx, al
    add rax, rdx        ; +1 (10 != 5)

    mov rcx, rax
    call ExitProcess
