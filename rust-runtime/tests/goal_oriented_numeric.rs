// PDDL 2.1-style numeric fluents for the GOAP planner -- additive
// alongside the existing propositional fact machinery (see
// goal_oriented_logic.rs's own tests for that). Exercised directly
// against the host functions for precise assertions, same convention.
use patlang_runtime::ir::hosts::{host_action_add_numeric, host_fluent_set, host_plan_numeric, reset_world};
use patlang_runtime::ir::types::Value;

fn s(x: &str) -> Value { Value::String(x.to_string().into()) }
fn i(n: i64) -> Value { Value::Int(n) }
fn list(xs: Vec<Value>) -> Value { Value::List(std::sync::Arc::new(xs)) }
fn triple(a: &str, op: &str, b: &str) -> Value { list(vec![s(a), s(op), s(b)]) }

#[test]
fn numeric_countdown_discovered_without_any_preenumerated_fact_table() {
    reset_world();
    // The exact capability gap this closes: earlier this session, a
    // "count down to zero" domain only worked via a pre-enumerated
    // dec(3,2)/dec(2,1)/dec(1,0) ground-fact table, since the planner
    // does pure fact unification with no arithmetic anywhere. Here,
    // chop_wood's numeric precondition/effect are genuine arithmetic
    // -- no fact table, no propositional preconditions at all.
    host_fluent_set(&[s("count"), i(3)]).unwrap();
    host_action_add_numeric(&[
        s("chop_wood"),
        list(vec![]),                              // preconds (propositional)
        list(vec![triple("count", ">=", "1")]),     // numeric_preconds
        list(vec![]),                               // add_effects
        list(vec![]),                               // del_effects
        list(vec![triple("count", "-=", "1")]),     // numeric_effects
        i(1),
    ]).unwrap();

    let result = host_plan_numeric(&[list(vec![]), list(vec![triple("count", "==", "0")])]).unwrap();
    match result {
        Value::List(steps) => {
            assert_eq!(steps.len(), 3, "should discover a genuine 3-step repeated-action plan, one per decrement");
            for step in steps.iter() {
                match step { Value::String(name) => assert_eq!(name.as_ref(), "chop_wood"), _ => panic!("expected String") }
            }
        }
        _ => panic!("expected List"),
    }
}

#[test]
fn numeric_inequality_goal_is_genuinely_expressible() {
    reset_world();
    // A goal like "count <= 0" (reached by counting down from ABOVE
    // zero) is provably inexpressible via the old fact-table approach
    // -- that can only ever match one exact literal value (count(0)),
    // never a range/inequality. This is the concrete capability the
    // pre-enumerated-fact-table design could never offer at all.
    host_fluent_set(&[s("count"), i(5)]).unwrap();
    host_action_add_numeric(&[
        s("chop_wood"),
        list(vec![]),
        list(vec![triple("count", ">", "0")]),
        list(vec![]),
        list(vec![]),
        list(vec![triple("count", "-=", "2")]),
        i(1),
    ]).unwrap();

    // 5 -> 3 -> 1 -> -1 : three steps needed to cross below zero.
    let result = host_plan_numeric(&[list(vec![]), list(vec![triple("count", "<=", "0")])]).unwrap();
    match result {
        Value::List(steps) => assert_eq!(steps.len(), 3, "should reach count<=0 by crossing below zero, not requiring an exact-zero landing"),
        _ => panic!("expected List"),
    }
}

#[test]
fn numeric_precondition_correctly_gates_action_applicability() {
    reset_world();
    // A numeric precondition genuinely blocks an action whose fluent
    // doesn't satisfy it -- not treated as automatically passing.
    host_fluent_set(&[s("count"), i(0)]).unwrap();
    host_action_add_numeric(&[
        s("chop_wood"),
        list(vec![]),
        list(vec![triple("count", ">=", "1")]),
        list(vec![]),
        list(vec![]),
        list(vec![triple("count", "-=", "1")]),
        i(1),
    ]).unwrap();

    // count already at 0 -- chop_wood's own precondition (count >= 1)
    // never holds, so no plan should be found at all.
    let result = host_plan_numeric(&[list(vec![]), list(vec![triple("count", "==", "-5")])]).unwrap();
    match result {
        Value::List(steps) => assert_eq!(steps.len(), 0, "chop_wood's numeric precondition should block it entirely, not silently pass"),
        _ => panic!("expected List"),
    }
}

#[test]
fn missing_fluent_fails_a_numeric_precondition_rather_than_silently_passing() {
    reset_world();
    // No fluent_set call at all for "count" -- a numeric precondition
    // referencing an unset fluent must fail closed, never treated as
    // "any value satisfies this."
    host_action_add_numeric(&[
        s("chop_wood"),
        list(vec![]),
        list(vec![triple("count", ">=", "1")]),
        list(vec![]),
        list(vec![]),
        list(vec![]),
        i(1),
    ]).unwrap();

    let result = host_plan_numeric(&[list(vec![]), list(vec![triple("count", "==", "0")])]).unwrap();
    match result {
        Value::List(steps) => assert_eq!(steps.len(), 0, "an unset fluent should never satisfy a numeric precondition"),
        _ => panic!("expected List"),
    }
}
