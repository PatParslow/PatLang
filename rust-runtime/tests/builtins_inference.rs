use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn test_infer_is_adult_true_and_false() {
    let src = r#"
alice = new("Person", "alice")
alice.set("age", "21")
print(alice.infer_is_adult())
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert_eq!(res.message, "true");

    let src2 = r#"
bob = new("Person", "bob")
bob.set("age", "16")
print(bob.infer_is_adult())
"#;
    let res2 = evaluate_patlang_source(src2).expect("ok");
    assert_eq!(res2.message, "false");
}

#[test]
fn test_infer_relations_no_parent() {
    let src = r#"
child = new("Person", "child")
print(child.infer_relations())
"#;
    let res = evaluate_patlang_source(src).expect("ok");
    assert_eq!(res.message, "false");
}
