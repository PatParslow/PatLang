use patlang_runtime::function::{FunctionDef, call_function};

#[test]
fn test_call_function_basic() {
    let def = FunctionDef {
        name: "foo".to_string(),
        params: vec!["a".to_string(), "b".to_string()],
    };
    let result = call_function(&def, vec!["1".to_string(), "2".to_string()]);
    assert!(result.contains("foo"));
    assert!(result.contains("1"));
    assert!(result.contains("2"));
}

#[test]
fn test_call_function_empty_args() {
    let def = FunctionDef {
        name: "bar".to_string(),
        params: vec![],
    };
    let result = call_function(&def, vec![]);
    assert!(result.contains("bar"));
    assert!(result.contains("[]"));
}