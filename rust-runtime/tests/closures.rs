//! Closures (Stage 0): |params| { body } literals capture free variables by
//! value at creation time, can be stored, passed as arguments, returned from
//! functions, and called through a local variable via CallValue.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

thread_local! {
    static PRINTED: std::cell::RefCell<Vec<String>> = std::cell::RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(v @ (Value::Int(_)|Value::Float(_)|Value::BigInt(_)|Value::Rational(_,_))) => patlang_runtime::ir::ops::v_to_string(v).into(),
        Some(Value::Bool(b)) => b.to_string().into(),
        _ => String::new().into(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s.to_string()));
    Ok(Value::Unit)
}

fn run_capture(src: &str) -> Vec<String> {
    let mut parser = Parser::new(src).expect("lexer init");
    let ast = parser.parse().expect("parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("run");
    PRINTED.with(|p| p.borrow().clone())
}

#[test]
fn closure_with_no_capture() {
    let out = run_capture("let add_five = |x| { return x + 5 }\nprint(add_five(10))\n");
    assert_eq!(out, vec!["15"]);
}

#[test]
fn closure_captures_enclosing_variable_by_value_snapshot() {
    // The closure snapshots `n` when created; a later reassignment of `n`
    // must not be visible inside the closure.
    let out = run_capture(
        "let n = 1\nlet show_n = |dummy| { return n }\nlet n = 99\nprint(show_n(0))\n"
    );
    assert_eq!(out, vec!["1"], "closure should see the value captured at creation time");
}

#[test]
fn nested_closure_captures_outer_functions_parameter() {
    let out = run_capture(
        "make a function called make_adder takes n returns r\n\
           return |x| { return x + n }\n\
         end\n\
         let add_three = make_adder(3)\n\
         print(add_three(7))\n"
    );
    assert_eq!(out, vec!["10"]);
}

#[test]
fn immediately_invoked_closure_literal() {
    let out = run_capture("print((|a, b| { return a * b })(6, 7))\n");
    assert_eq!(out, vec!["42"]);
}

#[test]
fn closure_passed_as_higher_order_argument() {
    let out = run_capture(
        "make a function called twice takes f, x returns r\n\
           return f(f(x))\n\
         end\n\
         let inc = |x| { return x + 1 }\n\
         print(twice(inc, 10))\n"
    );
    assert_eq!(out, vec!["12"]);
}

#[test]
fn closure_recompiles_identically_native() {
    // Same programs, but through the compiled (rustc) path, to prove
    // interpreted and native closures behave identically.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping native closure test");
        return;
    }
    use patlang_runtime::ir::RustCodegen;

    let src = "make a function called make_adder takes n returns r\n\
                 return |x| { return x + n }\n\
               end\n\
               let add_three = make_adder(3)\n\
               print(add_three(7))\n\
               print((|a, b| { return a * b })(6, 7))\n";
    let mut parser = Parser::new(src).expect("lexer init");
    let ast = parser.parse().expect("parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let cg = RustCodegen::new();
    let rust_src = cg.emit_rust(&program);

    let out_dir = std::env::temp_dir().join("patlang_closures_test");
    let _ = std::fs::create_dir_all(&out_dir);
    let src_path = out_dir.join("closures_main.rs");
    std::fs::write(&src_path, &rust_src).expect("write emitted source");
    let exe_path = out_dir.join(if cfg!(windows) { "closures_main.exe" } else { "closures_main" });
    let status = std::process::Command::new(&rustc)
        .arg("-O").arg(&src_path).arg("-o").arg(&exe_path)
        .status().expect("invoke rustc");
    assert!(status.success(), "rustc failed to compile emitted closures program");

    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success());
    let stdout = String::from_utf8_lossy(&out.stdout);
    let lines: Vec<&str> = stdout.lines().collect();
    assert_eq!(lines.get(0).copied(), Some("10"));
    assert_eq!(lines.get(1).copied(), Some("42"));
}
