//! Tests for Patlang Rust parser and lexer

use patlang_runtime::parser::{Parser, ParserError};
use patlang_runtime::ast::Stmt;

#[test]
fn test_multiline_statement() {
    let input = "let x = 1 +\n 2 +\n 3";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1, "Should parse one statement across multiple lines");
}

#[test]
fn test_multiple_statements_one_line() {
    // Requires semicolon between same-line statements
    let input = "let x = 1; let y = 2";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 2, "Should parse two statements on one line with semicolon");
}

#[test]
fn test_statement_split_across_lines() {
    let input = "let x =\n1 +\n2";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1, "Should parse statement split across lines");
}

#[test]
fn test_error_recovery_malformed_statement() {
    let input = "let x = ; let y = 2";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let result = parser.parse();
    assert!(result.is_err(), "Malformed statement should cause error");
    // Error expected; recovery not implemented
}

#[test]
#[ignore]
fn test_lexer_stub() {
    // Ignored: Lexer implementation has changed, update test.
}

#[test]
#[ignore]
fn test_parser_stub() {
    // Ignored: Parser implementation has changed, update test.
}

#[test]
fn test_return_statement_parsing() {
    let input = "return\nreturn 42";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 2);
    match &stmts[0] { Stmt::Return(None) => {}, _ => panic!("Expected bare return") }
    match &stmts[1] { Stmt::Return(Some(expr)) => match expr { patlang_runtime::ast::Expr::Number(n) => assert_eq!(*n, 42.0), _ => panic!("Expected number") }, _ => panic!("Expected return with value") }
}

#[test]
fn test_if_else_block_parsing() {
    let input = "if 1 { return 2 } else { return 3 }";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 1);
    match &stmts[0] {
        Stmt::If { cond, then_branch, else_branch } => {
            // cond should be number 1
            match cond { patlang_runtime::ast::Expr::Number(n) => assert_eq!(*n, 1.0), _ => panic!("Expected number condition") }
            assert_eq!(then_branch.len(), 1);
            assert!(else_branch.is_some());
        }
        _ => panic!("Expected if statement"),
    }
}

#[test]
fn test_error_hint_for_missing_equals() {
    let input = "let x 1"; // missing '='
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let err = parser.parse().err().expect("Expected parse error");
    match err {
        ParserError::ExpectedToken { expected, line, hint } => {
            assert!(expected.contains("="));
            assert_eq!(line, 1);
            assert!(hint.contains("let name = value"));
        }
        _ => panic!("Expected ExpectedToken error with hint"),
    }
}