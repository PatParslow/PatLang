use patlang_runtime::core_evaluator::evaluate_patlang_source;
use std::fs;

fn read(path: &str) -> String { fs::read_to_string(path).expect("read file") }

#[test]
fn native_sources_parse_without_error() {
    for path in [
        "../native_lexer/native_lexer.patlang",
        "../native_parser/native_parser.patlang",
        "../native_evaluator/core_evaluator.patlang",
    ] {
        let src = read(&format!("{}/{}", env!("CARGO_MANIFEST_DIR"), path));
        let res = evaluate_patlang_source(&src);
        assert!(res.is_ok(), "{} should parse/evaluate without fatal error: {:?}", path, res.err());
    }
}

#[test]
fn bootstrap_tiny_program_end_to_end_smoke() {
    // Tiny program: show arithmetic and print. The native sources currently serve mostly as
    // parser/evaluator definitions; here we just assert our evaluator can handle a tiny program.
    let tiny = r#"
1 + 2
print "ok"
"#;
    let res = evaluate_patlang_source(tiny);
    assert!(res.is_ok(), "tiny program should evaluate: {:?}", res);
    let msg = res.unwrap().message;
    assert_eq!(msg, "ok");
}
