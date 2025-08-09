//! Statement boundary and multi-line parsing tests

use patlang_runtime::parser::Parser;
use patlang_runtime::ast::Stmt;

#[test]
fn test_mixed_terminators_and_blank_lines() {
    let input = "\n\nlet a = 1;\n\nlet b = 2\n\nlet c = 3; let d = 4\n\n";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 4);
}

#[test]
fn test_parenthesized_multiline_expression() {
    let input = "let x = (1\n + 2\n) * 3";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1);
    match &stmts[0] { Stmt::Let { .. } => {}, _ => panic!("Expected let statement") }
}

#[test]
fn test_same_line_requires_semicolon() {
    let input = "let a = 1 let b = 2"; // missing semicolon and no newline
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let err = parser.parse().err().expect("Expected parse error");
    match err {
        patlang_runtime::parser::ParserError::ExpectedToken { expected, hint, .. } => {
            assert!(expected.contains("separator") || expected.contains("separator"));
            assert!(hint.contains("';'"));
        }
        _ => panic!("Expected separator error"),
    }
}

#[test]
fn test_newline_between_statements_no_semicolon() {
    let input = "let a = 1\nlet b = 2"; // newline is fine
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 2);
}

#[test]
fn test_multiline_call_arguments() {
    let input = "print(\n  1,\n  2,\n  3\n)";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1);
}

#[test]
fn test_let_allows_newline_before_equals() {
    let input = "let x\n= 42";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1);
}
