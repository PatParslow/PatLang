//! Design-by-contract regression tests (Stage 0): require/ensure/assert lower
//! to a shared contract_check host call. Passing conditions are silent;
//! failing conditions abort with a message naming the function, the kind of
//! check, and the condition text.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

fn quiet_print(_args: &[Value]) -> Result<Value, String> { Ok(Value::Unit) }

fn run(src: &str) -> Result<(), String> {
    let mut parser = Parser::new(src).map_err(|e| format!("{:?}", e))?;
    let ast = parser.parse().map_err(|e| format!("{:?}", e))?;
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", quiet_print);
    register_stage0_shims(&mut interp);
    interp.run(&program).map(|_| ())
}

#[test]
fn passing_require_and_ensure_are_silent() {
    let src = r#"
make a function called safe_divide takes a, b returns r
  require b != 0
  let r = a / b
  ensure (r * b) == a
  return r
end
print(safe_divide(10, 2))
"#;
    assert!(run(src).is_ok(), "passing contracts should not abort");
}

#[test]
fn failing_require_aborts_with_function_and_condition_in_message() {
    let src = r#"
make a function called safe_divide takes a, b returns r
  require b != 0
  let r = a / b
  return r
end
print(safe_divide(1, 0))
"#;
    let err = run(src).expect_err("precondition violation should abort");
    assert!(err.contains("precondition"), "message: {}", err);
    assert!(err.contains("safe_divide"), "message: {}", err);
    assert!(err.contains("b != 0"), "message: {}", err);
}

#[test]
fn failing_ensure_aborts_as_postcondition() {
    let src = r#"
make a function called broken takes n returns r
  let r = n + 1
  ensure r == n
  return r
end
print(broken(5))
"#;
    let err = run(src).expect_err("postcondition violation should abort");
    assert!(err.contains("postcondition"), "message: {}", err);
    assert!(err.contains("broken"), "message: {}", err);
}

#[test]
fn standalone_assert_works_outside_any_function() {
    assert!(run("assert (1 + 1) == 2\n").is_ok());
    let err = run("assert (1 + 1) == 3\n").expect_err("failing assert should abort");
    assert!(err.contains("assertion"), "message: {}", err);
    assert!(err.contains("main"), "message: {}", err);
}

#[test]
fn selfhost_lowerer_contract_check_via_run_ir_no_rustc() {
    // Proves contracts are a VM semantic, not a codegen concern: this drives
    // the SELF-HOSTED (Stage 1) lexer/parser/lowerer and executes the result
    // via run_ir, with no rustc invocation anywhere in this test.
    let manifest = env!("CARGO_MANIFEST_DIR");
    let read = |rel: &str| std::fs::read_to_string(format!("{}/../self_hosting/{}", manifest, rel)).expect("read");
    let compiler_libs = format!("{}\n{}\n{}", read("lib/lexer.patlang"), read("lib/parser.patlang"), read("lib/lower.patlang"));

    let driver = r#"
let src = "make a function called safe_divide takes a, b returns r\nrequire b != 0\nlet r = a / b\nreturn r\nend\nprint(safe_divide(1, 0))\n"
let toks = tokenize(src)
let ast = parse_program(toks)
let ir = lower_program(ast)
run_ir(ir)
"#;
    let full_src = format!("{}\n{}", compiler_libs, driver);
    let mut parser = Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("outer source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", quiet_print);
    register_stage0_shims(&mut interp);
    let err = interp.run(&program).expect_err("violation should propagate through run_ir");
    assert!(err.contains("contract violation"), "message: {}", err);
    assert!(err.contains("safe_divide"), "message: {}", err);
}
