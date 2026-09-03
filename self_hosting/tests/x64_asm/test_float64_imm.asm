; Exercises the NASM __float64__(literal) pseudo-immediate specifically,
; in exactly the shape codegen_x64.patlang's own Const emission uses it
; (`mov rax, __float64__(text)`, see x64_float_literal_text's call site) --
; not a data-directive form. Backs xa_float_bits_of_string in
; x64_asm.patlang, the decimal-to-IEEE754 converter built to unblock the
; x64 assembler's own compiled-mode cutover (see
; patlang-x64-selfhosted-assembler-phase1 memory). Three literals chosen
; to exercise: a simple case (3.0), a repeating binary fraction (0.1),
; and mantissa-overflow renormalization (0.9999999999999999, rounds up
; through the implicit leading bit).
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, __float64__(3.0)
    movq xmm0, rax
    mov rax, __float64__(0.1)
    movq xmm1, rax
    addsd xmm0, xmm1
    mov rax, __float64__(0.9999999999999999)
    movq xmm1, rax
    addsd xmm0, xmm1        ; xmm0 = 3.0 + 0.1 + 0.9999999999999999 ~= 4.0999999999999996
    cvttsd2si rax, xmm0     ; truncates to 4
    add rax, 38             ; 42
    mov rcx, rax
    call ExitProcess
