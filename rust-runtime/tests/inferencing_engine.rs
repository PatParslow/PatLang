//! Tests for InferencingEngine core module

use patlang_runtime::inferencing_engine::{InferencingEngine, Term, Goal, InferenceResult, UnificationResult};

#[test]
fn test_inferencing_engine_new() {
    let engine = InferencingEngine::new();
    assert!(engine.evaluator.is_none());
    assert!(engine.goal_system.is_none());
}

#[test]
fn test_unify_success_and_failure() {
    let engine = InferencingEngine::new();
    let a = Term::Int(1);
    let b = Term::Int(1);
    let c = Term::Int(2);
    assert!(engine.unify(&a, &b).is_success());
    assert!(engine.unify(&a, &c).is_failure());
}

#[test]
fn test_distributed_reason_not_implemented() {
    let engine = InferencingEngine::new();
    let goal = Goal::default();
    let result = engine.distributed_reason(&goal);
    assert!(result.is_not_implemented());
}