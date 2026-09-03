; Chunk B: defines mul_helper(a, b) -> add_helper(a, b) * 2, exercising a
; CROSS-CHUNK call (add_helper is defined in chunk_a.asm, not here).
default rel
global mul_helper
extern add_helper

section .text
mul_helper:
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 32
    call add_helper
    add rax, rax
    mov rsp, rbp
    pop rbp
    ret
