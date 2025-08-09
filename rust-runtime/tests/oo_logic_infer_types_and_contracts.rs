use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn oo_logic_infer_types_and_contracts() {
    let src = include_str!("../examples/oo_logic_infer_types_and_contracts.patlang");
    let result = evaluate_patlang_source(src).expect("evaluation should succeed");

    // Last print
    assert_eq!(result.message.trim(), "ok");

    // Two queries captured -> bob then carol inferred as X
    assert_eq!(result.query_results.len(), 2);
    assert_eq!(result.query_results[0].len(), 1);
    assert_eq!(result.query_results[0][0].0, "X");
    assert_eq!(result.query_results[0][0].1, "bob");
    assert_eq!(result.query_results[1].len(), 1);
    assert_eq!(result.query_results[1][0].0, "X");
    assert_eq!(result.query_results[1][0].1, "carol");

    // Objects snapshot should contain alice, bob, carol and types inferred
    let mut seen = 0;
    let mut bob_age: Option<String> = None;
    let mut carol_age: Option<String> = None;
    for (name, props) in result.objects.iter() {
        if name == "alice" || name == "bob" || name == "carol" {
            seen += 1;
            assert!(props.iter().any(|(k, v)| k == "type" && v == "Person"));
            assert!(props.iter().any(|(k, v)| k == "name" && v == name));
        }
        if name == "bob" {
            bob_age = props.iter().find(|(k, _)| k == "age").map(|(_, v)| v.clone());
        }
        if name == "carol" {
            carol_age = props.iter().find(|(k, _)| k == "age").map(|(_, v)| v.clone());
        }
    }
    assert_eq!(seen, 3);

    // Contract enforcement: the bad set should not overwrite bob's numeric age
    assert_eq!(bob_age.as_deref(), Some("20"));
    assert_eq!(carol_age.as_deref(), Some("55"));
}
