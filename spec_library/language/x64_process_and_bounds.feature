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
     anything that is neither a list nor a string is 0. (A bytes, added
     later, is indexed and measured as a list is: spec 1.5.)

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
    Given the program
      """
      let e = []
      let l = [1, 2, 3]
      print(type_of(e[0]))
      print(type_of(l[10]))
      print(type_of(l[0 - 1]))
      print("abc"[10] == "")
      print(list_len(e[0]))
      print(list_len(5))
      print(list_len(l[10]))
      print(l[2])
      """
    When it runs interpreted and compiled
    Then both print
      """
      unit
      unit
      unit
      true
      0
      0
      0
      3
      """

  Scenario: a program path with a directory separator but no ./ prefix launches on both exec forms
    Given the program
      """
      include "{lib}/v2_engines.patlang"
      let probe = spec_out() + "/exec_rel_probe.patlang"
      write_file(probe, "print(" + chr(34) + "probe" + chr(34) + ")" + chr(10))
      let a = exec_capture("self_hosting/build/v2_interp.exe", probe)
      print(str_contains(a, "probe"))
      let b = exec_capture_io("self_hosting/build/v2_interp.exe", [probe], "", 0)
      print(str_contains(b[0], "probe"))
      print(b[2])
      remove_file(probe)
      """
    When it runs interpreted and compiled
    Then both print
      """
      true
      true
      true
      """

  Scenario: exec_capture_io kills a child that outlives timeout_ms and leaves a quick child alone
    Given the program
      """
      include "{lib}/v2_engines.patlang"
      let interp = "./self_hosting/build/v2_interp.exe"
      let spin = spec_out() + "/exec_timeout_spin.patlang"
      let quick_src = spec_out() + "/exec_timeout_quick.patlang"
      write_file(spin, "while true do" + chr(10) + "end" + chr(10))
      write_file(quick_src, "print(" + chr(34) + "quick" + chr(34) + ")" + chr(10))
      let t0 = now_ms()
      let spun = exec_capture_io(interp, [spin], "", 400)
      let elapsed = now_ms() - t0
      print(spun[2])
      print(str_contains(spun[1], "timeout after 400 ms"))
      print(elapsed < 6000)
      let quick = exec_capture_io(interp, [quick_src], "", 30000)
      print(quick[2])
      print(str_contains(quick[0], "quick"))
      print(str_contains(quick[1], "timeout"))
      remove_file(spin)
      remove_file(quick_src)
      """
    When it runs interpreted and compiled
    Then both print
      """
      false
      true
      true
      true
      true
      false
      """
