use patlang_runtime::core_evaluator::evaluate_patlang_source;
use patlang_runtime::ir::{Lowerer, Interpreter, Value, RustCodegen};

#[test]
fn interpreter_event_payload_available() {
    let src = r##"
when foo {
  print("#{event_data}")
}

emit("foo", "PAYLOAD")
"##;
    let result = evaluate_patlang_source(src).expect("evaluation should succeed");
    assert_eq!(result.message.trim(), "PAYLOAD");
}

#[test]
fn ir_interpreter_event_payload_passed() {
    // `when` blocks now lower to a genuine closure (lowering.rs's
    // lower_when), registered at RUNTIME via register_event_handler
    // rather than a bare function name in program.event_handlers -- so
    // this test can no longer look the handler up by name from outside
    // (there's no static registry entry to find it through). Verifies
    // the same real thing the old version did (event_data genuinely
    // reaches the handler) by observing actual output instead of poking
    // Program internals directly, matching
    // interpreter_event_payload_available just above.
    use std::cell::RefCell;
    thread_local! { static CAPTURED: RefCell<Vec<String>> = RefCell::new(Vec::new()); }
    fn capture_print(args: &[Value]) -> Result<Value, String> {
        let s = match args.get(0) { Some(Value::String(s)) => s.to_string(), _ => String::new() };
        CAPTURED.with(|c| c.borrow_mut().push(s));
        Ok(Value::Unit)
    }

    let src = r#"
when foo {
  print(event_data)
}

emit("foo", "P")
"#;
    use patlang_runtime::parser::Parser;
    let mut parser = Parser::new(src).unwrap();
    let ast = parser.parse().unwrap();
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    patlang_runtime::ir::hosts::reset_world();
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    patlang_runtime::ir::hosts::register_stage0_shims(&mut interp);
    interp.run(&program).expect("program should run without error");

    CAPTURED.with(|c| assert_eq!(c.borrow().as_slice(), ["P"]));
}

#[test]
fn codegen_emit_payload_passed() {
    // Construct AST for: when foo { print("ok") } emit("foo", "X"). `when`
    // blocks now lower to a genuine closure registered at runtime via
    // register_event_handler (lowering.rs's lower_when) rather than a
    // bare function name -- this checks the generated Rust text reflects
    // that (both the registration call and emit's real dispatch), the
    // same shallow-but-real sanity check the original version did for
    // the older static-registration shape.
    let src = r#"
when foo {
  print("ok")
}

emit("foo", "X")
"#;
    use patlang_runtime::parser::Parser;
    let mut parser = Parser::new(src).unwrap();
    let ast = parser.parse().unwrap();
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let cg = RustCodegen::new();
    let rust_src = cg.emit_rust(&program);
    assert!(rust_src.contains("CallHost(\"emit\""));
    assert!(rust_src.contains("CallHost(\"register_event_handler\""));
}
