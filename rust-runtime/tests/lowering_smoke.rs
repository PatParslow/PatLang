use patlang_runtime::{parser::Parser, ir::*};

fn register_test_hosts(interp: &mut Interpreter) {
  // Provide minimal hosts needed by lowering for member access and message send
  interp.host.insert("len", |args| {
    let v = args.get(0).cloned().unwrap_or(Value::Unit);
    let n = match v {
      Value::String(ref s) => s.chars().count() as f64,
      Value::List(ref xs) => xs.len() as f64,
      Value::Object(ref m) => m.len() as f64,
      Value::Unit => 0.0,
      _ => 0.0,
    };
    Ok(Value::Number(n))
  });
  interp.host.insert("get", |args| {
    if args.len() != 2 { return Err("expected 2 args".into()); }
    let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
    match &args[0] {
      Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
      _ => Ok(Value::Unit),
    }
  });
  interp.host.insert("send", |_args| Ok(Value::Unit));
}

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
  let mut interp = Interpreter::new();
  register_test_hosts(&mut interp);
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

#[test]
fn lower_and_run_boolean_ops_and_truthiness() {
  let src = r#"
    let t = true
    let f = false
    let n1 = 1
    let n0 = 0
    let s0 = ""
    let sx = "x"
  # combine a few
    return (t and f) or (n1 and n0) or (s0 or sx)
  "#;
  let mut p = Parser::new(src).expect("parser");
  let ast = p.parse().expect("parse ok");
  let mut lower = Lowerer::new();
  let program = lower.lower_program_basic(&ast);
  let interp = Interpreter::new();
  let v = interp.run(&program).expect("run ok");
  assert_eq!(v, Value::Bool(true));
}

#[test]
fn lower_and_run_member_access_len_and_get() {
  let src = r#"
    let s = "hello"
    let a = [1,2,3]
    # len via property
    let ls = s.length
    let la = a.len
    return ls + la
  "#;
  let mut p = Parser::new(src).expect("parser");
  let ast = p.parse().expect("parse ok");
  let mut lower = Lowerer::new();
  let program = lower.lower_program_basic(&ast);
  let mut interp = Interpreter::new();
  register_test_hosts(&mut interp);
  let v = interp.run(&program).expect("run ok");
  assert_eq!(v, Value::Number(8.0)); // "hello" -> 5, [1,2,3] -> 3
}
