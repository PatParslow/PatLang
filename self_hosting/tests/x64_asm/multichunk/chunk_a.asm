; Chunk A: defines add_helper(a, b) -> a+b, callable from other chunks.
default rel
global add_helper

section .text
add_helper:
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 32
    mov rax, rcx
    add rax, rdx
    mov rsp, rbp
    pop rbp
    ret
