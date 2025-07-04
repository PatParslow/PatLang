//! Tests for ErrorHandler core module

use patlang_runtime::error_handler::{RuntimeError, RuntimeErrorKind};

#[test]
fn test_runtime_error_new() {
    let err = RuntimeError::new(RuntimeErrorKind::GoalSystem, "Goal error");
    assert_eq!(err.kind, RuntimeErrorKind::GoalSystem);
    assert_eq!(err.message, "Goal error");
    assert!(err.source.is_none());
}

#[test]
fn test_runtime_error_propagate() {
    let src = RuntimeError::new(RuntimeErrorKind::MemoryManager, "Alloc fail");
    let err = RuntimeError::propagate(RuntimeErrorKind::CoreEvaluator, "Eval fail", src.clone());
    assert_eq!(err.kind, RuntimeErrorKind::CoreEvaluator);
    assert_eq!(err.message, "Eval fail");
    assert!(err.source.is_some());
    assert_eq!(err.source.as_ref().unwrap().message, "Alloc fail");
}

#[test]
fn test_runtime_error_display() {
    let err = RuntimeError::new(RuntimeErrorKind::TypeSystem, "Type mismatch");
    let s = format!("{}", err);
    assert!(s.contains("TypeSystem"));
    assert!(s.contains("Type mismatch"));
}

#[test]
fn test_emit_event_stub() {
    let err = RuntimeError::new(RuntimeErrorKind::EventSystem, "Event error");
    err.emit_event(); // Should not panic (stub)
}