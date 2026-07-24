use patlang_runtime::ir::*;

#[test]
fn compiled_emit_invokes_when_handlers() {
    // Build Program with a synthesized handler and a main that calls emit("foo")
    let mut handler = Function { name: "__when_foo_1".into(), ..Default::default() };
    handler.body.push(Instr::Const(Value::String("ok".to_string().into())));
    handler.body.push(Instr::Return);

    let mut mainf = Function { name: "main".into(), ..Default::default() };
    mainf.body.push(Instr::Const(Value::String("foo".to_string().into())));
    mainf.body.push(Instr::CallHost("emit".into(), 1));
    mainf.body.push(Instr::Return);

    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("__when_foo_1".into(), handler);
    p.functions.insert("main".into(), mainf);
    p.event_handlers.insert("foo".into(), vec!["__when_foo_1".into()]);

    // Emit Rust
    let cg = RustCodegen::new();
    let src = cg.emit_rust(&p);

    // Compile and run
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let check = std::process::Command::new(&rustc).arg("--version").output();
    if check.is_err() { eprintln!("rustc not found; skipping event parity build-run test"); return; }

    let tmp = std::env::temp_dir().join("patlang_codegen_event_test");
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
    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    assert_eq!(stdout, "ok");
}
