// The portfolio pages' WebAssembly runner, on v2's own browser host
// (self_hosting/v2/wasm/: layout.mjs, launcher.mjs, executor.mjs; see
// docs/spec/ir.md, "The WASM host"). build_portfolio.patlang puts this file in
// each page that runs a program, after defining two names:
//
//   V2_LAUNCHER  a function giving the launcher's run(), with the layout
//   V2_EXECUTOR_SRC  the executor's source, with the layout, as one module
//
// and the page's own `const WASMS = { id: base64 module, ... }`. The executor
// starts as a Worker from a Blob, so a page needs no file beside it.
//
// v2's modules share their memory between threads, which needs
// SharedArrayBuffer, which a browser gives only to a cross-origin isolated
// page. A host that sends no isolation headers gets them from the service
// worker the page registers (coi-sw.js, beside the portfolio's index); the
// page reloads once when it first takes control.

function b64bytes(s) {
  const bin = atob(s);
  const a = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) a[i] = bin.charCodeAt(i);
  return a;
}

(function isolate() {
  if (self.crossOriginIsolated || !('serviceWorker' in navigator) || !window.isSecureContext) return;
  const sw = new URL('../coi-sw.js', location.href);
  navigator.serviceWorker.register(sw).then((reg) => {
    let reloaded = false;
    try { reloaded = sessionStorage.getItem('coi-reloaded') === '1'; } catch (e) {}
    if (reloaded) return;
    const reload = () => {
      try { sessionStorage.setItem('coi-reloaded', '1'); } catch (e) {}
      location.reload();
    };
    if (reg.active && !navigator.serviceWorker.controller) reload();
    else navigator.serviceWorker.addEventListener('controllerchange', reload);
  }).catch(() => {});
})();

const MODCACHE = {};
const v2Run = V2_LAUNCHER();
let V2_EXECUTOR_URL = null;

function v2NewWorker() {
  if (!V2_EXECUTOR_URL) {
    V2_EXECUTOR_URL = URL.createObjectURL(new Blob([V2_EXECUTOR_SRC], { type: 'text/javascript' }));
  }
  const w = new Worker(V2_EXECUTOR_URL, { type: 'module' });
  return {
    post: (m) => w.postMessage(m),
    onMessage: (f) => { w.onmessage = (e) => f(e.data); },
    terminate: () => w.terminate(),
  };
}

// Runs module wasmId with the arguments; onText(textSoFar) sees the output as
// it arrives. Gives { text, code }.
async function runWasmText(wasmId, args, onText) {
  if (!self.crossOriginIsolated) {
    throw new Error('this page is not cross-origin isolated, so it has no SharedArrayBuffer for the program\'s memory; reload it once its service worker is installed');
  }
  if (!MODCACHE[wasmId]) MODCACHE[wasmId] = b64bytes(WASMS[wasmId]);
  const dec = new TextDecoder();
  let text = '';
  const code = await v2Run({
    bytes: MODCACHE[wasmId],
    args: (args || []).map(String),
    name: wasmId,
    newWorker: v2NewWorker,
    onOutput(b) {
      text += dec.decode(b, { stream: true });
      if (onText) onText(text);
    },
  });
  return { text, code };
}

// Runs module wasmId, showing its output in #out-<outId> and its time in
// #ms-<outId>; gives the output, with the exit code after it when it is not 0.
async function runWasm(outId, wasmId, extraArgs) {
  const out = document.getElementById('out-' + outId);
  if (out) out.textContent = 'running...';
  const t0 = performance.now();
  try {
    const r = await runWasmText(wasmId, extraArgs, (t) => { if (out) out.textContent = t; });
    const text = r.code === 0 ? r.text : r.text + ' [exit ' + r.code + ']';
    if (out) out.textContent = text;
    const msEl = document.getElementById('ms-' + outId);
    if (msEl) msEl.textContent = (performance.now() - t0).toFixed(1) + ' ms wall (compile+run, this browser)';
    return text;
  } catch (e) {
    const msg = '[error: ' + (e && e.message || e) + ']';
    if (out) out.textContent = msg;
    return msg;
  }
}

// Every v2 module has threads, so a threaded run is an ordinary one.
const runWasmThreaded = runWasm;
