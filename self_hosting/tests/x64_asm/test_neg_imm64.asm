; Exercises `mov reg64, imm64` with a genuinely negative immediate --
; the imm64 form specifically (a 64-bit register with no size-fitting
; shortcut), not the smaller reg32/imm32 forms already covered
; elsewhere. Real bug found here (session 8, x64 native-toolchain
; cutover): xa_int_to_bytes_le's negative-number handling computed
; `uv = v + 2^64` by way of `powers[63] * 2` as an actual intermediate
; VALUE -- one bit past what fits in a signed 64-bit integer. The
; INTERPRETER (`pat --ir-run`) silently promotes this to a genuine
; BigInt and gets the right answer, but `codegen.rs` (the Rust-emission
; backend that compiles patc1.exe ITSELF) does not reliably promote a
; runtime multiplication's overflow the same way -- confirmed directly:
; `mov rcx, -11` (GetStdHandle's own STD_OUTPUT_HANDLE argument in
; self_hosting/lib/x64_runtime.patlang) compiled through patc1.exe
; emitted the bytes for -1 (0xFFFFFFFFFFFFFFFF) instead of -11
; (0xFFFFFFFFFFFFFFF5), so GetStdHandle(-1) returned
; INVALID_HANDLE_VALUE and every subsequent WriteFile silently no-op'd
; -- console output vanished with no crash and no error. Fixed by
; computing two's complement via the "invert(|v|-1)" identity instead,
; which never needs a value anywhere near 2^63/2^64. Expected exit
; code: 245 (the low byte of -11's two's-complement bit pattern,
; 0xFFFFFFFFFFFFFFF5).
default rel
global main
extern ExitProcess

section .text
main:
    and rsp, -16
    sub rsp, 32
    mov rax, -11
    mov rcx, rax
    call ExitProcess
