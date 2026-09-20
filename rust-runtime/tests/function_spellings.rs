//! Every spelling of a function definition runs in the native (Stage 0) parser:
//! `fn`/`function` with a brace body, and `make a function called` with either
//! an `end`-terminated or a brace-delimited body (with or without `takes` and
//! `returns`). The self-hosted parser accepts the same set; see
//! self_hosting/fn_syntax_selftest.patlang.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

thread_local! {
    static PRINTED: std::cell::RefCell<Vec<String>> = std::cell::RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(v @ (Value::Int(_) | Value::Float(_) | Value::BigInt(_) | Value::Rational(_, _))) => patlang_runtime::ir::ops::v_to_string(v).into(),
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
fn fn_with_a_brace_body() {
    assert_eq!(run_capture("fn add(a, b) { return a + b }\nprint(add(2, 3))\n"), vec!["5"]);
}

#[test]
fn function_keyword_with_a_brace_body() {
    assert_eq!(run_capture("function add(a, b) { return a + b }\nprint(add(2, 3))\n"), vec!["5"]);
}

#[test]
fn make_with_an_end_terminated_body() {
    assert_eq!(run_capture("make a function called add takes a, b returns sum\n  return a + b\nend\nprint(add(2, 3))\n"), vec!["5"]);
}

#[test]
fn make_with_takes_and_returns_and_a_brace_body() {
    assert_eq!(run_capture("make a function called add takes a, b returns sum {\n  return a + b\n}\nprint(add(2, 3))\n"), vec!["5"]);
}

#[test]
fn make_with_takes_only_and_a_brace_body() {
    assert_eq!(run_capture("make a function called add takes a, b {\n  return a + b\n}\nprint(add(2, 3))\n"), vec!["5"]);
}

#[test]
fn make_with_no_parameters_and_a_brace_body_runs_the_body() {
    assert_eq!(run_capture("make a function called hello {\n  return 7\n}\nprint(hello())\n"), vec!["7"]);
}

#[test]
fn brace_body_honours_the_returns_name_like_the_end_form() {
    // assigning the declared return name and falling off the end returns it
    assert_eq!(run_capture("make a function called inc takes n returns r {\n  let r = n + 1\n}\nprint(inc(4))\n"), vec!["5"]);
    assert_eq!(run_capture("make a function called inc takes n returns r\n  let r = n + 1\nend\nprint(inc(4))\n"), vec!["5"]);
}

#[test]
fn main_is_reserved_in_every_spelling() {
    for src in [
        "fn main() { return 1 }\n",
        "function main() { return 1 }\n",
        "make a function called main takes a returns r\n  return 1\nend\n",
    ] {
        let mut parser = Parser::new(src).expect("lexer init");
        assert!(parser.parse().is_err(), "expected `main` to be rejected: {src}");
    }
}
