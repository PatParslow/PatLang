// The browser page: runs ?wasm=URL (default program.wasm) with ?args=[JSON],
// shows its output, and with ?report posts {code, out} to /result. ?files=URL
// names a bundle of files the program may read: JSON mapping each path to its
// bytes in base64 (run_browser.py, bundle).

import { run } from "./launcher.mjs";

const q = new URLSearchParams(location.search);
const status = document.getElementById("status");
const pre = document.getElementById("out");
const chunks = [];
const dec = new TextDecoder();

function base64(parts) {
  let s = "";
  for (const p of parts) for (let i = 0; i < p.length; i++) s += String.fromCharCode(p[i]);
  return btoa(s);
}

async function report(result) {
  if (q.has("report")) {
    await fetch("/result", { method: "POST", body: JSON.stringify(result) });
  }
}

try {
  if (!crossOriginIsolated) {
    throw new Error("the page is not cross-origin isolated, so it has no SharedArrayBuffer; " +
                    "serve it with Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy headers");
  }
  const response = await fetch(q.get("wasm") || "program.wasm");
  const bytes = new Uint8Array(await response.arrayBuffer());
  const files = {};
  if (q.has("files")) {
    const listed = await (await fetch(q.get("files"))).json();
    for (const [path, b64] of Object.entries(listed)) {
      const raw = atob(b64);
      const data = new Uint8Array(raw.length);
      for (let i = 0; i < raw.length; i++) data[i] = raw.charCodeAt(i);
      files[path] = data;
    }
  }
  status.textContent = "Running…";
  const executor = new URL("./executor.mjs", import.meta.url);
  const code = await run({
    bytes,
    args: JSON.parse(q.get("args") || "[]"),
    files,
    name: "program",
    newWorker() {
      const w = new Worker(executor, { type: "module" });
      return {
        post: (m) => w.postMessage(m),
        onMessage: (f) => { w.onmessage = (e) => f(e.data); },
        terminate: () => w.terminate(),
      };
    },
    onOutput(b) {
      chunks.push(b);
      pre.textContent += dec.decode(b, { stream: true });
    },
  });
  status.textContent = "Exit code " + code;
  await report({ code, out: base64(chunks) });
} catch (e) {
  status.textContent = "Error: " + e.message;
  await report({ error: String(e && e.stack || e) });
}
