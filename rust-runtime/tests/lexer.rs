//! Lexer tests for Patlang

use patlang_runtime::lexer::{Lexer, Token, LexerError};

fn lex_all(input: &str) -> Vec<Result<Token, LexerError>> {
let mut lexer = Lexer::new(input);
let mut tokens = Vec::new();
loop {
let tok = lexer.next_token();
if let Ok(Token::EOF) = &tok {
tokens.push(tok);
break;
}
tokens.push(tok);
}
tokens
}

#[test]
fn test_simple_number() {
let tokens = lex_all("42");
assert_eq!(tokens[0], Ok(Token::Number(42.0)));
assert_eq!(tokens[1], Ok(Token::EOF));
}

#[test]
fn test_identifier_and_keywords() {
let tokens = lex_all("let x = 5");
assert_eq!(tokens[0], Ok(Token::Let));
assert_eq!(tokens[1], Ok(Token::Identifier("x".to_string())));
assert_eq!(tokens[2], Ok(Token::Equal));
assert_eq!(tokens[3], Ok(Token::Number(5.0)));
assert_eq!(tokens[4], Ok(Token::EOF));
}

#[test]
fn test_operators_and_parens() {
let tokens = lex_all("(a+b)*c/2");
assert_eq!(tokens[0], Ok(Token::LParen));
assert_eq!(tokens[1], Ok(Token::Identifier("a".to_string())));
assert_eq!(tokens[2], Ok(Token::Plus));
assert_eq!(tokens[3], Ok(Token::Identifier("b".to_string())));
assert_eq!(tokens[4], Ok(Token::RParen));
assert_eq!(tokens[5], Ok(Token::Star));
assert_eq!(tokens[6], Ok(Token::Identifier("c".to_string())));
assert_eq!(tokens[7], Ok(Token::Slash));
assert_eq!(tokens[8], Ok(Token::Number(2.0)));
assert_eq!(tokens[9], Ok(Token::EOF));
}

#[test]
fn test_string_literal() {
let tokens = lex_all("\"hello\"");
assert_eq!(tokens[0], Ok(Token::String("hello".to_string())));
assert_eq!(tokens[1], Ok(Token::EOF));
}

#[test]
fn test_unterminated_string() {
let tokens = lex_all("\"hello");
assert!(matches!(tokens[0], Err(LexerError::UnterminatedString(_))));
}

#[test]
fn test_unicode_string_literal() {
    // Regression test: the lexer used to read string-literal bytes one at a
    // time via `bytes[pos] as char`, never decoding multi-byte UTF-8
    // sequences -- so "café" (4 real characters, the last a 2-byte UTF-8
    // sequence) came back as 5 corrupted characters. Covers a precomposed
    // accented Latin character (2-byte UTF-8) and a CJK character (3-byte
    // UTF-8), both inside an otherwise-ordinary string literal.
    let tokens = lex_all("\"café\"");
    assert_eq!(tokens[0], Ok(Token::String("café".to_string())));
    assert_eq!(tokens[1], Ok(Token::EOF));

    let tokens = lex_all("\"你好\"");
    assert_eq!(tokens[0], Ok(Token::String("你好".to_string())));
    assert_eq!(tokens[1], Ok(Token::EOF));
}

#[test]
fn test_dot_and_newline() {
let tokens = lex_all("foo.\nbar");
assert_eq!(tokens[0], Ok(Token::Identifier("foo".to_string())));
assert_eq!(tokens[1], Ok(Token::Dot));
assert_eq!(tokens[2], Ok(Token::Newline));
assert_eq!(tokens[3], Ok(Token::Identifier("bar".to_string())));
assert_eq!(tokens[4], Ok(Token::EOF));
}

#[test]
fn test_comments_and_whitespace() {
let tokens = lex_all("a # comment\nb");
assert_eq!(tokens[0], Ok(Token::Identifier("a".to_string())));
assert_eq!(tokens[1], Ok(Token::Newline));
assert_eq!(tokens[2], Ok(Token::Identifier("b".to_string())));
assert_eq!(tokens[3], Ok(Token::EOF));
}

#[test]
fn test_block_delimiters() {
let tokens = lex_all("{foo} bar");
assert_eq!(tokens[0], Ok(Token::BlockStart));
assert_eq!(tokens[1], Ok(Token::Identifier("foo".to_string())));
assert_eq!(tokens[2], Ok(Token::BlockEnd));
assert_eq!(tokens[3], Ok(Token::Identifier("bar".to_string())));
assert_eq!(tokens[4], Ok(Token::EOF));
}

#[test]
fn test_comparisons() {
let tokens = lex_all("a == b >= c <= d > e < f");
assert_eq!(tokens[0], Ok(Token::Identifier("a".to_string())));
assert_eq!(tokens[1], Ok(Token::EqualEqual));
assert_eq!(tokens[2], Ok(Token::Identifier("b".to_string())));
assert_eq!(tokens[3], Ok(Token::GreaterEqual));
assert_eq!(tokens[4], Ok(Token::Identifier("c".to_string())));
assert_eq!(tokens[5], Ok(Token::LessEqual));
assert_eq!(tokens[6], Ok(Token::Identifier("d".to_string())));
assert_eq!(tokens[7], Ok(Token::Greater));
assert_eq!(tokens[8], Ok(Token::Identifier("e".to_string())));
assert_eq!(tokens[9], Ok(Token::Less));
assert_eq!(tokens[10], Ok(Token::Identifier("f".to_string())));
assert_eq!(tokens[11], Ok(Token::EOF));
}