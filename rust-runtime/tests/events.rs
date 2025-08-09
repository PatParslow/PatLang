use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn when_handler_runs_on_emit() {
    // Define a simple program: register when foo { print("ok") } then emit("foo")
    let src = r#"
when foo {
  print("ok")
}

emit("foo")
"#;
    let result = evaluate_patlang_source(src).expect("evaluation should succeed");
    assert_eq!(result.message.trim(), "ok");
}
