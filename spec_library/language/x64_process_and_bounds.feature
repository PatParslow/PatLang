Feature: Native x64 process spawning, timeouts and out-of-range access agree with the interpreter

  Found chasing the crash cluster in the native selftest parity report
  (synthesis_*, interp_run): four separate native-only defects, each
  invisible under `pat --ir-run`.

  1. rt_list_get and rt_list_len (x64_runtime.patlang) dereferenced their
     operand without checking its family tag or the index against the
     length. An empty list, or a Unit produced by an earlier out-of-range
     read, was dereferenced as if it were a list: a segfault, or garbage that
     happened not to crash. The interpreter's contract: an out-of-range list
     index is Unit, an out-of-range string index is "", and list_len of
     anything that is neither a list nor a string is 0.

  2. CreateProcessA is called with a NULL application name, so it only treats
     the first token of the command line as a path when it is prefixed with
     `./` or `.\` or is absolute. `rust-runtime/target/release/pat.exe`
     (interp_run's default) failed to launch and came back empty.
     rt_exec_join_args, shared by exec_capture and exec_capture_io, now
     normalizes that first token.

  3. exec_capture_io was declared with 3 parameters but called with 4. Under
     the native caller-pushes/caller-cleans-up convention an arity mismatch
     corrupts the callee's own frame; the interpreter silently drops the
     extra argument. It now declares timeout_ms and every call site passes
     all four.

  4. The timeout itself: exec_capture_io's timeout_ms was ignored natively,
     so an infinite child hung the caller forever (the read loop blocks in
     ReadFile, before the wait). os_set_exec_timeout arms a one-shot timeout;
     the exec primitive then polls the pipe with PeekNamedPipe, waits on the
     child in 10 ms slices, and TerminateProcess-es it at the deadline,
     reporting success=false and "timeout after N ms" on the stderr slot as
     the interpreter does.

  Scenario: out-of-range list and string access, and list_len of a non-list, match the interpreter
    Given an empty list, a three-element list, and out-of-range and negative indexes into them
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same nine lines, with Unit for the list reads and 0 for list_len of Unit

  Scenario: a program path with a directory separator but no ./ prefix launches on both exec forms
    Given exec_capture and exec_capture_io called with "rust-runtime/target/release/pat.exe"
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same four lines, with the child's output captured

  Scenario: exec_capture_io kills a child that outlives timeout_ms and leaves a quick child alone
    Given an infinite-loop child with a 400 ms timeout and a quick child with a 30000 ms timeout
    When the file is run under `pat --ir-run` and compiled+run via `--x64`
    Then both print the same seven lines: the infinite child reports failure and "timeout after 400 ms" well inside the guard, the quick child succeeds untimed
