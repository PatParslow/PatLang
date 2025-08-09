use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn oo_logic_goals_person_end_to_end() {
    let src = include_str!("../examples/oo_logic_goals_person.patlang");
    let result = evaluate_patlang_source(src).expect("evaluation should succeed");

    // Last print
    assert_eq!(result.message.trim(), "ready");

    // Two queries captured
    assert_eq!(result.query_results.len(), 2);
    assert_eq!(result.query_results[0].len(), 1);
    assert_eq!(result.query_results[0][0].0, "X");
    assert_eq!(result.query_results[0][0].1, "bob");
    assert_eq!(result.query_results[1].len(), 1);
    assert_eq!(result.query_results[1][0].0, "X");
    assert_eq!(result.query_results[1][0].1, "carol");

    // Objects snapshot contains at least alice, bob, carol, with properties
    let mut found = 0;
    for (name, props) in result.objects.iter() {
        if name == "alice" || name == "bob" || name == "carol" {
            found += 1;
            // has type and name
            assert!(props.iter().any(|(k, v)| k == "type" && v == "Person"));
            assert!(props.iter().any(|(k, v)| k == "name" && v == name));
            // age known
            assert!(props.iter().any(|(k, _)| k == "age"));
        }
        if name == "bob" || name == "carol" {
            // infer_relations sets has_parent true when a parent fact exists
            assert!(props.iter().any(|(k, v)| k == "has_parent" && v == "true"));
        }
        if name == "alice" || name == "carol" {
            // adults inferred
            assert!(props.iter().any(|(k, v)| k == "is_adult" && v == "true"));
        }
        if name == "bob" {
            // bob is not adult
            assert!(!props.iter().any(|(k, v)| k == "is_adult" && v == "true"));
        }
    }
    assert_eq!(found, 3);

    // Goals captured
    assert_eq!(result.goals.len(), 2);
    assert_eq!(result.goals[0].0, "ancestor");
    assert_eq!(result.goals[0].1, vec!["alice".to_string(), "carol".to_string()]);
    assert_eq!(result.goals[1].0, "ancestor");
    assert_eq!(result.goals[1].1, vec!["bob".to_string(), "carol".to_string()]);
}
