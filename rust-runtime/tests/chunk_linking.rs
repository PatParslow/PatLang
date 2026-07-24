// Exploratory test for the --patc prelude chunk-precompile-and-link
// mechanism (Stage 40, patlang-patc-prelude-chunk-linking-investigation
// memory). Shells out to rustc several times (once per chunk rlib, once
// for the final link) -- like other rustc-shelling tests in this suite,
// marked #[ignore] and run explicitly, not part of the routine `cargo
// test` pass.
use patlang_runtime::ir::*;
use patlang_runtime::ir::codegen::build_chunked_native;

fn run_exe(path: &str) -> String {
    let out = std::process::Command::new(path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe exited non-zero: {:?}", out);
    String::from_utf8_lossy(&out.stdout).to_string()
}

#[test]
#[ignore]
fn chunked_build_plain_arithmetic() {
    // print(3 + 4)
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(3)));
    f.body.push(Instr::Const(Value::Int(4)));
    f.body.push(Instr::BinOp(BinOpKind::Add));
    f.body.push(Instr::CallHost("print".into(), 1));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    let cg = RustCodegen::new();
    let program_src = cg.emit_rust_chunked(&p);
    let chunks: Vec<String> = RustCodegen::required_chunks(&p).iter().map(|c| c.name().to_string()).collect();
    println!("required chunks: {:?}", chunks);

    let out_path = std::env::temp_dir().join("chunked_arith_test.exe");
    let result = build_chunked_native(&program_src, &chunks, out_path.to_str().unwrap());
    let exe = result.expect("build_chunked_native should succeed");
    let stdout = run_exe(&exe);
    assert_eq!(stdout.trim(), "7");
}

#[test]
#[ignore]
fn chunked_build_strings_and_logic() {
    // fact("age", ["alice", 30]) ; print(query("age", ["alice", "?x"]))
    // -- exercises a non-core chunk (logic) through the new dispatch path.
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::String("age".to_string().into())));
    f.body.push(Instr::Const(Value::String("alice".to_string().into())));
    f.body.push(Instr::Const(Value::Int(30)));
    f.body.push(Instr::BuildList(2));
    f.body.push(Instr::CallHost("fact".into(), 2));
    f.body.push(Instr::Const(Value::String("age".to_string().into())));
    f.body.push(Instr::Const(Value::String("alice".to_string().into())));
    f.body.push(Instr::Const(Value::String("?x".to_string().into())));
    f.body.push(Instr::BuildList(2));
    f.body.push(Instr::CallHost("query".into(), 2));
    f.body.push(Instr::CallHost("print".into(), 1));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    let cg = RustCodegen::new();
    let program_src = cg.emit_rust_chunked(&p);
    let chunks: Vec<String> = RustCodegen::required_chunks(&p).iter().map(|c| c.name().to_string()).collect();
    println!("required chunks: {:?}", chunks);
    assert!(chunks.iter().any(|c| c == "logic"), "this program should require the logic chunk");

    let out_path = std::env::temp_dir().join("chunked_logic_test.exe");
    let result = build_chunked_native(&program_src, &chunks, out_path.to_str().unwrap());
    let exe = result.expect("build_chunked_native should succeed");
    let _stdout = run_exe(&exe);
    // Not asserting exact output shape here (query's return representation
    // isn't the point of this test) -- just that dispatch through a
    // non-core chunk compiles, links, and runs without erroring.
}

#[test]
#[ignore]
fn chunked_build_oo_needs_logic() {
    // new("Point") ; set_var(obj, "x", 5) ; print(get(obj, "x"))
    // -- exercises Tier 2 (`oo`, which per CROSS_CHUNK_EDGES additionally
    // needs `logic` -- `send()`'s dispatcher reads `FACTS`, only declared
    // in PRELUDE_LOGIC's text).
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::String("Point".to_string().into())));
    f.body.push(Instr::CallHost("new".into(), 1));
    f.body.push(Instr::StoreLocal("obj".into()));
    f.body.push(Instr::LoadLocal("obj".into()));
    f.body.push(Instr::Const(Value::String("x".to_string().into())));
    f.body.push(Instr::Const(Value::Int(5)));
    f.body.push(Instr::CallHost("set_var".into(), 3));
    f.body.push(Instr::LoadLocal("obj".into()));
    f.body.push(Instr::Const(Value::String("x".to_string().into())));
    f.body.push(Instr::CallHost("get".into(), 2));
    f.body.push(Instr::CallHost("print".into(), 1));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    let cg = RustCodegen::new();
    let program_src = cg.emit_rust_chunked(&p);
    let chunks: Vec<String> = RustCodegen::required_chunks(&p).iter().map(|c| c.name().to_string()).collect();
    println!("required chunks: {:?}", chunks);
    assert!(chunks.iter().any(|c| c == "oo"), "this program should require the oo chunk");
    assert!(chunks.iter().any(|c| c == "logic"), "oo needs logic per CROSS_CHUNK_EDGES");

    let out_path = std::env::temp_dir().join("chunked_oo_test.exe");
    let result = build_chunked_native(&program_src, &chunks, out_path.to_str().unwrap());
    let exe = result.expect("build_chunked_native should succeed");
    let _stdout = run_exe(&exe);
}

#[test]
#[ignore]
fn chunked_build_math_needs_numeric_tower() {
    // print(sqrt(16.0)) -- exercises `math`, which per CROSS_CHUNK_EDGES
    // additionally needs `numeric_tower` (so also exercises the
    // `base_tower` variant together with a non-base, non-core chunk).
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Float(16.0)));
    f.body.push(Instr::CallHost("sqrt".into(), 1));
    f.body.push(Instr::CallHost("print".into(), 1));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);

    let cg = RustCodegen::new();
    let program_src = cg.emit_rust_chunked(&p);
    let chunks: Vec<String> = RustCodegen::required_chunks(&p).iter().map(|c| c.name().to_string()).collect();
    println!("required chunks: {:?}", chunks);
    assert!(chunks.iter().any(|c| c == "math"), "this program should require the math chunk");
    assert!(chunks.iter().any(|c| c == "numeric_tower"), "math needs numeric_tower per CROSS_CHUNK_EDGES");

    let out_path = std::env::temp_dir().join("chunked_math_test.exe");
    let result = build_chunked_native(&program_src, &chunks, out_path.to_str().unwrap());
    let exe = result.expect("build_chunked_native should succeed");
    let stdout = run_exe(&exe);
    assert_eq!(stdout.trim(), "4");
}
