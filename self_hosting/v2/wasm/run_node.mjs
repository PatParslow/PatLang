// Runs a v2 WASM module under Node, with the same host as the browser's:
//
//   node self_hosting/v2/wasm/run_node.mjs PROGRAM.wasm [ARGS...]
//
// The program's output goes to stdout, and its exit code is this process's.

import { readFileSync } from "node:fs";
import { Worker } from "node:worker_threads";
import { run } from "./launcher.mjs";

const [path, ...args] = process.argv.slice(2);
if (!path) {
  process.stderr.write("usage: node run_node.mjs PROGRAM.wasm [ARGS...]\n");
  process.exit(2);
}
const executor = new URL("./executor.mjs", import.meta.url);
const code = await run({
  bytes: readFileSync(path),
  args,
  name: path,
  newWorker() {
    const w = new Worker(executor);
    return {
      post: (m) => w.postMessage(m),
      onMessage: (f) => w.on("message", f),
      terminate: () => w.terminate(),
    };
  },
  onOutput: (b) => process.stdout.write(b),
  onError: (b) => process.stderr.write(b),
});
process.stdout.write("", () => process.exit(code));
