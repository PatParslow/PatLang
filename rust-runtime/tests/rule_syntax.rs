// Real `rule Head(args) :- Body1, Body2.` / `rule Head(args).` declarative
// syntax (Stage B) -- exercised via the real lexer/parser/lowering/
// interpreter pipeline (the one hosts.rs actually backs; the older
// core_evaluator.rs harness used by some other tests doesn't know about
// rule_add/solve at all), since the whole point is proving the SUGAR
// desugars correctly, not just that the host functions work in isolation
// (already covered by rust-runtime/tests/goal_oriented_logic.rs).
use std::cell::RefCell;

use patlang_runtime::parser::Parser as Stage0Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::{register_stage0_shims, reset_world};

thread_local! {
    static PRINTED: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(v) => patlang_runtime::ir::ops::v_to_string(v),
        None => String::new(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s));
    Ok(Value::Unit)
}

fn run(src: &str) -> Vec<String> {
    reset_world();
    let mut parser = Stage0Parser::new(src).expect("lexer init");
    let ast = parser.parse().expect("parse should succeed");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("pipeline should run");
    PRINTED.with(|p| p.borrow().clone())
}

#[test]
fn fact_only_rule_declares_a_ground_fact() {
    let lines = run(r#"
rule ok(z).
let sols = solve("ok", ["z"])
print(list_len(sols))
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("1"));
}

#[test]
fn multi_goal_body_chains_correctly() {
    let lines = run(r#"
rule dep(a, b).
rule dep(b, c).
rule unchanged(c).
rule buildable(X) :- unchanged(X).
rule buildable(X) :- dep(X, Y), buildable(Y).
let sols = solve("buildable", ["a"])
print(list_len(sols))
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("1"), "2-hop chain a->b->c should resolve");
}

#[test]
fn rule_correctly_fails_when_chain_never_resolves() {
    let lines = run(r#"
rule dep(d, e).
rule buildable(X) :- unchanged(X).
rule buildable(X) :- dep(X, Y), buildable(Y).
let sols = solve("buildable", ["d"])
print(list_len(sols))
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("0"), "e is never unchanged, must correctly fail");
}

#[test]
fn rule_call_form_still_works_unbroken() {
    // The pre-existing rule_add(...) function-call form must be untouched --
    // this is the regression check for the parser's `if matches!(self.peek,
    // Token::LParen)` branch.
    let lines = run(r#"
rule_add("ok", ["z"], [])
let sols = solve("ok", ["z"])
print(list_len(sols))
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("1"));
}

#[test]
fn backtracking_across_multiple_facts_still_works_via_rule_syntax() {
    let lines = run(r#"
rule likes(alice, bob).
rule likes(alice, carol).
let sols = solve("likes", ["alice", "Y"])
print(list_len(sols))
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("2"));
}

#[test]
fn non_prolog_shaped_rule_syntax_degrades_to_a_no_op_instead_of_a_hard_error() {
    // Not every `rule NAME(...) :- ....` in the wild is Prolog-shaped --
    // found the hard way via native_parser/native_parser.patlang, which
    // uses the same surface syntax for an unrelated pseudo-code convention
    // with arbitrary statement bodies. This must parse (as a no-op,
    // matching the pre-Stage-B legacy behavior for any `rule` statement),
    // not throw a fatal parse error, and must not disturb parsing of the
    // statements that follow it.
    let lines = run(r#"
rule weird(x) :- x = { a: 1 }.
print("after")
"#);
    assert_eq!(lines.last().map(|s| s.as_str()), Some("after"));
}
