# Guards against genuine wall-clock performance regressions in the native
# (`pat --patc`) compiled path, as opposed to the correctness-only parity
# checks elsewhere in this suite -- a program that finishes with the RIGHT
# answer but takes 1700x longer than it should would pass every other test
# here.

Feature: List accumulation through a function call stays linear, not quadratic

  # GitHub #75: `let out = push_via_fn(out, v)` -- accumulating a list by
  # passing it through an ordinary function call and reassigning the
  # caller's own variable to the result -- measured 2700x slower than the
  # equivalent inline `list_push` at n=40,000 (~24.1s instead of ~9ms),
  # because Instr::Call bound the callee's parameter via `locals[i] =
  # v.clone()` against a Vec the caller's own drained argsv was still
  # alive to alias, so Arc::make_mut inside list_push always saw
  # strong_count() > 1 and paid a full O(n) deep-clone on every single
  # call (O(n^2) overall). Fixed in both rust-runtime/src/ir/interpreter.rs
  # (the `pat --ir-run` path) and rust-runtime/src/ir/codegen.rs's
  # PRELUDE_CORE (embedded into every `pat --patc`-compiled binary) by
  # binding call arguments via move instead of clone.
  Scenario: Accumulating a list of 20,000 elements through a helper function compiles and runs natively in well under the old quadratic time
    Given a PatLang program:
      """
      make a function called push_via_fn takes out, v returns lst
        let out = list_push(out, v)
        return out
      end
      let out = []
      let i = 0
      while i < 20000 do
        let out = push_via_fn(out, i % 256)
        let i = i + 1
      end
      print(list_len(out))
      """
    When I compile and run it natively
    Then it prints exactly "20000"
    And the compiled run completes within 5 seconds
