// Exercises the PatLang-authored regex engine (self_hosting/lib/regex.patlang)
// directly through the Rust IR pipeline, to validate it before it gets wired
// into the syntax_dsl source preprocessor. This is a temporary validation
// harness for the regex engine itself.
use patlang_runtime::ir::{Lowerer, Interpreter, Value};
use patlang_runtime::parser::Parser;

fn run_regex_match(pattern: &str, text: &str, start: f64) -> f64 {
    let src = std::fs::read_to_string(
        concat!(env!("CARGO_MANIFEST_DIR"), "/../self_hosting/lib/regex.patlang")
    ).expect("read regex.patlang");
    let mut p = Parser::new(&src).expect("parser init");
    let ast = p.parse().expect("parse regex.patlang");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let interp = Interpreter::new();
    // register_stage0_shims is private to the crate's hosts module in some
    // builds; use the public re-export path instead.
    let mut interp = interp;
    patlang_runtime::ir::hosts::register_stage0_shims(&mut interp);
    let args = vec![Value::String(pattern.to_string()), Value::String(text.to_string()), Value::Int(start as i64)];
    let v = interp.call_function(&program, "regex_match_string_at", &args).expect("call regex_match_string_at");
    v.as_number().unwrap_or_else(|_| panic!("expected Number, got {:?}", v))
}

#[test]
fn regex_literal_match() {
    assert_eq!(run_regex_match("abc", "xabcx", 1.0), 4.0);
    assert_eq!(run_regex_match("abc", "xabxx", 1.0), -1.0);
}

#[test]
fn regex_dot_and_star() {
    assert_eq!(run_regex_match("a.*b", "aXYb", 0.0), 4.0);
    assert_eq!(run_regex_match("a.*b", "a", 0.0), -1.0);
    assert_eq!(run_regex_match("a*", "aaab", 0.0), 3.0);
}

#[test]
fn regex_class_and_plus() {
    assert_eq!(run_regex_match("[a-z]+", "hello123", 0.0), 5.0);
    assert_eq!(run_regex_match("[0-9]+", "hello123", 5.0), 8.0);
    assert_eq!(run_regex_match("[^0-9]+", "abc123", 0.0), 3.0);
}

#[test]
fn regex_alternation_and_group() {
    assert_eq!(run_regex_match("(GET|POST|PUT|DELETE)", "GET /users", 0.0), 3.0);
    assert_eq!(run_regex_match("(GET|POST|PUT|DELETE)", "POST /x", 0.0), 4.0);
    assert_eq!(run_regex_match("(GET|POST|PUT|DELETE)", "PATCH /x", 0.0), -1.0);
}

#[test]
fn regex_word_boundary_http_verb() {
    // Mirrors the RouterDSL example: \b(GET|POST|PUT|DELETE)\b
    let pattern = "\\b(GET|POST|PUT|DELETE)\\b";
    assert_eq!(run_regex_match(pattern, "GET /users", 0.0), 3.0);
    assert_eq!(run_regex_match(pattern, "GETX /users", 0.0), -1.0);
}

#[test]
fn regex_url_path() {
    let pattern = "/[a-zA-Z0-9_/:-]*";
    assert_eq!(run_regex_match(pattern, "/users/:id/edit -> X", 0.0), 15.0);
}

#[test]
fn regex_optional_and_anchors() {
    assert_eq!(run_regex_match("colou?r", "color", 0.0), 5.0);
    assert_eq!(run_regex_match("colou?r", "colour", 0.0), 6.0);
    assert_eq!(run_regex_match("^abc$", "abc", 0.0), 3.0);
    assert_eq!(run_regex_match("^abc$", "abcd", 0.0), -1.0);
}
