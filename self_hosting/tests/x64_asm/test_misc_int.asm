; Exercises inc/dec/neg/not/imul/idiv/cqo/test+jz/lock cmpxchg/pause.
; Expected exit code: 33.
default rel
global main
extern ExitProcess

section .bss
    align 8
    slot resq 1

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 10
    inc rax          ; 11
    dec rax          ; 10
    mov rbx, rax
    neg rbx          ; -10
    not rbx          ; ~(-10) = 9
    add rax, rbx     ; 19

    mov rbx, 6
    mov r14, 7
    imul rbx, r14    ; 42

    mov r15, rax     ; running total = 19
    mov rax, 42
    cqo
    mov rbx, 5
    idiv rbx         ; rax=8 rem rdx=2

    test rax, rax
    jz fail
    add r15, rax     ; 19+8=27
    add r15, rdx     ; 27+2=29

    mov qword [rel slot], 4
    mov rax, 4
    mov r10, 4
    lock cmpxchg [rel slot], r10
    ; RAX(4) == [slot](4): equal, ZF set, [slot] <- r10(4) (unchanged value,
    ; but a real compare-and-swap really happened)
    jne fail
    mov r11, [rel slot]
    add r15, r11     ; 29+4=33
    pause

    mov rcx, r15
    call ExitProcess
fail:
    mov rcx, 1
    call ExitProcess
