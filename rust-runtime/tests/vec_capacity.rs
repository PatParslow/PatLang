//! Regression safety net for vec_new gaining an optional initial-capacity
//! hint (vec_new() still works with no args; vec_new(n) pre-reserves n
//! slots via Vec::with_capacity instead of growing from empty one
//! reallocation at a time). This is a pure performance change -- Vec::
//! with_capacity(n) followed by push still grows automatically past n if
//! needed, so correctness must be identical regardless of the capacity
//! hint given (0, exact, too small, or omitted entirely). These tests are
//! the safety net for that invariant, not a "new behavior" RED/GREEN pair
//! -- the observable difference this optimization makes is real-world
//! speed (fewer realloc-and-copy cycles during vec_push), not anything
//! visible to a correctness check, which is exactly why a regression
//! test matters here: nothing should ever visibly change.

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
fn vec_new_with_no_args_still_works() {
    let out = run_capture(
        "let v = vec_new()\nvec_push(v, 10)\nvec_push(v, 20)\nprint(vec_get(v, 0))\nprint(vec_get(v, 1))\n"
    );
    assert_eq!(out, vec!["10", "20"]);
}

#[test]
fn vec_new_with_exact_capacity_hint() {
    let out = run_capture(
        "let v = vec_new(3)\nvec_push(v, 1)\nvec_push(v, 2)\nvec_push(v, 3)\nprint(vec_get(v, 0))\nprint(vec_get(v, 1))\nprint(vec_get(v, 2))\n"
    );
    assert_eq!(out, vec!["1", "2", "3"]);
}

#[test]
fn vec_grows_past_its_capacity_hint_correctly() {
    // Capacity hint of 2, but 5 pushed -- must still grow and preserve
    // every value correctly, not silently drop or corrupt anything past
    // the hinted size.
    let out = run_capture(
        "let v = vec_new(2)\nlet i = 0\nwhile i < 5 do\n  vec_push(v, i * 100)\n  let i = i + 1\nend\nlet j = 0\nwhile j < 5 do\n  print(vec_get(v, j))\n  let j = j + 1\nend\n"
    );
    assert_eq!(out, vec!["0", "100", "200", "300", "400"]);
}

#[test]
fn vec_set_and_get_correct_regardless_of_capacity_hint() {
    let out = run_capture(
        "let v = vec_new(10)\nlet i = 0\nwhile i < 10 do\n  vec_push(v, 0)\n  let i = i + 1\nend\nvec_set(v, 5, 999)\nprint(vec_get(v, 5))\nprint(vec_get(v, 0))\nprint(vec_get(v, 9))\n"
    );
    assert_eq!(out, vec!["999", "0", "0"]);
}

#[test]
fn zero_capacity_hint_behaves_like_no_hint() {
    let out = run_capture(
        "let v = vec_new(0)\nvec_push(v, 42)\nprint(vec_get(v, 0))\n"
    );
    assert_eq!(out, vec!["42"]);
}
