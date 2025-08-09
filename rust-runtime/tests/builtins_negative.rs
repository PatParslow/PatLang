use patlang_runtime::core_evaluator::evaluate_patlang_source;

// Cover branches in builtins where wrong arity or empty inputs are handled without panicking.
#[test]
fn test_builtins_handle_invalid_arity_gracefully() {
    let src = r#"
# wrong arity for set_var, infer_type_for, new, contract, person, goal, fact, query
set_var("x")
infer_type_for("p", 0)
new("ClassOnly")
contract()
person()
goal()
fact("pred", "a")
query("pred", "a")
print("done")
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert_eq!(res.message, "done");
}

// Cover object method branches for lists and objects: add/concat/get with missing inputs
#[test]
fn test_method_add_concat_get_edge_cases() {
    let src = r#"
list = list_new()
# add to list works
list.add("a")
# concat with non-existent list id should be no-op
list.concat("__no_such_list")
# get on object without property returns empty string
obj = new("Thing", "t1")
print(obj.get("missing"))
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert_eq!(res.message, "");
}
