; Chunk main: the real PE entry point. Calls mul_helper (chunk_b.asm,
; itself calling add_helper in chunk_a.asm) -- exercises a 2-hop
; cross-chunk call. Also stores an ABS64 pointer to add_helper (a
; function defined in a DIFFERENT chunk) in its own .data, mirroring
; the real g_apply_table shape, and a .bss counter in its own chunk.
; Expected exit code: 34 ((10+7)*2).
default rel
global main
extern mul_helper, add_helper
extern ExitProcess

section .data
    align 8
fn_table:
    dq add_helper

section .bss
    align 8
    counter resq 1

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rcx, 10
    mov rdx, 7
    call mul_helper
    mov qword [rel counter], rax
    ; Read back the cross-chunk ABS64 function-pointer table entry (not
    ; indirectly called -- register-indirect call is a separate, not-
    ; yet-implemented addressing form, out of this test's scope) just
    ; to prove the linker resolved it to a real, non-zero address
    ; without crashing.
    mov r10, [rel fn_table]
    test r10, r10
    jz fail
    mov rcx, [rel counter]
    call ExitProcess
fail:
    mov rcx, 99
    call ExitProcess
