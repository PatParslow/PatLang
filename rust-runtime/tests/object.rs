use patlang_runtime::object::Object;

#[test]
fn test_object_new() {
    let obj = Object::new("TestClass");
    assert_eq!(obj.class_name, "TestClass");
}

#[test]
fn test_object_new_empty_class() {
    let obj = Object::new("");
    assert_eq!(obj.class_name, "");
}