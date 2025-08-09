use patlang_runtime::string::{eval_string, StringOp};

#[test]
fn test_concat() {
    let result = eval_string(StringOp::Concat, "foo", Some("bar"));
    assert_eq!(result, "foobar");
}

#[test]
fn test_concat_none() {
    let result = eval_string(StringOp::Concat, "foo", None);
    assert_eq!(result, "foo");
}

#[test]
fn test_length() {
    let result = eval_string(StringOp::Length, "hello", None);
    assert_eq!(result, "5");
}

#[test]
fn test_length_empty() {
    let result = eval_string(StringOp::Length, "", None);
    assert_eq!(result, "0");
}