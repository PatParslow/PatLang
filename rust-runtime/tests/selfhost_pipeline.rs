//! Regression test for the Stage 1 self-hosting pipeline:
//! PatLang-written lexer + parser (self_hosting/lib) run under the Stage 0 IR
//! interpreter, produce a list-shaped AST for a small program, and
//! compile_shape lowers + compiles it to a native executable whose output is
//! verified.

use std::cell::RefCell;

use patlang_runtime::parser::Parser as Stage0Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

thread_local! {
    static PRINTED: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() },
        Some(Value::Bool(b)) => b.to_string(),
        _ => String::new(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s));
    Ok(Value::Unit)
}

#[test]
fn selfhost_pipeline_compiles_feature_demo() {
    // Full feature matrix through the PatLang front-end: functions/recursion,
    // if/while, lists/index/member, events (when/emit), logic (fact/query),
    // OO (new/send/get) — compiled natively and output-verified.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping feature demo test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");
    let demo_path = format!("{}/../self_hosting/examples/feature_demo.patlang", manifest).replace('\\', "/");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "feature_demo.exe" } else { "feature_demo" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let exe = compile_shape(ast, \"{}\")\n\
         print(\"COMPILED\")\n",
        demo_path, exe_str
    );
    let full_src = format!("{}\n{}\n{}", lexer_lib, parser_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    patlang_runtime::ir::hosts::reset_world();

    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("feature pipeline should run");
    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("fib(10) = 55"), "recursion: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("sum = 10"), "lists/while: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("sum ok"), "if/else: {}", stdout);
    assert_eq!(printed.get(3).copied(), Some("event received: hello events"), "events: {}", stdout);
    assert_eq!(printed.get(4).copied(), Some("alice children: 2"), "logic facts/query: {}", stdout);
    assert_eq!(printed.get(5).copied(), Some("kim age: 42"), "OO new/send/get: {}", stdout);
    assert_eq!(printed.get(6).copied(), Some("doubled: [2, 4, 6, 8]"), "functional map via apply: {}", stdout);
    assert_eq!(printed.get(7).copied(), Some("evens: [2, 4]"), "functional filter via apply: {}", stdout);
}

#[test]
fn selfhost_pipeline_compiles_program_via_patlang_frontend() {
    // rustc is required to complete the pipeline; skip when unavailable
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping selfhost pipeline test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "pipeline_out.exe" } else { "pipeline_out" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    // Driver: lex + parse a tiny program with the PatLang front-end, then compile it
    let driver = format!(
        "let source = \"let x = 40\\nlet y = x + 2\\nprint(\\\"answer: \\\" + y)\\nprint(y * 10)\\n\"\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let exe = compile_shape(ast, \"{}\")\n\
         print(\"COMPILED\")\n",
        exe_str
    );
    let full_src = format!("{}\n{}\n{}", lexer_lib, parser_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);

    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("pipeline should run");

    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "pipeline did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    // Run the native executable produced by the PatLang front-end
    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("answer: 42"), "unexpected output: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("420"), "unexpected output: {}", stdout);
}
