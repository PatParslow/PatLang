; Exercises movq (gpr<->xmm), addsd/subsd/mulsd/divsd, cvtsi2sd/cvttsd2si,
; ucomisd + jcc.
; Expected exit code: 20.
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 4
    cvtsi2sd xmm0, rax     ; xmm0 = 4.0
    mov rax, 6
    cvtsi2sd xmm1, rax     ; xmm1 = 6.0
    movq xmm2, xmm0
    addsd xmm2, xmm1       ; xmm2 = 10.0
    mulsd xmm2, xmm1       ; xmm2 = 60.0
    divsd xmm2, xmm1       ; xmm2 = 10.0
    subsd xmm2, xmm0       ; xmm2 = 6.0
    ucomisd xmm2, xmm1
    je equal
    mov rcx, 1
    call ExitProcess
equal:
    cvttsd2si rax, xmm2      ; rax = 6
    add rax, 14              ; 20
    mov rcx, rax
    call ExitProcess
