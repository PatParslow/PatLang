; Exercises add/sub/and/or/xor/cmp + je/jne/jg/jl/jge/jle/jmp.
; Expected exit code: 42.
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 10
    add rax, 5      ; 15
    sub rax, 3      ; 12
    mov rbx, 12
    xor rax, rax    ; 0
    mov rax, 255
    and rax, 15     ; 15
    or rax, 32      ; 47
    xor rax, 5      ; 42
    cmp rax, 42
    jne fail
    mov rcx, rbx
    cmp rcx, 12
    jne fail
    jmp done
fail:
    mov rcx, 1
    call ExitProcess
done:
    mov rcx, 42
    call ExitProcess
