//! Tests for Patlang Rust parser and lexer

use patlang_runtime::lexer::{Lexer, Token};
use patlang_runtime::parser::{Parser, ParserError};

#[test]
fn test_lexer_stub() {
    let mut lexer = Lexer::new("42");
    let token = lexer.next_token().unwrap();
    // Stub: Lexer always returns EOF for now
    assert_eq!(token, Token::EOF);
}

#[test]
fn test_parser_stub() {
    let mut parser = Parser::new("42").unwrap();
    let result = parser.parse();
    // Stub: Parser will error on parse_expression
    assert!(result.is_err());
}