use patlang_runtime::ir::*;

#[test]
fn codegen_emits_rust_source() {
    // Build a tiny IR program: return 1 + 2
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(1)));
    f.body.push(Instr::Const(Value::Int(2)));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    let cg = RustCodegen::new();
    let src = cg.emit_rust(&p);
    assert!(src.contains("fn main()"));
    assert!(src.contains("build_program()"));
    assert!(src.contains("Instr::Const"));
}
