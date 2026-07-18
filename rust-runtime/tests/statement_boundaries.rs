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

// A statement separator (';'/newline) is welcome but no longer required:
// by the time a statement is fully parsed, its own expression parser has
// already resolved exactly how far it extends (operator lookahead, not
// newline significance), so there's no remaining ambiguity for a
// separator to protect against -- the one case that WOULD have been
// ambiguous (a bare `{ ... }` statement competing with trailing-closure
// sugar) is handled by rejecting bare `{ ... }` as a statement outright
// instead, see `bare_block_as_a_statement_is_rejected` below.
#[test]
fn test_same_line_without_separator_is_now_allowed() {
    let input = "let a = 1 let b = 2"; // missing semicolon and no newline
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse should now succeed without a separator");
    assert_eq!(stmts.len(), 2);
}

#[test]
fn bare_block_as_a_statement_is_rejected() {
    // The one case dropping the separator requirement made genuinely
    // ambiguous otherwise: `f(x)` followed by a bare `{ ... }` statement
    // is indistinguishable from `f(x) { ... }` trailing-closure sugar
    // without some marker between them. Resolved by making bare `{ ... }`
    // illegal as its own statement -- it's still legal as a VALUE (e.g.
    // `let f = { ... }`, a real function literal), just not standalone.
    let input = "print(1)\n{ print(2) }\nprint(3)";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let err = parser.parse().err().expect("Expected parse error");
    match err {
        patlang_runtime::parser::ParserError::UnexpectedToken { token, .. } => {
            assert!(matches!(token, patlang_runtime::lexer::Token::BlockStart));
        }
        other => panic!("Expected UnexpectedToken(BlockStart), got {:?}", other),
    }
}

#[test]
fn bare_block_as_a_value_still_works() {
    let input = "let f = { return 42 }\nprint(f())";
    let mut parser = Parser::new(input).expect("Parser creation failed");
    let stmts = parser.parse().expect("Parse failed");
    assert_eq!(stmts.len(), 2);
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
