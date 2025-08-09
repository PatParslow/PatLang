use patlang_runtime::{parser::Parser, ir::*};

#[test]
fn lower_and_run_basic_if() {
    let src = r#"
        let x = 3 + 4
        if x > 5 {
          return x
        } else {
          return 0
        }
    "#;
    let mut p = Parser::new(src).expect("parser");
    let ast = p.parse().expect("parse ok");

    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let interp = Interpreter::new();
    let v = interp.run(&program).expect("run ok");
    assert_eq!(v, Value::Number(7.0));
}

#[test]
fn lower_and_run_list_literal() {
  let src = r#"
    let a = [1, 2, 3]
    return a
  "#;
  let mut p = Parser::new(src).expect("parser");
  let ast = p.parse().expect("parse ok");
  let mut lower = Lowerer::new();
  let program = lower.lower_program_basic(&ast);
  let interp = Interpreter::new();
  let v = interp.run(&program).expect("run ok");
  assert_eq!(v, Value::List(vec![Value::Number(1.0), Value::Number(2.0), Value::Number(3.0)]));
}

#[test]
fn lower_and_run_reassignment() {
  let src = r#"
    let x = 1
    x = x + 41
    return x
  "#;
  let mut p = Parser::new(src).expect("parser");
  let ast = p.parse().expect("parse ok");
  let mut lower = Lowerer::new();
  let program = lower.lower_program_basic(&ast);
  let interp = Interpreter::new();
  let v = interp.run(&program).expect("run ok");
  assert_eq!(v, Value::Number(42.0));
}
