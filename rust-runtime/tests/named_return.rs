//! Named-return regression tests (GitHub issue #5): a function's `returns
//! NAME` hint should give NAME real fall-through semantics -- if control
//! reaches the end of the body without an explicit `return`, the function
//! implicitly returns whatever NAME's current value is. Explicit `return
//! expr` anywhere always wins, unaffected.
//!
//! Deliberately does NOT touch require/ensure semantics at all (see
//! `still_works_with_require_and_ensure` below) -- this is a fall-through
//! fix, not a new contract-binding feature.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

fn call(src: &str, fname: &str, args: &[Value]) -> Result<Value, String> {
    let mut parser = Parser::new(src).map_err(|e| format!("{:?}", e))?;
    let ast = parser.parse().map_err(|e| format!("{:?}", e))?;
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    register_stage0_shims(&mut interp);
    interp.call_function(&program, fname, args)
}

const CLASSIFY_SRC: &str = r#"
make a function called classify takes n returns r
  if n < 0 then
    return "negative"
  end
  let r = "non-negative"
end
"#;

#[test]
fn falls_through_to_named_return_even_when_an_earlier_branch_returns_explicitly() {
    // The bug this fixes: today, ANY explicit `return` anywhere in the body
    // (even in an unrelated early-exit branch) suppresses the named-return
    // synthesis for the WHOLE function -- so this fell through with Unit,
    // not "non-negative", before the fix.
    let result = call(CLASSIFY_SRC, "classify", &[Value::Int(5)]).unwrap();
    assert_eq!(result, Value::String("non-negative".to_string().into()));
}

#[test]
fn explicit_return_in_an_earlier_branch_is_unaffected() {
    let result = call(CLASSIFY_SRC, "classify", &[Value::Int(-1)]).unwrap();
    assert_eq!(result, Value::String("negative".to_string().into()));
}

#[test]
fn zero_explicit_returns_still_works_as_before() {
    // Non-regression: a function with NO explicit return anywhere already
    // worked under the old has_return-scan logic too (the scan trivially
    // found nothing and synthesized) -- must keep working identically.
    let src = r#"
make a function called double takes n returns r
  let r = n * 2
end
"#;
    let result = call(src, "double", &[Value::Int(5)]).unwrap();
    assert_eq!(result, Value::Int(10));
}

#[test]
fn still_works_with_require_and_ensure() {
    // Deliberately verifies decision #2 in the plan: require/ensure gain NO
    // new automatic binding to the return name. `ensure` here only works
    // because the author manually wrote `let r = a / b` using the same
    // identifier as `returns r` -- pure convention, same as it is today.
    // The new part being tested: no explicit `return r` at the end, relying
    // on the named-return fall-through for the actual returned value.
    let src = r#"
make a function called safe_divide2 takes a, b returns r
  if b == 0 then
    return -1
  end
  let r = a / b
  ensure (r * b) == a
end
"#;
    let result = call(src, "safe_divide2", &[Value::Int(6), Value::Int(3)]).unwrap();
    assert_eq!(result, Value::Int(2));
}
