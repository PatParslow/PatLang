use patlang_runtime::ir::*;

#[test]
fn ir_interpreter_add_and_branch() {
    // fn main() {
    //   let x = 3 + 4;
    //   if x > 5 { return x; } else { return 0; }
    // }
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(3)));
    f.body.push(Instr::Const(Value::Int(4)));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::StoreLocal("x".into()));
    // load x, const 5, gt
    f.body.push(Instr::LoadLocal("x".into()));
    f.body.push(Instr::Const(Value::Int(5)));
    f.body.push(Instr::BinOp(BinOpKind::Gt));
    // if false jump to else
    // then branch: return x
    let else_pc = 11usize;
    f.body.push(Instr::JumpIfFalse(else_pc));
    f.body.push(Instr::LoadLocal("x".into()));
    f.body.push(Instr::Return);
    // else: return 0
    f.body.push(Instr::Const(Value::Int(0)));
    f.body.push(Instr::Return);

    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);

    let interp = Interpreter::new();
    let v = interp.run(&program).expect("run ok");
    assert_eq!(v, Value::Int(7));
}

#[test]
fn ir_interpreter_host_call() {
    // return print_num(2+3)
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(2)));
    f.body.push(Instr::Const(Value::Int(3)));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::CallHost("double".into(), 1));
    f.body.push(Instr::Return);

    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);

    let mut interp = Interpreter::new();
    interp.host.insert("double", |args: &[Value]| {
        let x = args[0].as_number()?;
        Ok(Value::Int((x * 2.0) as i64))
    });

    let v = interp.run(&program).expect("run ok");
    assert_eq!(v, Value::Int(10));
}

#[test]
fn ir_interpreter_truthiness_and_or() {
    // return (true and false) or (1 and -1) or ("" or "x")
    let mut f = Function { name: "main".into(), ..Default::default() };
    // true and false -> false
    f.body.push(Instr::Const(Value::Bool(true)));
    f.body.push(Instr::Const(Value::Bool(false)));
    f.body.push(Instr::BinOp(BinOpKind::And));
    // 1 and -1 -> true
    f.body.push(Instr::Const(Value::Int(1)));
    f.body.push(Instr::Const(Value::Int(-1)));
    f.body.push(Instr::BinOp(BinOpKind::And));
    // (false) or (true) -> true
    f.body.push(Instr::BinOp(BinOpKind::Or));
    // "" or "x" -> true
    f.body.push(Instr::Const(Value::String(String::new().into())));
    f.body.push(Instr::Const(Value::String("x".to_string().into())));
    f.body.push(Instr::BinOp(BinOpKind::Or));
    // (true) or (true) -> true
    f.body.push(Instr::BinOp(BinOpKind::Or));
    f.body.push(Instr::Return);

    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);

    let interp = Interpreter::new();
    let v = interp.run(&program).expect("run ok");
    assert_eq!(v, Value::Bool(true));
}
