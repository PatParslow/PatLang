//! Regression test for the Stage 1 self-hosted lexer:
//! self_hosting/lexer_stage1.patlang must parse, lower, and run under the
//! Stage 0 IR interpreter, tokenizing its embedded sample program correctly.

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
        Some(v @ (Value::Int(_)|Value::Float(_)|Value::BigInt(_)|Value::Rational(_,_))) => patlang_runtime::ir::ops::v_to_string(v).into(),
        Some(Value::Bool(b)) => b.to_string().into(),
        _ => String::new().into(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s.to_string()));
    Ok(Value::Unit)
}

#[test]
fn selfhost_lexer_tokenizes_sample_program() {
    let path = format!("{}/../self_hosting/lexer_stage1.patlang", env!("CARGO_MANIFEST_DIR"));
    let raw = std::fs::read_to_string(&path).expect("read lexer_stage1.patlang");
    let base = std::path::Path::new(&path).parent().unwrap().to_path_buf();
    let src = patlang_runtime::preprocess::expand_includes(&raw, &base).expect("expand includes");

    let mut parser = Stage0Parser::new(&src).expect("lexer init");
    let ast = parser.parse().expect("stage 1 lexer source should parse");

    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);

    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("stage 1 lexer should run");

    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(!lines.is_empty(), "lexer should print token summary");
    assert_eq!(lines[0], "TOKENS: 30", "expected 30 tokens for the sample program, got: {:?}", lines);

    // Spot-check the token stream: first tokens of `let x = 41`
    assert_eq!(lines[1], "IDENT 'let' @1");
    assert_eq!(lines[2], "IDENT 'x' @1");
    assert_eq!(lines[3], "OP '=' @1");
    assert_eq!(lines[4], "NUM '41' @1");

    // String literal token from line 4 of the sample
    assert!(lines.iter().any(|l| l == "STR 'hi there' @4"), "string token missing: {:?}", lines);
    // Two-char operator
    assert!(lines.iter().any(|l| l == "OP '>=' @5"), ">= token missing: {:?}", lines);
    // Final EOF token
    assert!(lines.iter().any(|l| l.starts_with("EOF")), "EOF token missing: {:?}", lines);
}
