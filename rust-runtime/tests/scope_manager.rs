//! Tests for ScopeManager and Scope core module

use patlang_runtime::scope_manager::{Scope, ScopeValue};

#[test]
fn test_scope_bind_and_lookup() {
    let mut scope = Scope::new();
    scope.bind("x", ScopeValue::Int(42));
    assert_eq!(scope.lookup("x"), Some(&ScopeValue::Int(42)));
    assert_eq!(scope.lookup("y"), None);
}

#[test]
fn test_scope_chain_lookup() {
    let mut root = Scope::new();
    root.bind("a", ScopeValue::Str("root".to_string()));
    let mut child = root.child();
    child.bind("b", ScopeValue::Bool(true));
    // Child can see its own and parent's bindings
    assert_eq!(child.lookup("b"), Some(&ScopeValue::Bool(true)));
    assert_eq!(child.lookup("a"), Some(&ScopeValue::Str("root".to_string())));
    // Parent cannot see child's bindings
    assert_eq!(root.lookup("b"), None);
}

#[test]
fn test_scope_shadowing() {
    let mut root = Scope::new();
    root.bind("var", ScopeValue::Int(1));
    let mut child = root.child();
    child.bind("var", ScopeValue::Int(2));
    assert_eq!(child.lookup("var"), Some(&ScopeValue::Int(2)));
}