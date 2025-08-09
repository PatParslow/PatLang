use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn oo_logic_mix_example_runs() {
    // Load the embedded example source and evaluate via the core evaluator
    let src = include_str!("../examples/oo_logic_mix.patlang");
    let result = evaluate_patlang_source(src).expect("evaluation should succeed");

    // Last print("done") should be reflected in message
    assert_eq!(result.message.trim(), "done");

    // Evaluator should have collected query results for the 2 queries
    assert_eq!(result.query_results.len(), 2);
    // Each query should yield exactly one substitution mapping X -> value
    let q1 = &result.query_results[0];
    assert_eq!(q1.len(), 1);
    assert_eq!(q1[0].0, "X");
    assert_eq!(q1[0].1, "bob");

    let q2 = &result.query_results[1];
    assert_eq!(q2.len(), 1);
    assert_eq!(q2[0].0, "X");
    assert_eq!(q2[0].1, "carol");
}
