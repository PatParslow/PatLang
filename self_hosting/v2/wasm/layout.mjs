// The control block the launcher and every executor share, as Int32 indexes
// (TLS as BigInt64 indexes), and the host's fixed values.

const MAX_EXEC = 65536;
const MAX_THREAD = 65536;
const TLS_SLOTS = 4;
const EXEC = 64;                          // 4 ints each: gate, thread
const THREADS = EXEC + 4 * MAX_EXEC;      // 1 int each: 1 once finished
const TLS_BYTE = Math.ceil((THREADS + MAX_THREAD) * 4 / 8) * 8;

export const L = {
  EXITED: 0, EXIT_CODE: 1, NEXT_EXEC: 2, NEXT_THREAD: 3, NEXT_TLS: 4,
  OUT_LOCK: 5, OUT_LEN: 6, OUT_DRAINS: 7, SLEEP: 8, RESERVE_PAGE: 9,
  MAX_EXEC, MAX_THREAD, TLS_SLOTS, EXEC, THREADS,
  TLS: TLS_BYTE / 8,
  BYTES: TLS_BYTE + 8 * MAX_THREAD * TLS_SLOTS,
};

export const OUT_BYTES = 1 << 20;
export const STD_IN = 0x10, STD_OUT = 0x11, STD_ERR = 0x12;
export const THREAD_H = 0x1000000, FIBER_H = 0x2000000;
export const FILE_H = 0x3000000;
export const HOST_AREA = 4096;
export const GB4 = 4294967296;
export const TRAP_CODE = 101;
