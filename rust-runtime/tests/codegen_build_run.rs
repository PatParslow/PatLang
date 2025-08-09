use patlang_runtime::ir::*;

#[test]
fn codegen_build_and_run_matches_interpreter_output() {
    // Build a small program: let s = "hi"; let a=[1,2,3]; return s.length + a.len
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::String("hi".into())));
    f.body.push(Instr::StoreLocal("s".into()));
    f.body.push(Instr::Const(Value::Number(1.0)));
    f.body.push(Instr::Const(Value::Number(2.0)));
    f.body.push(Instr::Const(Value::Number(3.0)));
    f.body.push(Instr::BuildList(3));
    f.body.push(Instr::StoreLocal("a".into()));
    f.body.push(Instr::LoadLocal("s".into()));
    f.body.push(Instr::CallHost("len".into(), 1));
    f.body.push(Instr::LoadLocal("a".into()));
    f.body.push(Instr::CallHost("len".into(), 1));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    // Run interpreter
    let mut interp = Interpreter::new();
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
    let v = interp.run(&p).expect("run ok");
    let expected = match v { Value::Number(n) => n, _ => panic!("unexpected value") };

    // Emit Rust
    let cg = RustCodegen::new();
    let src = cg.emit_rust(&p);

    // Try to compile with rustc; if rustc missing, skip test
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let check = std::process::Command::new(&rustc).arg("--version").output();
    if check.is_err() { eprintln!("rustc not found; skipping build-run test"); return; }

    let tmp = std::env::temp_dir().join("patlang_codegen_test");
    let _ = std::fs::create_dir_all(&tmp);
    let src_path = tmp.join("prog.rs");
    std::fs::write(&src_path, src).expect("write src");
    let exe_path = if cfg!(windows) { tmp.join("prog.exe") } else { tmp.join("prog") };
    let st = std::process::Command::new(&rustc)
        .arg("-O")
        .arg(&src_path)
        .arg("-o").arg(&exe_path)
        .status()
        .expect("invoke rustc");
    assert!(st.success(), "rustc failed: {:?}", st);
    let out = std::process::Command::new(&exe_path).output().expect("run child");
    assert!(out.status.success());
    let stdout = String::from_utf8_lossy(&out.stdout);
    // The generated main prints the result
    let printed = stdout.trim().parse::<f64>().expect("parse output as number");
    assert_eq!(printed, expected);
}
