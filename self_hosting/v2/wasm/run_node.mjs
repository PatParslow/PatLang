// Runs a v2 WASM module under Node, with the same host as the browser's:
//
//   node self_hosting/v2/wasm/run_node.mjs [--files DIR]... [--fail NAME:N] [--real-files] PROGRAM.wasm [ARGS...]
//
// Each --files DIR gives the program every file under DIR to read, at its path
// relative to the current directory, as a page's file bundle does.
// --real-files instead puts its file calls on the disk, relative to the current
// directory, so it can write: the compiler built as WebAssembly can then build
// a program, on any machine with Node (review, test-suite recommendation 1). --fail
// NAME:N makes the Nth call each worker makes to the host's NAME fail, as the
// system's would, to test what the program does with it. The program's output
// goes to stdout, and its exit code is this process's.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { Worker } from "node:worker_threads";
import { run } from "./launcher.mjs";

const argv = process.argv.slice(2);
const files = {};
function add(dir) {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) add(full);
    else files[relative(process.cwd(), full).split("\\").join("/")] = new Uint8Array(readFileSync(full));
  }
}
// --fail NAME:N makes the Nth call to the host's NAME fail (launcher.mjs, fail);
// --real-files puts the program's file calls on the disk (realFiles)
let fail = null;
let realFiles = false;
while (argv[0] === "--files" || argv[0] === "--fail" || argv[0] === "--real-files") {
  const flag = argv.shift();
  if (flag === "--real-files") { realFiles = true; continue; }
  const value = argv.shift();
  if (flag === "--files") add(value);
  else {
    const [func, nth] = value.split(":");
    fail = { func, nth: Number(nth) };
  }
}
const [path, ...args] = argv;
if (!path) {
  process.stderr.write("usage: node run_node.mjs [--files DIR]... PROGRAM.wasm [ARGS...]\n");
  process.exit(2);
}
const executor = new URL("./executor.mjs", import.meta.url);
const code = await run({
  bytes: readFileSync(path),
  args,
  files,
  fail,
  realFiles,
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
