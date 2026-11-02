# PatLang program templates

Starting points for new PatLang programs. Copy one, rename it, and change
the parts its header marks as yours.

## budgeted_tool.patlang: long-running tools

Use it for any tool that runs for more than a few seconds: batch jobs,
converters, checkers, daemons.

- **Budgeted orchestration.** The work runs only inside
  `budgeted(SLICE_MS, handle) { ... }` slices, driven by one orchestrator,
  `run_tool`. A slice that runs out of time pauses at a loop back-edge and
  is resumed from its handle on the next turn. Between slices the
  orchestrator polls for signals, so the tool always answers promptly.
- **Signals.** `status`, `pause`, `resume` and `quit` are built in. Running
  a second copy finds the port already taken and passes its argument to
  the running copy:
  `pat --ir-run budgeted_tool.patlang status`.
- **No loose globals.** State lives in objects, one class per concern:
  `ToolSettings`, `ToolControl`, `ToolProgress`, `Workload`, and `Tool`,
  which ties them together and answers signals. Each `when` handler is a
  one-line call into `Tool`. Other functions receive object names as
  parameters. Nothing uses `set_var` or `get("__vars", ...)`.

To make a new tool, pick a free port and rewrite the `Workload` class
(`total_units`, `do_unit`, `result`). Keep each `do_unit` call bounded,
because a slice can only pause inside a loop. To add a signal, add a method
to `Tool` and a one-line `when` handler for it.

Not included: crash-safe resumption. If losing finished units on a crash
matters, publish each unit's result with `queue_publish` and call
`queue_ack` only once it is stored (`self_hosting/lib/queue.patlang`).

`check_budgeted_tool.sh` tests the template's claims against a running
copy. It checks that:

- `status` is answered while the tool is busy;
- `pause` holds the unit count still;
- `resume` carries on from where it stopped;
- an interrupted run gives the same result as an uninterrupted one;
- `quit` stops the tool early.

It runs under the interpreter by default. To test a native build, set
`TOOL=./tool.exe`.
