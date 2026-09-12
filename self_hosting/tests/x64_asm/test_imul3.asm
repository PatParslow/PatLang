; Regression fixture for the three-operand `imul reg, r/m, imm` form
; (REX.W + 69 /r id). The self-hosted assembler used to handle only the
; one-operand (F7 /5) and two-operand (0F AF /r) imul forms, so a
; three-operand `imul rax, rax, 8` silently fell through to the
; two-operand encoder, dropping the immediate and computing rax*rax
; instead of rax*8 -- turning every `i * 8` element-stride computation
; into `i * i`, which corrupted every BigInt built by the runtime's own
; rt_bigint_from_i64 (wrong limb offsets AND an under-allocated block).
;
; Exit code checks several distinct shapes so a partial fix can't pass:
;   3 * 8   = 24   (dst == src, small imm -- the exact runtime pattern)
;   5 * 7   = 35   (dst != src)
;   2 * 8   = 16   (extended register as source, exercises REX.B)
;   1 * 8   =  8   (extended register as dest, exercises REX.R)
; 24 + 35 + 16 + 8 = 83

bits 64
default rel

global main
extern ExitProcess

section .text

main:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; dst == src, immediate 8 -- the exact `16 + i * 8` stride shape
    mov rax, 3
    imul rax, rax, 8          ; 24
    mov rbx, rax

    ; dst != src
    mov rcx, 5
    imul rdx, rcx, 7          ; 35
    add rbx, rdx

    ; source is an extended register (REX.B path)
    mov r9, 2
    imul rax, r9, 8           ; 16
    add rbx, rax

    ; destination is an extended register (REX.R path)
    mov rcx, 1
    imul r10, rcx, 8          ; 8
    add rbx, r10

    mov rcx, rbx
    call ExitProcess
