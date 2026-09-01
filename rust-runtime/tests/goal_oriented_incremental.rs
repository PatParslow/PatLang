// plan_incremental (GitHub issue #71 follow-up): a caller that registers
// actions in growing batches and asks "reachable yet?" after each batch
// should get the SAME answers plan() would give at each point, while
// reusing search work across calls instead of re-solving from scratch.
// action_clear() must fully reset the incremental cache too, since it
// invalidates the "actions only ever grow" assumption the cache relies on.
use patlang_runtime::ir::hosts::{host_action_add, host_action_clear, host_plan_incremental, reset_world};
use patlang_runtime::ir::types::Value;

fn s(x: &str) -> Value { Value::String(x.to_string().into()) }
fn list(xs: Vec<Value>) -> Value { Value::List(std::sync::Arc::new(xs)) }
fn pair(pred: &str, args: Vec<Value>) -> Value { list(vec![s(pred), list(args)]) }
fn action(name: &str, preconds: Vec<Value>, add_effects: Vec<Value>, cost: i64) {
    host_action_add(&[s(name), list(preconds), list(add_effects), list(vec![]), Value::Int(cost)]).unwrap();
}
fn plan_len(goal: Vec<Value>) -> usize {
    match host_plan_incremental(&[list(goal)]).unwrap() { Value::List(xs) => xs.len(), _ => panic!("expected List") }
}

#[test]
fn incremental_plan_finds_goal_only_once_a_later_batch_enables_it() {
    reset_world();
    action("step_a", vec![], vec![pair("has", vec![s("a"), s("1")])], 1);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 0, "no route to b yet");

    action("step_b_from_a", vec![pair("has", vec![s("a"), s("1")])], vec![pair("has", vec![s("b"), s("1")])], 1);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 2, "b now reachable via a, cost 2");
}

#[test]
fn incremental_plan_keeps_the_cheaper_cached_route_when_a_pricier_one_is_added_later() {
    reset_world();
    action("step_a", vec![], vec![pair("has", vec![s("a"), s("1")])], 1);
    action("step_b_from_a", vec![pair("has", vec![s("a"), s("1")])], vec![pair("has", vec![s("b"), s("1")])], 1);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 2);

    // A pricier direct route shouldn't displace the already-cached
    // cheaper one.
    action("step_b_direct", vec![], vec![pair("has", vec![s("b"), s("1")])], 5);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 2, "cheaper cached route unaffected");
}

#[test]
fn incremental_plan_finds_a_new_route_added_after_the_first_solve_for_a_different_goal() {
    reset_world();
    action("step_a", vec![], vec![pair("has", vec![s("a"), s("1")])], 1);
    action("step_b_from_a", vec![pair("has", vec![s("a"), s("1")])], vec![pair("has", vec![s("b"), s("1")])], 1);
    plan_len(vec![pair("has", vec![s("b"), s("1")])]);

    // A genuinely different goal (both facts at once) forces a fresh
    // cache entry and must still find the right (only valid) route.
    assert_eq!(plan_len(vec![pair("has", vec![s("a"), s("1")]), pair("has", vec![s("b"), s("1")])]), 2);
}

#[test]
fn action_clear_resets_the_incremental_cache_not_just_the_action_list() {
    reset_world();
    action("step_a", vec![], vec![pair("has", vec![s("a"), s("1")])], 1);
    action("step_b", vec![pair("has", vec![s("a"), s("1")])], vec![pair("has", vec![s("b"), s("1")])], 1);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 2);

    host_action_clear(&[]).unwrap();
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 0, "actions gone, cached path must not survive");

    action("step_b_direct", vec![], vec![pair("has", vec![s("b"), s("1")])], 3);
    assert_eq!(plan_len(vec![pair("has", vec![s("b"), s("1")])]), 1, "finds the fresh route after clear, not a stale cached one");
}
