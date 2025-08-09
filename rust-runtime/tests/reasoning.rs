use patlang_runtime::reasoning::{eval_reasoning, ReasoningOp};

#[test]
fn test_unify() {
    let result = eval_reasoning(ReasoningOp::Unify, "x = y");
    assert!(result.contains("Unify"));
    assert!(result.contains("x = y"));
}

#[test]
fn test_infer() {
    let result = eval_reasoning(ReasoningOp::Infer, "type(x)");
    assert!(result.contains("Infer"));
    assert!(result.contains("type(x)"));
}

#[test]
fn test_empty_input() {
    let result = eval_reasoning(ReasoningOp::Unify, "");
    assert!(result.contains("Unify"));
    assert!(result.contains("input"));
}