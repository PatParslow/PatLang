# Orchestrator + workers, coordinated over real signals

This is an executable document (run it with
`pat --ir-run self_hosting/tools/run_markdown_doc.patlang self_hosting/examples/orchestrator_signals_demo.md`)
— every ` ```patlang ` block below is real PatLang, actually executed, with
its own output injected back into the document by the doc-runner. It
demonstrates PatLang's signals mechanism (`self_hosting/lib/signals.patlang`)
coordinating several genuinely separate OS processes: one **orchestrator**
and three **workers**.

The key thing to notice by the end: the orchestrator is the *first* process
fired up, but it's the *last* one to close. That's not incidental — it's
the defining shape of an orchestrator. It has to still be around to hear
from everyone it's coordinating, so whatever starts it can't just fire it
and forget it the way it can with the workers.

## Step 1: the worker program

Each worker is a short-lived process. It does a small amount of "work" (a
toy calculation, standing in for whatever real task you'd hand off), then
reports its result to the orchestrator over a signal, then exits. It never
listens for anything itself — it only ever calls out.

Workers take two arguments (via `argv()`, since `spawn()` passes extra
arguments straight through as the child's own CLI args): a worker ID and
the orchestrator's port. One template file, spawned three times.

```patlang
let worker_src = "include \"../self_hosting/lib/signals.patlang\"" + chr(10) +
  "let args = argv()" + chr(10) +
  "let worker_id = args[0]" + chr(10) +
  "let port = to_num(args[1])" + chr(10) +
  "let total = 0" + chr(10) +
  "let i = 0" + chr(10) +
  "while i < 5 do" + chr(10) +
  "  let total = total + (to_num(worker_id) * (i + 1))" + chr(10) +
  "  let i = i + 1" + chr(10) +
  "end" + chr(10) +
  "sleep_ms(200 + (to_num(worker_id) * 150))" + chr(10) +
  "let payload = \"worker-\" + worker_id + \" computed total=\" + total" + chr(10) +
  "let reply = signal_query(port, \"report\", payload)" + chr(10) +
  "print(\"worker-\" + worker_id + \": orchestrator replied [\" + reply + \"]\")" + chr(10)
write_file("temp/orch_worker.patlang", worker_src)
print("wrote temp/orch_worker.patlang")
```
```stdout
wrote temp/orch_worker.patlang
```

## Step 2: the orchestrator program

The orchestrator claims a signal port (`signal_claim`) and registers a
`when report do ... end` handler — the same event-handler mechanism
`self_hosting/examples/signals_demo.patlang` uses. Each time a worker's
`signal_query` arrives, `signal_poll` fires that handler once, the handler
tallies it and calls `signal_reply(...)` so the worker's own call unblocks.
The orchestrator keeps polling until it's heard from every worker it's
expecting (or a safety timeout elapses), *then* it exits.

Because `spawn()` discards a child's stdout/stderr (documented in
`hosts.rs`'s `host_spawn` — deliberately, so a spawned child's own prints
don't interleave confusingly into the parent's output), the orchestrator
narrates its own story into a log file instead of stdout, so this document
can show it afterward.

`when` handlers must be declared at the top level of a program -- they
can't be nested inside `if`/`while`/a function body, since a handler is
registered once, statically, not conditionally at runtime. So the handler
gets registered *before* the claim attempt, unconditionally, and only the
claim-succeeded/failed branching happens inside the `if`.

```patlang
let orch_src = "include \"../self_hosting/lib/signals.patlang\"" + chr(10) +
  "let port = 9812" + chr(10) +
  "let expected = 3" + chr(10) +
  "let log_path = \"temp/orch_log.txt\"" + chr(10) +
  "write_file(log_path, \"orchestrator: starting up, about to claim port \" + port + chr(10))" + chr(10) +
  "set_var(\"orch_received\", 0)" + chr(10) +
  "when report do" + chr(10) +
  "  let n = get(\"__vars\", \"orch_received\") + 1" + chr(10) +
  "  set_var(\"orch_received\", n)" + chr(10) +
  "  let existing2 = read_file(log_path)" + chr(10) +
  "  write_file(log_path, existing2 + \"orchestrator: received report #\" + n + \": \" + event_data + chr(10))" + chr(10) +
  "  signal_reply(\"ack #\" + n)" + chr(10) +
  "end" + chr(10) +
  "let port_id = signal_claim(port)" + chr(10) +
  "if port_id < 0 then" + chr(10) +
  "  let existing = read_file(log_path)" + chr(10) +
  "  write_file(log_path, existing + \"orchestrator: FAILED to claim port -- another instance is already running\" + chr(10))" + chr(10) +
  "else" + chr(10) +
  "  let existing = read_file(log_path)" + chr(10) +
  "  write_file(log_path, existing + \"orchestrator: claimed port \" + port_id + \", now waiting for \" + expected + \" worker reports\" + chr(10))" + chr(10) +
  "  let waited = 0" + chr(10) +
  "  while (get(\"__vars\", \"orch_received\") < expected) and (waited < 10000) do" + chr(10) +
  "    signal_poll(port_id, 100)" + chr(10) +
  "    let waited = waited + 100" + chr(10) +
  "  end" + chr(10) +
  "  let existing3 = read_file(log_path)" + chr(10) +
  "  write_file(log_path, existing3 + \"orchestrator: all \" + expected + \" workers reported -- shutting down now (first one up, last one to close)\" + chr(10))" + chr(10) +
  "end" + chr(10)
write_file("temp/orch_orchestrator.patlang", orch_src)
print("wrote temp/orch_orchestrator.patlang")
```
```stdout
wrote temp/orch_orchestrator.patlang
```

## Step 3: fire it all up, in the order that matters

The orchestrator goes first — it needs to have the port claimed and its
`when report` handler registered before any worker could possibly reach
it. Only once it's up do the three workers get spawned. Then this block
waits on the *orchestrator's* liveness, not the workers' — proving the
point: the workers each finish on their own schedule, but the orchestrator
outlives all three of them, closing only once it's collected every report.

```patlang
let pat_exe = "rust-runtime/target/release/pat.exe"
let log_path = "temp/orch_log.txt"
write_file(log_path, "")

print("1. firing up the orchestrator (first process started)")
let orch_pid = spawn(pat_exe, "--ir-run", "temp/orch_orchestrator.patlang")
sleep_ms(400)
print("   orchestrator pid=" + orch_pid + ", alive=" + is_alive(orch_pid))

print("2. firing up 3 workers")
let w1 = spawn(pat_exe, "--ir-run", "temp/orch_worker.patlang", "1", "9812")
let w2 = spawn(pat_exe, "--ir-run", "temp/orch_worker.patlang", "2", "9812")
let w3 = spawn(pat_exe, "--ir-run", "temp/orch_worker.patlang", "3", "9812")
print("   worker pids=" + w1 + ", " + w2 + ", " + w3)

print("3. waiting for the orchestrator to finish (it decides when, not us)")
let waited = 0
while is_alive(orch_pid) and (waited < 8000) do
  sleep_ms(100)
  let waited = waited + 100
end

print("")
print("=== final liveness check ===")
print("worker 1 still alive? " + is_alive(w1))
print("worker 2 still alive? " + is_alive(w2))
print("worker 3 still alive? " + is_alive(w3))
print("orchestrator still alive? " + is_alive(orch_pid) + "   (started FIRST, but only now, LAST, has it actually finished)")

print("")
print("=== orchestrator's own narrated log ===")
print(read_file(log_path))
```
```stdout
1. firing up the orchestrator (first process started)
   orchestrator pid=37900, alive=true
2. firing up 3 workers
   worker pids=53880, 44144, 3120
3. waiting for the orchestrator to finish (it decides when, not us)

=== final liveness check ===
worker 1 still alive? false
worker 2 still alive? false
worker 3 still alive? false
orchestrator still alive? false   (started FIRST, but only now, LAST, has it actually finished)

=== orchestrator's own narrated log ===
orchestrator: starting up, about to claim port 9812
orchestrator: claimed port 9812, now waiting for 3 worker reports
orchestrator: received report #1: worker-1 computed total=15
orchestrator: received report #2: worker-2 computed total=30
orchestrator: received report #3: worker-3 computed total=45
orchestrator: all 3 workers reported -- shutting down now (first one up, last one to close)

```

## What that transcript shows

Read the log above in order: the orchestrator claims the port before
anything else exists to talk to it, then each `orchestrator: received
report #N` line arrives as a worker finishes its own short-lived run and
calls in — in whatever order the workers actually finish (they're
deliberately staggered by `sleep_ms(200 + worker_id*150)`, so worker 1
tends to report before worker 3). By the time this document checks
liveness again, all three workers are already gone; the orchestrator is
the one still running, or has *just* finished, right after the last
report came in.

That's the whole point of the pattern: an orchestrator's lifetime has to
span everyone it's coordinating, so anything that starts one first should
expect it to be the last thing still standing, not the first thing to
disappear.
