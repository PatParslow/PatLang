// A1 (backward-chaining resolver), A2 (GOAP planner), and contracts-as-facts
// -- exercised directly against the host functions, not through .patlang
// source, for precise assertions on solution counts/ordering/costs.
use patlang_runtime::ir::hosts::{host_action_add, host_contract_check, host_plan, host_rule_add, host_solve, reset_world};
use patlang_runtime::ir::types::Value;

fn s(x: &str) -> Value { Value::String(x.to_string()) }
fn list(xs: Vec<Value>) -> Value { Value::List(xs) }
fn pair(pred: &str, args: Vec<Value>) -> Value { list(vec![s(pred), list(args)]) }

#[test]
fn a1_two_hop_chain_resolves() {
    reset_world();
    // dep(a,b). dep(b,c). unchanged(c).
    // buildable(X) :- unchanged(X).
    // buildable(X) :- dep(X,Y), buildable(Y).
    host_rule_add(&[s("dep"), list(vec![s("a"), s("b")]), list(vec![])]).unwrap();
    host_rule_add(&[s("dep"), list(vec![s("b"), s("c")]), list(vec![])]).unwrap();
    host_rule_add(&[s("unchanged"), list(vec![s("c")]), list(vec![])]).unwrap();
    host_rule_add(&[s("buildable"), list(vec![s("X")]), list(vec![pair("unchanged", vec![s("X")])])]).unwrap();
    host_rule_add(&[s("buildable"), list(vec![s("X")]), list(vec![pair("dep", vec![s("X"), s("Y")]), pair("buildable", vec![s("Y")])])]).unwrap();

    let sols = host_solve(&[s("buildable"), list(vec![s("a")])]).unwrap();
    match sols { Value::List(xs) => assert_eq!(xs.len(), 1, "expected exactly one 2-hop derivation"), _ => panic!("expected List") }
}

#[test]
fn a1_correctly_fails_when_chain_never_resolves() {
    reset_world();
    host_rule_add(&[s("dep"), list(vec![s("d"), s("e")]), list(vec![])]).unwrap();
    host_rule_add(&[s("buildable"), list(vec![s("X")]), list(vec![pair("unchanged", vec![s("X")])])]).unwrap();
    host_rule_add(&[s("buildable"), list(vec![s("X")]), list(vec![pair("dep", vec![s("X"), s("Y")]), pair("buildable", vec![s("Y")])])]).unwrap();
    // "e" is never asserted unchanged anywhere -- must correctly fail, not
    // just return the first plausible-looking rule application.
    let sols = host_solve(&[s("buildable"), list(vec![s("d")])]).unwrap();
    match sols { Value::List(xs) => assert_eq!(xs.len(), 0), _ => panic!("expected List") }
}

#[test]
fn a1_backtracking_returns_all_matching_facts() {
    reset_world();
    host_rule_add(&[s("likes"), list(vec![s("alice"), s("bob")]), list(vec![])]).unwrap();
    host_rule_add(&[s("likes"), list(vec![s("alice"), s("carol")]), list(vec![])]).unwrap();
    let sols = host_solve(&[s("likes"), list(vec![s("alice"), s("Y")])]).unwrap();
    match sols {
        Value::List(xs) => {
            assert_eq!(xs.len(), 2, "should backtrack across both matching facts, not stop at the first");
            let bound: Vec<String> = xs.iter().map(|sol| match sol {
                Value::List(pair) => match &pair[1] { Value::String(v) => v.clone(), _ => panic!() },
                _ => panic!(),
            }).collect();
            assert!(bound.contains(&"bob".to_string()));
            assert!(bound.contains(&"carol".to_string()));
        }
        _ => panic!("expected List"),
    }
}

#[test]
fn a1_depth_cap_prevents_hang_on_cyclic_rule() {
    reset_world();
    // p(X) :- p(X).  A directly self-referential rule with no base case --
    // must terminate (return no solutions) rather than hang.
    host_rule_add(&[s("p"), list(vec![s("X")]), list(vec![pair("p", vec![s("X")])])]).unwrap();
    let sols = host_solve(&[s("p"), list(vec![s("z")])]).unwrap();
    match sols { Value::List(xs) => assert_eq!(xs.len(), 0), _ => panic!("expected List") }
}

#[test]
fn a2_goap_plan_prefers_cheaper_multistep_over_pricier_direct_path() {
    reset_world();
    host_action_add(&[s("compile_b"), list(vec![]), list(vec![pair("compiled", vec![s("b")])]), list(vec![]), Value::Int(5)]).unwrap();
    host_action_add(&[s("compile_a"), list(vec![pair("compiled", vec![s("b")])]), list(vec![pair("compiled", vec![s("a")])]), list(vec![]), Value::Int(3)]).unwrap();
    host_action_add(&[s("link"), list(vec![pair("compiled", vec![s("a")]), pair("compiled", vec![s("b")])]), list(vec![pair("shipped", vec![])]), list(vec![]), Value::Int(2)]).unwrap();
    host_action_add(&[s("direct_ship"), list(vec![pair("compiled", vec![s("b")])]), list(vec![pair("shipped", vec![])]), list(vec![]), Value::Int(100)]).unwrap();

    let result = host_plan(&[list(vec![pair("shipped", vec![])])]).unwrap();
    match result {
        Value::List(steps) => {
            let names: Vec<String> = steps.iter().map(|v| match v { Value::String(s) => s.clone(), _ => panic!() }).collect();
            assert_eq!(names, vec!["compile_b", "compile_a", "link"], "should pick the cost-10 path, not the cost-105 shortcut");
        }
        _ => panic!("expected List"),
    }
}

#[test]
fn a2_parameterized_action_grounds_against_each_matching_fact() {
    reset_world();
    // Two targets, each independently "ready" -- a single parameterized
    // `build(X)` action (precond ready(X), effect built(X)) should ground
    // into two distinct instantiations, one per target, not just the first.
    host_rule_add(&[s("ready"), list(vec![s("a")]), list(vec![])]).unwrap();
    host_rule_add(&[s("ready"), list(vec![s("b")]), list(vec![])]).unwrap();
    host_action_add(&[s("build"), list(vec![pair("ready", vec![s("X")])]), list(vec![pair("built", vec![s("X")])]), list(vec![]), Value::Int(1)]).unwrap();

    let result = host_plan(&[list(vec![pair("built", vec![s("a")]), pair("built", vec![s("b")])])]).unwrap();
    match result {
        Value::List(steps) => {
            let names: Vec<String> = steps.iter().map(|v| match v { Value::String(s) => s.clone(), _ => panic!() }).collect();
            assert_eq!(names.len(), 2, "should take exactly two build(X) steps to reach both goal facts");
            assert!(names.contains(&"build(X=a)".to_string()), "step names: {:?}", names);
            assert!(names.contains(&"build(X=b)".to_string()), "step names: {:?}", names);
        }
        _ => panic!("expected List"),
    }
}

#[test]
fn a2_parameterized_action_binds_shared_variable_across_two_preconds() {
    reset_world();
    // dep(target, base). ready(base). A single `build(X)` action needs BOTH
    // dep(X, Y) and ready(Y) to hold under the SAME binding of Y -- proving
    // the conjunctive match threads one variable's binding from the first
    // precond into the second, not just unifying each precond in isolation.
    host_rule_add(&[s("dep"), list(vec![s("target"), s("base")]), list(vec![])]).unwrap();
    host_rule_add(&[s("ready"), list(vec![s("base")]), list(vec![])]).unwrap();
    host_action_add(&[s("build"), list(vec![pair("dep", vec![s("X"), s("Y")]), pair("ready", vec![s("Y")])]), list(vec![pair("built", vec![s("X")])]), list(vec![]), Value::Int(1)]).unwrap();

    let result = host_plan(&[list(vec![pair("built", vec![s("target")])])]).unwrap();
    match result {
        Value::List(steps) => {
            let names: Vec<String> = steps.iter().map(|v| match v { Value::String(s) => s.clone(), _ => panic!() }).collect();
            assert_eq!(names, vec!["build(X=target,Y=base)"], "step names: {:?}", names);
        }
        _ => panic!("expected List"),
    }
}

#[test]
fn a2_ground_action_still_matches_via_the_single_empty_substitution() {
    reset_world();
    // A regression guard, not just relying on the pre-existing suite above:
    // an action with zero variables anywhere in its preconds must ground to
    // exactly one instantiation (the empty substitution) when its preconds
    // hold, and zero when they don't -- the exact old plain-equality
    // behavior, now expressed as a special case of the general matcher.
    host_action_add(&[s("noop_ready"), list(vec![]), list(vec![pair("done", vec![])]), list(vec![]), Value::Int(1)]).unwrap();
    let result = host_plan(&[list(vec![pair("done", vec![])])]).unwrap();
    match result {
        Value::List(steps) => assert_eq!(steps.len(), 1, "a zero-precond ground action should ground exactly once"),
        _ => panic!("expected List"),
    }
}

#[test]
fn a2_reports_unreachable_goal_as_empty_plan() {
    reset_world();
    host_action_add(&[s("noop"), list(vec![]), list(vec![pair("irrelevant", vec![])]), list(vec![]), Value::Int(1)]).unwrap();
    let result = host_plan(&[list(vec![pair("unreachable_goal", vec![])])]).unwrap();
    match result { Value::List(xs) => assert_eq!(xs.len(), 0), _ => panic!("expected List") }
}

#[test]
fn contract_check_success_records_a_queryable_fact() {
    reset_world();
    host_contract_check(&[s("half"), s("require"), s("n >= 0"), Value::Bool(true)]).unwrap();
    host_contract_check(&[s("half"), s("ensure"), s("r >= 0"), Value::Bool(true)]).unwrap();
    let sols = host_solve(&[s("contract_holds"), list(vec![s("half"), s("X")])]).unwrap();
    match sols { Value::List(xs) => assert_eq!(xs.len(), 2), _ => panic!("expected List") }
}

#[test]
fn contract_check_failure_aborts_and_records_nothing() {
    reset_world();
    let err = host_contract_check(&[s("half"), s("require"), s("n >= 0"), Value::Bool(false)]);
    assert!(err.is_err());
    let sols = host_solve(&[s("contract_holds"), list(vec![s("half"), s("X")])]).unwrap();
    match sols { Value::List(xs) => assert_eq!(xs.len(), 0), _ => panic!("expected List") }
}
