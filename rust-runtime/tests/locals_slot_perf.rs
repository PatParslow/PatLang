//! Regression safety net for the locals/call-target precomputation
//! optimization: run_function's per-instruction HashMap<String,Value>
//! local-variable lookup (and, separately, program.functions.get(name)
//! per Instr::Call) replaced with a per-FUNCTION cached dispatch table
//! (Vec<Value> locals indexed by a resolved slot number; resolved callee
//! references for Call sites), computed once per distinct function ever
//! called rather than once per call or once per instruction.
//!
//! History, for anyone touching this again: a first version precomputed
//! this table once per CALL rather than once per function. That fixed a
//! pure-loop microbenchmark (~30% faster) but was a measured REGRESSION
//! on fantgame's real ecosystem_bench.patlang (24.77s -> 26.58s locals-
//! only -> 29-31s once Call was added too) -- functions with short bodies
//! called millions of times (update_prey/update_predator/regen_vegetation)
//! paid a fresh Vec-allocation-and-body-scan cost on every single call,
//! outweighing the hashing it replaced. The per-FUNCTION cache here (keyed
//! by the function's own stable address, safe because a Function's body
//! and the Program's function table are both immutable after construction)
//! fixes that: the real ecosystem_bench.patlang benchmark went from
//! 24.77s to ~11.4-12.4s, roughly 2x, with the checksum unchanged. See
//! patlang-call-fix-regression-found / patlang-locals-percall-fix-superseded
//! memory entries and PHASE0_SPIKE_RESULTS.md for the full story, including
//! the earlier, wrong hypothesis (the numeric tower) this eventually
//! disproved.
//!
//! Tests below were written and confirmed passing BEFORE the per-function
//! refactor (baseline, under the per-call and, before that, the original
//! HashMap implementation), then re-confirmed passing after -- correctness
//! never regressed even though an earlier PERFORMANCE attempt did.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

thread_local! {
    static PRINTED: std::cell::RefCell<Vec<String>> = std::cell::RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(v @ (Value::Int(_)|Value::Float(_)|Value::BigInt(_)|Value::Rational(_,_))) => patlang_runtime::ir::ops::v_to_string(v).into(),
        Some(Value::Bool(b)) => b.to_string().into(),
        _ => String::new().into(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s.to_string()));
    Ok(Value::Unit)
}

fn run_capture(src: &str) -> Vec<String> {
    let mut parser = Parser::new(src).expect("lexer init");
    let ast = parser.parse().expect("parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("run");
    PRINTED.with(|p| p.borrow().clone())
}

#[test]
fn sequential_unrelated_shadowing_in_one_function() {
    // Given a variable name reused after an earlier, unrelated `let` of
    // the same name -- the flat per-function scope model means this is
    // the SAME storage slot both times, not two independent bindings.
    let out = run_capture(
        "let temp = 1\nprint(temp)\nlet temp = 2\nprint(temp)\nlet temp = temp + 10\nprint(temp)\n"
    );
    assert_eq!(out, vec!["1", "2", "12"]);
}

#[test]
fn recursive_calls_get_independent_locals() {
    let out = run_capture(
        "make a function called fact takes n returns result\n  if n <= 1 then\n    return 1\n  end\n  return n * fact(n - 1)\nend\nprint(fact(6))\n"
    );
    assert_eq!(out, vec!["720"]);
}

#[test]
fn loop_mutating_a_local_many_times() {
    let out = run_capture(
        "let total = 0\nlet i = 0\nwhile i < 1000 do\n  let total = total + i\n  let i = i + 1\nend\nprint(total)\n"
    );
    // sum 0..999 = 499500
    assert_eq!(out, vec!["499500"]);
}

#[test]
fn two_functions_reuse_the_same_variable_name_independently() {
    let out = run_capture(
        "make a function called f takes x returns result\n  let y = x + 1\n  return y\nend\nmake a function called g takes x returns result\n  let y = x * 100\n  return y\nend\nprint(f(5))\nprint(g(5))\n"
    );
    assert_eq!(out, vec!["6", "500"]);
}

#[test]
fn closure_capture_ordering_survives_slot_resolution() {
    // Two different free variables captured in a specific order --
    // MakeClosure's captured_names ordering must still match the
    // sequence of LoadLocal pushes at the closure's creation site
    // regardless of how locals are internally stored.
    let out = run_capture(
        "let a = 100\nlet b = 7\nlet make_it = || do\n  return a - b\nend\nprint(make_it())\n"
    );
    assert_eq!(out, vec!["93"]);
}

#[test]
fn hot_loop_calling_several_named_functions_repeatedly() {
    // Same bug shape as Instr::LoadLocal/StoreLocal, but for Instr::Call:
    // program.functions.get(fname) re-hashes the CALLEE's name on every
    // single call. A loop that calls several different user-defined
    // functions many times (the exact shape of fantgame's
    // ecosystem_bench.patlang, which calls update_prey/update_predator/
    // regen_vegetation once per tile-day, each themselves calling
    // max2/min2 repeatedly, from inside ONE outer run_benchmark loop)
    // exercises this directly. Correctness-focused: verifies repeated
    // calls to several different functions from the same loop body,
    // including one calling another, produce the right accumulated
    // result -- guards against any slot/resolution mixup a per-call-site
    // Call-target cache could introduce.
    let out = run_capture(
        "make a function called sq takes x returns r\n  return x * x\nend\nmake a function called combine takes a, b returns r\n  return sq(a) + sq(b)\nend\nlet total = 0\nlet i = 0\nwhile i < 1000 do\n  let total = total + combine(i, i + 1)\n  let i = i + 1\nend\nprint(total)\n"
    );
    // sum over i=0..999 of (i^2 + (i+1)^2)
    let expected: i64 = (0..1000i64).map(|i| i*i + (i+1)*(i+1)).sum();
    assert_eq!(out, vec![expected.to_string()]);
}

#[test]
fn nested_closures_three_levels_independent_state() {
    let out = run_capture(
        "let make_adder3 = |a| do\n  let level2 = |b| do\n    let level3 = |c| do\n      return a + b + c\n    end\n    return level3\n  end\n  return level2\nend\nlet add10_20 = make_adder3(10)(20)\nprint(add10_20(1))\nprint(make_adder3(100)(20)(1))\nprint(add10_20(2))\n"
    );
    assert_eq!(out, vec!["31", "121", "32"]);
}
