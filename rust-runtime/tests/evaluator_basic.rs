use patlang_runtime::core_evaluator;

#[test]
fn test_simple_assignment() {
    let src = "x = 1";
    let result = core_evaluator::evaluate_patlang_source(src);
    assert!(result.is_ok());
}

#[test]
fn test_simple_expression() {
    let src = "y = 2 + 3";
    let result = core_evaluator::evaluate_patlang_source(src);
    assert!(result.is_ok());
}

#[test]
fn test_function_definition_and_call() {
    let src = r#"
        fn add(a, b) { a + b }
        result = add(2, 3)
    "#;
    let result = core_evaluator::evaluate_patlang_source(src);
    assert!(result.is_ok());
}