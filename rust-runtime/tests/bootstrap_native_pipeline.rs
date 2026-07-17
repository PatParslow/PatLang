use patlang_runtime::core_evaluator::evaluate_patlang_source;

#[test]
fn bootstrap_tiny_program_end_to_end_smoke() {
    // Tiny program: show arithmetic and print. Exercises core_evaluator's
    // fallback evaluation path (used by `pat` when run without --ir-run/--patc).
    let tiny = r#"
1 + 2
print "ok"
"#;
    let res = evaluate_patlang_source(tiny);
    assert!(res.is_ok(), "tiny program should evaluate: {:?}", res);
    let msg = res.unwrap().message;
    assert_eq!(msg, "ok");
}
