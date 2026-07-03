# PatLang portfolio

`index.html` is a self-contained page (no network needed): each example shows
its PatLang source, runs the compiled WebAssembly in your browser via an
inline WASI shim, self-reports timings with `now_ms()`, and displays the
native transcript captured on the build machine for comparison.

Everything on the page is produced by the self-hosted PatLang toolchain —
including the page itself (`self_hosting/tools/build_portfolio.patlang`).

Regenerate (requires `rustup target add wasm32-wasip1`):

```bash
rust-runtime/target/release/pat --ir-run self_hosting/tools/build_portfolio.patlang
```

`build/` holds intermediate native/wasm artifacts and is not committed.
