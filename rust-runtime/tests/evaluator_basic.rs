//! Basic tests for Patlang Rust evaluator

use rust_runtime::core_evaluator::{AstKind, AstNode, CoreEvaluator};

#[test]
fn test_arithmetic_add() {
    let left = AstNode { kind: AstKind::Number(2.0), children: vec![] };
    let right = AstNode { kind: AstKind::Number(3.0), children: vec![] };
    let node = AstNode {
        kind: AstKind::BinaryOp {
            op: rust_runtime::arithmetic::ArithmeticOp::Add,
            left: Box::new(left),
            right: Box::new(right),
        },
        children: vec![],
    };
    let mut evaluator = CoreEvaluator::new(None, None, None, None, None);
    let result = evaluator.execute_node(&node);
    assert!(result.is_ok());
}

#[test]
fn test_string_concat() {
    let left = AstNode { kind: AstKind::String("foo".to_string()), children: vec![] };
    let right = AstNode { kind: AstKind::String("bar".to_string()), children: vec![] };
    let node = AstNode {
        kind: AstKind::StringOp {
            op: rust_runtime::string::StringOp::Concat,
            left: Box::new(left),
            right: Some(Box::new(right)),
        },
        children: vec![],
    };
    let mut evaluator = CoreEvaluator::new(None, None, None, None, None);
    let result = evaluator.execute_node(&node);
    assert!(result.is_ok());
}