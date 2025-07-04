//! Tests for TypeSystem core module

use patlang_runtime::type_system::{TypeSystem, Type, TypedValue};

fn make_typed_value<T: 'static + Send + Sync>(val: T, ty: Type) -> TypedValue {
    TypedValue {
        value: Box::new(val),
        ty,
    }
}

#[test]
fn test_type_registration_and_check() {
    let mut ts = TypeSystem::new();
    ts.register_custom_type("MyType");
    assert_eq!(ts.custom_types().get("MyType"), Some(&Type::Custom("MyType".to_string())));
}

#[test]
fn test_check_type_success() {
    let ts = TypeSystem::new();
    let val = make_typed_value(42, Type::Int);
    assert!(ts.check_type(val, &Type::Int).is_ok());
}

#[test]
fn test_check_type_failure() {
    let ts = TypeSystem::new();
    let val = make_typed_value(42, Type::Int);
    let result = ts.check_type(val, &Type::Float);
    assert!(result.is_err());
}

#[test]
fn test_unknown_type() {
    let ts = TypeSystem::new();
    let val = make_typed_value("abc", Type::Unknown);
    let result = ts.check_type(val, &Type::String);
    assert!(result.is_err());
}