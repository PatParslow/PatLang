//! Tests for closures, lists, dotted resolution, and lexical scoping

use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn test_any_over_list_of_objects() {
    let src = r#"
        let t1 = Thing.new("t1")
        t1.set("age", "20")
        let t2 = Thing.new("t2")
        t2.set("age", "30")
        let lst = ["t1", "t2"]
        print(lst.any?(|p| { p.age == "30" }))
    "#;
    let res = evaluate_patlang_source(src).expect("program should evaluate");
    assert_eq!(res.message.trim(), "true");
}

#[test]
fn test_closure_param_scoping_shadow_does_not_leak() {
    let src = r#"
        let x = "outer"
        let lst = ["a"]
        lst.each(|x| { x })
        print(x)
    "#;
    let res = evaluate_patlang_source(src).expect("program should evaluate");
    assert_eq!(res.message.trim(), "outer");
}
