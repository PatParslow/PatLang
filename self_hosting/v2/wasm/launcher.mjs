// Runs a program's module: the main executor and one executor per thread and
// fibre, each a Worker. The launcher itself never runs the program, so it
// can stay on a browser's main thread, which may not block.
//
//   run({ bytes, args, env, files, newWorker, onOutput }) -> Promise<exit code>
//
// files: the files the program may read, path -> Uint8Array, each path
// relative with "/" between its parts (docs/spec/ir.md, "The WASM host").
//
// newWorker() gives { post(message), onMessage(callback), terminate() }.

import { L, OUT_BYTES, TRAP_CODE } from "./layout.mjs";

function quote(a) {
  return '"' + a.replace(/"/g, '\\"') + '"';
}

export async function run({ bytes, args = [], env = {}, files = {}, newWorker, onOutput, onError = onOutput, name = "program" }) {
  const module = await WebAssembly.compile(bytes);
  // the data segment lies within the module, so this covers the constants
  const pages = Math.ceil((131072 + bytes.byteLength) / 65536);
  const memory = new WebAssembly.Memory({ initial: pages, maximum: 65536, shared: true });
  const ctl = new SharedArrayBuffer(L.BYTES);
  const out = new SharedArrayBuffer(OUT_BYTES);
  const C = new Int32Array(ctl);
  const O = new Uint8Array(out);
  C[L.NEXT_EXEC] = 1;
  C[L.NEXT_THREAD] = 1;
  C[L.EXEC] = 1;
  const cmdline = [name, ...args].map(quote).join(" ");
  const workers = new Map();

  function drain() {
    while (Atomics.compareExchange(C, L.OUT_LOCK, 0, 1) !== 0) {}
    const n = C[L.OUT_LEN];
    const bytesOut = O.slice(0, n);
    C[L.OUT_LEN] = 0;
    Atomics.add(C, L.OUT_DRAINS, 1);
    Atomics.notify(C, L.OUT_DRAINS);
    Atomics.store(C, L.OUT_LOCK, 0);
    if (n) onOutput(bytesOut);
  }

  return await new Promise((resolve) => {
    let finished = false;
    function finish(code) {
      if (finished) return;
      finished = true;
      drain();
      for (const w of workers.values()) w.terminate();
      workers.clear();
      resolve(code);
    }
    function spawn(e, init) {
      const w = newWorker();
      workers.set(e, w);
      w.onMessage((m) => {
        if (m.t === "out") drain();
        else if (m.t === "exit") finish(C[L.EXIT_CODE]);
        else if (m.t === "spawn") {
          spawn(m.e, { kind: m.kind, start: m.start, param: m.param, thread: m.thread });
        } else if (m.t === "done" || m.t === "kill") {
          const d = workers.get(m.e);
          if (d) { d.terminate(); workers.delete(m.e); }
        } else if (m.t === "trap") {
          drain();
          onError(new TextEncoder().encode("wasm trap: " + m.msg + "\n"));
          finish(TRAP_CODE);
        }
      });
      w.post({ module, memory, ctl, out, me: e, env, files, cmdline, ...init });
    }
    spawn(0, { kind: "main" });
  });
}
