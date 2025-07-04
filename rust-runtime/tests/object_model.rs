//! Tests for ObjectModel core module

use patlang_runtime::object_model::{Object, Value, ObjectError};

fn dummy_method(_obj: &mut Object, args: Vec<Value>) -> Result<Value, ObjectError> {
    if let Some(Value::Int(x)) = args.get(0) {
        Ok(Value::Int(x + 1))
    } else {
        Err(ObjectError { message: "Invalid argument".to_string() })
    }
}

#[test]
fn test_object_creation_and_properties() {
    let mut obj = Object::new("TestClass");
    assert_eq!(obj.class_name, "TestClass");
    obj.set_property("foo", Value::Int(123));
    if let Some(val) = obj.get_property("foo") {
        assert!(matches!(val, Value::Int(123)));
    } else {
        panic!("Property 'foo' not found");
    }
    assert!(obj.get_property("bar").is_none());
}

#[test]
fn test_method_registration_and_call() {
    let mut obj = Object::new("TestClass");
    obj.add_method("inc", dummy_method);
    let result = obj.call_method("inc", vec![Value::Int(10)]).unwrap();
    assert!(matches!(result, Value::Int(11)));
}

#[test]
fn test_method_call_error() {
    let mut obj = Object::new("TestClass");
    let err = obj.call_method("missing", vec![]).unwrap_err();
    assert!(err.message.contains("not found") || err.message.contains("Missing"));
}