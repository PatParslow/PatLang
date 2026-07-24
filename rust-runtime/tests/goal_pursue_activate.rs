//! Real semantics for the `goal`/`pursue`/`activate` surface syntax (GOAP):
//! `goal NAME { dep1(args), ... }` names a target state, `pursue GOAL`
//! plans against it (reusing the existing A2 GOAP planner exercised
//! directly in goal_oriented_logic.rs), and `activate PLAN` runs each
//! planned action's bound closure (action_bind) in order, stopping and
//! reporting failure the moment one returns false (a dependency "might be
//! a function [that] might fail for some reason" -- not every plan step
//! is guaranteed to succeed just because the planner found a path through
//! it). This exercises the FULL pipeline (parse -> lower -> interpret),
//! not host functions directly, since the gap being closed is at the
//! syntax/lowering level -- the underlying planner itself is already
//! covered by goal_oriented_logic.rs.
use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::{register_stage0_shims, reset_world};

thread_local! {
    static PRINTED: std::cell::RefCell<Vec<String>> = std::cell::RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.as_ref().clone(),
        Some(v @ (Value::Int(_) | Value::Float(_) | Value::BigInt(_) | Value::Rational(_, _))) => patlang_runtime::ir::ops::v_to_string(v),
        Some(Value::Bool(b)) => b.to_string(),
        Some(other) => format!("{:?}", other),
        None => String::new(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s));
    Ok(Value::Unit)
}

fn run_capture(src: &str) -> Vec<String> {
    reset_world();
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
fn goal_pursue_activate_full_round_trip_runs_actions_in_planned_order() {
    let out = run_capture(r#"
rule_add("dep", ["house", "walls"], [])
rule_add("dep", ["walls", "foundation"], [])
rule_add("built", ["foundation_base"], [])

action_add("build_base", [["built", ["foundation_base"]]], [["built", ["foundation"]]], [], 1)
action_add("build_dep", [["dep", ["X", "Y"]], ["built", ["Y"]]], [["built", ["X"]]], [], 1)

action_bind("build_base", |args| {
  print("base")
  return true
})
action_bind("build_dep", |args| {
  print("dep:" + args[0])
  return true
})

goal need_house {
  built(house)
}

let p = pursue need_house
let ok = activate p
print(ok)
"#);
    // Real planned order: build the foundation from its base, then walls
    // (which needs the foundation), then house (which needs walls) --
    // proving `pursue` actually ran the A2 search (not just returned
    // whatever was declared first) and `activate` called the RIGHT bound
    // closure for each step, in the right order, with the right bound arg.
    assert_eq!(out, vec!["base", "dep:walls", "dep:house", "true"]);
}

#[test]
fn pursue_is_usable_as_an_expression_not_just_a_bare_statement() {
    // `let p = pursue GOAL` -- not just `pursue GOAL` alone -- proving
    // pursue is a real expression (parse_primary), not sugar that only
    // works at statement level.
    let out = run_capture(r#"
rule_add("ready", ["a"], [])
action_add("build", [["ready", ["X"]]], [["built", ["X"]]], [], 1)
goal g { built(a) }
let p = pursue g
print(p)
"#);
    assert_eq!(out, vec!["List([String(\"build(X=a)\")])"]);
}

#[test]
fn activate_stops_and_reports_failure_when_a_bound_action_fails() {
    // A dependency "might be a function [that] might fail for some
    // reason" (explicit user correction during design) -- a plan is not
    // guaranteed to complete just because the planner found a path. The
    // third action must NOT run once the second one fails.
    let out = run_capture(r#"
action_bind("a", |args| { print("a"); return true })
action_bind("b", |args| { print("b"); return false })
action_bind("c", |args| { print("c"); return true })
let plan = ["a", "b", "c"]
let ok = activate plan
print(ok)
"#);
    assert_eq!(out, vec!["a", "b", "false"]);
}

#[test]
fn activate_reports_success_when_every_bound_action_succeeds() {
    let out = run_capture(r#"
action_bind("a", |args| { print("a"); return true })
action_bind("b", |args| { print("b"); return true })
let plan = ["a", "b"]
let ok = activate plan
print(ok)
"#);
    assert_eq!(out, vec!["a", "b", "true"]);
}

#[test]
fn goal_with_no_reachable_plan_activates_an_empty_plan_as_success() {
    // No actions registered at all -- `pursue` returns an empty plan
    // (the goal facts already hold, or nothing can reach them; either
    // way there's nothing to run), and activating an empty plan is
    // vacuously successful, not an error.
    let out = run_capture(r#"
goal g { built(nothing) }
let p = pursue g
let ok = activate p
print(ok)
"#);
    assert_eq!(out, vec!["true"]);
}
