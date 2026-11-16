// One executor: a Worker running the program's module on the shared memory.
// The main executor runs the program; each thread and each fibre has one of
// its own (docs/spec/ir.md, "The WASM host"). It provides the Windows calls
// the runtime makes, over the control block the launcher shares.

import { L, STD_IN, STD_OUT, STD_ERR, THREAD_H, FIBER_H, FILE_H, HOST_AREA, GB4 } from "./layout.mjs";

const isNode = typeof process !== "undefined" && !!(process.versions && process.versions.node);
let post;
if (isNode) {
  const { parentPort } = await import("node:worker_threads");
  post = (m) => parentPort.postMessage(m);
  parentPort.on("message", start);
} else {
  post = (m) => self.postMessage(m);
  self.onmessage = (e) => start(e.data);
}

class Exit extends Error {}

function start(init) {
  const { module, memory, ctl, out, me, kind } = init;
  const C = new Int32Array(ctl);
  const T = new BigInt64Array(ctl);
  const O = new Uint8Array(out);
  const gate = L.EXEC + 4 * me;
  let lastError = 0;
  const u8 = () => new Uint8Array(memory.buffer);
  const dv = () => new DataView(memory.buffer);
  const num = (x) => Number(BigInt.asUintN(64, x));
  const myThread = () => Atomics.load(C, gate + 1);

  function cstr(at) {
    const m = u8();
    let n = at;
    while (m[n] !== 0) n++;
    return new TextDecoder().decode(m.slice(at, n));
  }

  // The files the launcher was given, read-only: path -> bytes, each path
  // relative, with "/" between its parts. A directory is any path some file
  // lies under, "" being the top when there are any. Handles are this
  // executor's own: a file is opened, read and closed by one call of the
  // runtime's. With no files, each file call fails as it always has.
  const files = init.files || {};
  const dirs = new Set(Object.keys(files).length > 0 ? [""] : []);
  for (const f of Object.keys(files)) {
    const parts = f.split("/");
    for (let k = 1; k < parts.length; k++) dirs.add(parts.slice(0, k).join("/"));
  }
  function norm(path) {
    const out = [];
    for (const part of path.replace(/\\/g, "/").split("/")) {
      if (part === "" || part === ".") continue;
      if (part === "..") out.pop();
      else out.push(part);
    }
    return out.join("/");
  }
  const opened = new Map();
  let nextFile = 0;
  function entries(dir) {
    const names = new Set();
    const prefix = dir === "" ? "" : dir + "/";
    for (const f of Object.keys(files)) {
      if (!f.startsWith(prefix)) continue;
      const rest = f.slice(prefix.length);
      const k = rest.indexOf("/");
      names.add(k < 0 ? rest : rest.slice(0, k) + "/");
    }
    return [...names];
  }
  // WIN32_FIND_DATAA: the attributes at 0, the name at 44, NUL-ended
  function findData(at, name) {
    const m = u8();
    const isDir = name.endsWith("/");
    const raw = new TextEncoder().encode(isDir ? name.slice(0, -1) : name);
    m.fill(0, at, at + 320);
    dv().setUint32(at, isDir ? 16 : 128, true);
    m.set(raw.slice(0, 259), at + 44);
  }

  // stdout: appended under a lock to the shared buffer the launcher drains,
  // so output keeps the order the threads wrote it in
  function write(bytes) {
    let at = 0;
    while (at < bytes.length) {
      while (Atomics.compareExchange(C, L.OUT_LOCK, 0, 1) !== 0) {}
      const used = C[L.OUT_LEN];
      const room = O.length - used;
      if (room === 0) {
        const seen = Atomics.load(C, L.OUT_DRAINS);
        Atomics.store(C, L.OUT_LOCK, 0);
        post({ t: "out" });
        Atomics.wait(C, L.OUT_DRAINS, seen, 50);
        continue;
      }
      const n = Math.min(room, bytes.length - at);
      O.set(bytes.subarray(at, at + n), used);
      C[L.OUT_LEN] = used + n;
      Atomics.store(C, L.OUT_LOCK, 0);
      if (used === 0) post({ t: "out" });
      at += n;
    }
  }

  function newExec(gateValue, thread) {
    const e = Atomics.add(C, L.NEXT_EXEC, 1);
    if (e >= L.MAX_EXEC) throw new Error("more than " + L.MAX_EXEC + " threads and fibres");
    C[L.EXEC + 4 * e] = gateValue;
    C[L.EXEC + 4 * e + 1] = thread;
    return e;
  }

  const kernel = {
    ExitProcess(code) {
      if (Atomics.compareExchange(C, L.EXITED, 0, 1) === 0) {
        C[L.EXIT_CODE] = Number(BigInt.asIntN(32, code));
        post({ t: "exit" });
      }
      throw new Exit();
    },
    GetStdHandle(n) {
      const k = Number(BigInt.asIntN(32, n));
      return k === -10 ? STD_IN : k === -11 ? STD_OUT : k === -12 ? STD_ERR : -1;
    },
    WriteFile(h, buf, n, written) {
      const hn = num(h);
      if (hn !== STD_OUT && hn !== STD_ERR) { lastError = 6; return 0; }
      const len = num(n);
      write(u8().slice(num(buf), num(buf) + len));
      if (num(written) !== 0) dv().setUint32(num(written), len, true);
      return 1;
    },
    ReadFile(h, buf, n, read) {
      const hn = num(h);
      const f = opened.get(hn);
      if (f) {
        const len = Math.max(0, Math.min(num(n), f.data.length - f.pos));
        u8().set(f.data.subarray(f.pos, f.pos + len), num(buf));
        f.pos += len;
        if (num(read) !== 0) dv().setUint32(num(read), len, true);
        return 1;
      }
      if (hn !== STD_IN) { lastError = 6; return 0; }
      if (num(read) !== 0) dv().setUint32(num(read), 0, true);
      return 1;
    },
    GetLastError() { return lastError; },
    VirtualAlloc(addr, size, type, prot) {
      const t = num(type);
      if ((t & 0x2000) && num(addr) === 0) {
        const base = Math.ceil(memory.buffer.byteLength / 65536) * 65536;
        Atomics.store(C, L.RESERVE_PAGE, base / 65536);
        return base;
      }
      if (t & 0x1000) {
        const end = num(addr) + num(size);
        if (end > GB4) { lastError = 8; return 0; }
        const want = Math.ceil(end / 65536);
        const have = memory.buffer.byteLength / 65536;
        if (want > have) {
          try { memory.grow(want - have); } catch (e) { lastError = 8; return 0; }
        }
        return addr;
      }
      lastError = 87;
      return 0;
    },
    RtlMoveMemory(dst, src, n) {
      const s = num(src);
      u8().copyWithin(num(dst), s, s + num(n));
      return 0;
    },
    TlsAlloc() {
      const i = Atomics.add(C, L.NEXT_TLS, 1);
      return i < L.TLS_SLOTS ? i : 0xFFFFFFFF;
    },
    TlsGetValue(i) { return Atomics.load(T, L.TLS + myThread() * L.TLS_SLOTS + num(i)); },
    TlsSetValue(i, v) { Atomics.store(T, L.TLS + myThread() * L.TLS_SLOTS + num(i), v); return 1; },
    CreateThread(sa, stack, startAt, param) {
      const th = Atomics.add(C, L.NEXT_THREAD, 1);
      if (th >= L.MAX_THREAD) throw new Error("more than " + L.MAX_THREAD + " threads");
      Atomics.store(C, L.THREADS + th, 0);
      for (let k = 0; k < L.TLS_SLOTS; k++) Atomics.store(T, L.TLS + th * L.TLS_SLOTS + k, 0n);
      const e = newExec(1, th);
      post({ t: "spawn", e, kind: "thread", start: num(startAt), param, thread: th });
      return THREAD_H + th;
    },
    WaitForSingleObject(h, ms) {
      const hn = num(h);
      if (hn < THREAD_H || hn >= FIBER_H) { lastError = 6; return 0xFFFFFFFF; }
      const at = L.THREADS + (hn - THREAD_H);
      const forever = num(ms) === 0xFFFFFFFF;
      const until = Date.now() + num(ms);
      while (Atomics.load(C, at) === 0) {
        if (forever) Atomics.wait(C, at, 0);
        else {
          const left = until - Date.now();
          if (left <= 0) return 258;
          Atomics.wait(C, at, 0, left);
        }
      }
      return 0;
    },
    CloseHandle(h) { opened.delete(num(h)); return 1; },
    Sleep(ms) { Atomics.wait(C, L.SLEEP, 0, num(ms)); return 0; },
    ConvertThreadToFiber() { return FIBER_H + me; },
    ConvertFiberToThread() { return 1; },
    CreateFiber(stack, startAt, param) {
      const e = newExec(0, 0);
      post({ t: "spawn", e, kind: "fiber", start: num(startAt), param });
      return FIBER_H + e;
    },
    SwitchToFiber(f) {
      const target = L.EXEC + 4 * (num(f) - FIBER_H);
      Atomics.store(C, gate, 0);
      Atomics.store(C, target + 1, myThread());
      Atomics.store(C, target, 1);
      Atomics.notify(C, target);
      while (Atomics.load(C, gate) === 0) Atomics.wait(C, gate, 0);
      return 0;
    },
    DeleteFiber(f) { post({ t: "kill", e: num(f) - FIBER_H }); return 0; },
    GetSystemTimeAsFileTime(p) {
      const ft = (BigInt(Date.now()) + 11644473600000n) * 10000n;
      dv().setBigUint64(num(p), ft, true);
      return 0;
    },
    // The processors the browser reports; it gives no processor times or
    // memory figures, so cpu_times and memory_status give [-1, -1].
    GetSystemInfo(p) {
      const n = (typeof navigator !== "undefined" && navigator.hardwareConcurrency) || 1;
      dv().setUint32(num(p) + 32, n, true);
      return 0;
    },
    GetSystemTimes() { lastError = 50; return 0; },
    GlobalMemoryStatusEx() { lastError = 50; return 0; },
    GetCommandLineA() { return HOST_AREA; },
    GetEnvironmentVariableA(name, buf, size) {
      const v = init.env[cstr(num(name))];
      if (v === undefined) { lastError = 203; return 0; }
      const raw = new TextEncoder().encode(v);
      if (raw.length + 1 > num(size)) return raw.length + 1;
      const m = u8();
      m.set(raw, num(buf));
      m[num(buf) + raw.length] = 0;
      return raw.length;
    },
    // the files given are read; nothing is written, and there are no
    // processes or sockets: each of those reports failure
    CreateFileA(name, access) {
      const path = norm(cstr(num(name)));
      // GENERIC_READ alone
      if ((num(access) & 0x40000000) !== 0) { lastError = 5; return -1; }
      if (!(path in files)) { lastError = dirs.has(path) ? 5 : 2; return -1; }
      const h = FILE_H + nextFile++;
      opened.set(h, { data: files[path], pos: 0 });
      return h;
    },
    GetFileAttributesA(name) {
      const path = norm(cstr(num(name)));
      if (path in files) return 128;
      if (dirs.has(path)) return 16;
      lastError = 2;
      return 0xFFFFFFFF;
    },
    FindFirstFileA(pattern, data) {
      const p = norm(cstr(num(pattern)));
      if (!p.endsWith("*")) { lastError = 2; return -1; }
      const dir = norm(p.slice(0, -1));
      if (!dirs.has(dir)) { lastError = 3; return -1; }
      const list = entries(dir);
      if (list.length === 0) { lastError = 2; return -1; }
      const h = FILE_H + nextFile++;
      opened.set(h, { list, next: 1 });
      findData(num(data), list[0]);
      return h;
    },
    FindNextFileA(h, data) {
      const f = opened.get(num(h));
      if (!f || !f.list || f.next >= f.list.length) { lastError = 18; return 0; }
      findData(num(data), f.list[f.next++]);
      return 1;
    },
    FindClose(h) { opened.delete(num(h)); return 1; },
    GetFileSize(h, high) {
      const f = opened.get(num(h));
      if (!f || !f.data) { lastError = 6; return 0xFFFFFFFF; }
      if (num(high) !== 0) dv().setUint32(num(high), 0, true);
      return f.data.length;
    },
    SetFilePointerEx(h, distance, newPos, method) {
      const f = opened.get(num(h));
      if (!f || !f.data) { lastError = 6; return 0; }
      const d = Number(BigInt.asIntN(64, distance));
      const m = num(method);
      const at = m === 0 ? d : m === 1 ? f.pos + d : f.data.length + d;
      if (at < 0) { lastError = 131; return 0; }
      f.pos = at;
      if (num(newPos) !== 0) dv().setBigInt64(num(newPos), BigInt(at), true);
      return 1;
    },
    DeleteFileA() { lastError = 2; return 0; },
    RemoveDirectoryA() { lastError = 2; return 0; },
    CreateDirectoryA() { lastError = 5; return 0; },
    MoveFileExA() { lastError = 2; return 0; },
    CopyFileA() { lastError = 2; return 0; },
    // the files given are one tree, rooted at /: a path in full is / and the
    // path with . and .. taken out (path_absolute, spec 1.13)
    GetFullPathNameA(name, size, buf) {
      const raw = new TextEncoder().encode("/" + norm(cstr(num(name))));
      if (raw.length + 1 > num(size)) return raw.length + 1;
      const m = u8();
      m.set(raw, num(buf));
      m[num(buf) + raw.length] = 0;
      return raw.length;
    },
    CreatePipe() { lastError = 50; return 0; },
    SetHandleInformation() { lastError = 6; return 0; },
    CreateProcessA() { lastError = 2; return 0; },
    GetExitCodeProcess() { lastError = 6; return 0; },
    TerminateProcess() { lastError = 6; return 0; },
    PeekNamedPipe() { lastError = 6; return 0; },
    K32GetProcessMemoryInfo() { lastError = 50; return 0; },
    CreateJobObjectA() { lastError = 50; return 0; },
    AssignProcessToJobObject() { lastError = 6; return 0; },
    ResumeThread() { lastError = 6; return -1; },
    QueryInformationJobObject() { lastError = 6; return 0; },
  };
  const winsock = {
    WSAStartup() { return 10091; },
    WSAGetLastError() { return 10050; },
  };
  const round = (x) => {
    const r = Math.trunc(x);
    return Math.abs(x - r) >= 0.5 ? r + Math.sign(x) : r;
  };
  const crt = {
    sqrt: Math.sqrt, floor: Math.floor, ceil: Math.ceil, trunc: Math.trunc, round,
    sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos,
    atan: Math.atan, atan2: Math.atan2, exp: Math.exp, log: Math.log, pow: Math.pow,
    fmod: (a, b) => a % b,
  };

  const imports = { env: { memory } };
  for (const im of WebAssembly.Module.imports(module)) {
    if (im.kind !== "function") continue;
    const lib = im.module, func = im.name;
    imports[lib] = imports[lib] || {};
    if (lib === "UCRTBASE.DLL" && crt[func]) {
      imports[lib][func] = crt[func];
      continue;
    }
    const impl = lib === "KERNEL32.DLL" ? kernel[func] : lib === "WS2_32.DLL" ? (winsock[func] || (() => { lastError = 10050; return -1; })) : undefined;
    imports[lib][func] = impl
      ? (...args) => { const r = impl(...args); return typeof r === "bigint" ? r : BigInt(r); }
      : () => { throw new Error(lib + "!" + func + " is not available on this host"); };
  }

  let instance;
  try {
    instance = new WebAssembly.Instance(module, imports);
  } catch (e) {
    post({ t: "trap", e: me, msg: String(e && e.stack || e) });
    return;
  }
  const x = instance.exports;
  try {
    if (kind === "main") {
      x.init_memory();
      u8().set(new TextEncoder().encode(init.cmdline + "\0"), HOST_AREA);
      x.main();
    } else if (kind === "thread") {
      x.table.get(init.start)(init.param);
      Atomics.store(C, L.THREADS + init.thread, 1);
      Atomics.notify(C, L.THREADS + init.thread);
      post({ t: "done", e: me });
    } else {
      while (Atomics.load(C, gate) === 0) Atomics.wait(C, gate, 0);
      x.table.get(init.start)(init.param);
    }
  } catch (e) {
    if (!(e instanceof Exit)) post({ t: "trap", e: me, msg: String(e && e.stack || e) });
  }
}
