//! Regression test for tcp_connect (the client-side counterpart to
//! tcp_listen/tcp_accept, added for the Ollama chat CLI example). Loopback
//! only, no external dependency: connect() completes once the OS queues the
//! pending connection, so listen -> connect -> accept in that order (all
//! single-threaded) doesn't deadlock.

use patlang_runtime::parser::Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;
use std::cell::RefCell;

thread_local! {
    static OUTPUT: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    if let Some(v) = args.get(0) {
        let s = match v { Value::String(s) => s.clone(), other => format!("{:?}", other) };
        OUTPUT.with(|o| o.borrow_mut().push(s));
    }
    Ok(Value::Unit)
}

fn run(src: &str) -> Result<Vec<String>, String> {
    OUTPUT.with(|o| o.borrow_mut().clear());
    let mut parser = Parser::new(src).map_err(|e| format!("{:?}", e))?;
    let ast = parser.parse().map_err(|e| format!("{:?}", e))?;
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    interp.run(&program).map_err(|e| format!("{:?}", e))?;
    Ok(OUTPUT.with(|o| o.borrow().clone()))
}

#[test]
fn tcp_connect_round_trips_with_listen_and_accept() {
    let src = r#"
let port = tcp_listen(0)
let client = tcp_connect("127.0.0.1", port)
let server = tcp_accept(port)
tcp_write(client, "hello from client")
let got = tcp_read(server)
print(got)
tcp_write(server, "hello from server")
let reply = tcp_read(client)
print(reply)
tcp_close(client)
tcp_close(server)
"#;
    let out = run(src).expect("tcp_connect round-trip should succeed");
    assert_eq!(out, vec!["hello from client", "hello from server"]);
}

#[test]
fn tcp_connect_to_nothing_listening_errors() {
    let src = r#"
let conn = tcp_connect("127.0.0.1", 1)
"#;
    // Port 1 is a privileged/unused port with nothing listening; connect
    // should fail with a host error rather than hang or panic.
    assert!(run(src).is_err());
}

#[test]
fn byte_length_counts_utf8_bytes_not_chars() {
    // chr(233) builds the single Unicode character U+00E9 (e-acute), which
    // is 1 char but 2 UTF-8 bytes when the string is encoded - a controlled
    // way to get a known multi-byte character without depending on how this
    // source file's own literal text happens to be encoded/normalized.
    let src = r#"
print("" + byte_length("abc"))
let e_acute = chr(233)
print("" + byte_length("caf" + e_acute))
print("" + ("caf" + e_acute).length)
"#;
    let out = run(src).expect("byte_length should run");
    assert_eq!(out[0], "3");
    assert_eq!(out[1], "5", "caf (3 bytes) + 2-byte accented char = 5 bytes");
    assert_eq!(out[2], "4", ".length counts chars: caf + 1 char = 4");
}
