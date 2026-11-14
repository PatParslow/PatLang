# PatLang portfolio

`index.html` links the demo pages in `demos/`. Each example shows its PatLang
source, runs its WebAssembly build in your browser on v2's browser host,
self-reports timings with `now_ms()`, and displays the native transcript
captured on the build machine for comparison.

Everything here is produced by PatLang: every demo is built by v2, and the
pages by `self_hosting/tools/build_portfolio.patlang`, itself built by v2.

Regenerate, from the repo root:

```bash
self_hosting/build/v2.exe self_hosting/tools/build_portfolio.patlang build_portfolio.exe
./build_portfolio.exe
```

Serve this folder over http(s) to view it. The WebAssembly programs share their
memory between threads, which a browser allows only on a cross-origin isolated
page; `coi-sw.js`, a service worker the pages register, makes them so on a host
that does not send the Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy
headers itself.

`build/` holds intermediate native/wasm artifacts and is not committed.
