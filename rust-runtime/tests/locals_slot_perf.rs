//! Regression safety net for the locals-storage optimization: replacing
//! run_function's per-instruction HashMap<String,Value> local-variable
//! lookup with a slot table precomputed once per call (Vec<Value>
//! indexed by a resolved slot number instead of re-hashing the variable's
//! name string on every single LoadLocal/StoreLocal). Written and
//! confirmed passing BEFORE that refactor (establishing a correctness
//! baseline under the old HashMap-based implementation), then re-run
//! after the refactor to confirm no regression -- see
//! patlang-fantgame-perf-root-cause-found memory / PHASE0_SPIKE_RESULTS.md
//! for the real workload (fantgame's Ruby-to-PatLang port) that motivated
//! this: a bare loop with zero arithmetic cost ~240ns/iteration natively
//! compiled, traced to per-name HashMap lookups dominating cost uniformly
//! across int/float workloads (not the numeric tower, as first
//! hypothesized).

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
fn nested_closures_three_levels_independent_state() {
    let out = run_capture(
        "let make_adder3 = |a| do\n  let level2 = |b| do\n    let level3 = |c| do\n      return a + b + c\n    end\n    return level3\n  end\n  return level2\nend\nlet add10_20 = make_adder3(10)(20)\nprint(add10_20(1))\nprint(make_adder3(100)(20)(1))\nprint(add10_20(2))\n"
    );
    assert_eq!(out, vec!["31", "121", "32"]);
}
