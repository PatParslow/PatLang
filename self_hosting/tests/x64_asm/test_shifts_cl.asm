; Exercises shl/shr/sar with a VARIABLE count (the cl register), not
; just an immediate literal count (already covered by test_shifts.asm).
; Real bug found here (session 8, x64 native-toolchain cutover):
; xa_dispatch_instr's shl/shr/sar case always routed to the
; immediate-count encoder regardless of whether the second operand was
; a genuine immediate or the literal text "cl" -- for "cl", it parsed
; as a "reg" operand (register number 1) and that REGISTER NUMBER got
; used as if it were the immediate shift count, silently emitting
; `shl reg, 1` instead of `shl reg, cl`. This corrupted
; rt_payload_mask() (`1 shl 48 - 1`) throughout the whole compiled
; runtime. Expected exit code: 66.
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, 1
    mov rcx, 6
    shl rax, cl     ; 64
    mov rbx, 512
    mov rcx, 3
    shr rbx, cl     ; 64
    mov rdx, -256
    mov rcx, 2
    sar rdx, cl     ; -64 (arithmetic shift, sign-preserving)
    add rax, rbx    ; 128
    add rax, rdx    ; 64
    add rax, 2      ; 66
    mov rcx, rax
    call ExitProcess
