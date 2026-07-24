//! Cross-target and GUI-output tests for the self-hosted pipeline:
//! - WASM: the emitted Rust compiles unchanged to wasm32-wasip1 and runs
//!   under a WASI host (Node) with identical output
//! - HTML GUI: PatLang programs generate well-formed HTML+JS pages and can
//!   serve them (with live JSON data) over the tcp hosts

use std::cell::RefCell;

use patlang_runtime::parser::Parser as Stage0Parser;
use patlang_runtime::ir::{Interpreter, Lowerer, Value};
use patlang_runtime::ir::hosts::register_stage0_shims;

thread_local! {
    static PRINTED: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

/// Wraps a spawned `Child` so it's killed if this guard is dropped
/// without `.wait()` having already reaped it -- e.g. an `assert!`
/// between spawning a test server and the test's own final `child.wait()`
/// panics. Plain `std::process::Child` is NOT killed on drop (a well-known
/// std gotcha), so without this a panicking test leaks the server process,
/// which then holds its own .exe file locked on Windows and breaks the
/// NEXT run of the same test with an unrelated-looking compile/write
/// failure -- confirmed as a real, reproduced failure mode this session
/// (gui_server_serves_page_and_live_json), not a hypothetical concern.
struct KillOnDrop(Option<std::process::Child>);

impl KillOnDrop {
    fn new(child: std::process::Child) -> Self { Self(Some(child)) }
    fn wait(mut self) -> std::io::Result<std::process::ExitStatus> {
        self.0.take().expect("wait called once").wait()
    }
}

impl std::ops::Deref for KillOnDrop {
    type Target = std::process::Child;
    fn deref(&self) -> &Self::Target { self.0.as_ref().expect("not yet waited") }
}

impl std::ops::DerefMut for KillOnDrop {
    fn deref_mut(&mut self) -> &mut Self::Target { self.0.as_mut().expect("not yet waited") }
}

impl Drop for KillOnDrop {
    fn drop(&mut self) {
        if let Some(mut child) = self.0.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(v @ (Value::Int(_)|Value::Float(_)|Value::BigInt(_)|Value::Rational(_,_))) => patlang_runtime::ir::ops::v_to_string(v).into(),
        Some(Value::Bool(b)) => b.to_string().into(),
        _ => String::new().into(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s.to_string()));
    Ok(Value::Unit)
}

fn compiler_libs() -> String {
    let manifest = env!("CARGO_MANIFEST_DIR");
    let read = |rel: &str| std::fs::read_to_string(format!("{}/../self_hosting/{}", manifest, rel))
        .unwrap_or_else(|e| panic!("read {}: {}", rel, e));
    format!(
        "{}\n{}\n{}\n{}\n{}",
        read("lib/lexer.patlang"),
        read("lib/parser.patlang"),
        read("lib/lower.patlang"),
        read("lib/codegen.patlang"),
        read("lib/runtime_rs.patlang"),
    )
}

fn run_pipeline(driver: &str) -> Vec<String> {
    let full_src = format!("{}\n{}", compiler_libs(), driver);
    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("pipeline should run");
    PRINTED.with(|p| p.borrow().clone())
}

fn fwd(p: &std::path::Path) -> String { p.display().to_string().replace('\\', "/") }

#[test]
fn wasm_target_compiles_and_runs_feature_demo() {
    // Requires the wasm32-wasip1 std component; skip cleanly when absent
    let rustup = std::process::Command::new("rustup").args(["target", "list", "--installed"]).output();
    match &rustup {
        Ok(o) if String::from_utf8_lossy(&o.stdout).contains("wasm32-wasip1") => {}
        _ => { eprintln!("wasm32-wasip1 target not installed; skipping"); return; }
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let demo_path = format!("{}/../self_hosting/examples/feature_demo.patlang", manifest).replace('\\', "/");
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("wasm_target_compiles_and_runs_feature_demo");
    let _ = std::fs::create_dir_all(&out_dir);
    let wasm_path = out_dir.join("feature_demo.wasm");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let wasm = rustc_build(rs, \"{}\", \"wasm32-wasip1\")\n\
         print(\"WASM-OK\")\n",
        demo_path, fwd(&wasm_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "WASM-OK"), "wasm build did not complete: {:?}", lines);
    assert!(wasm_path.exists(), "wasm artifact missing");

    // Run under Node's WASI if node is available
    let node_ok = std::process::Command::new("node").arg("--version").output().is_ok();
    if !node_ok { eprintln!("node not found; wasm artifact built but not executed"); return; }
    let runner = out_dir.join("run_wasi.mjs");
    std::fs::write(&runner,
        "import { readFile } from 'node:fs/promises';\n\
         import { WASI } from 'node:wasi';\n\
         import { argv, env } from 'node:process';\n\
         const wasi = new WASI({ version: 'preview1', args: argv.slice(2), env });\n\
         const wasm = await WebAssembly.compile(await readFile(argv[2]));\n\
         const instance = await WebAssembly.instantiate(wasm, wasi.getImportObject());\n\
         wasi.start(instance);\n").expect("write wasi runner");
    let out = std::process::Command::new("node")
        .arg("--no-warnings").arg(&runner).arg(&wasm_path)
        .output().expect("run node wasi");
    assert!(out.status.success(), "wasm run failed: {}", String::from_utf8_lossy(&out.stderr));
    let stdout = String::from_utf8_lossy(&out.stdout);
    assert!(stdout.contains("fib(10) = 55") && stdout.contains("evens: [2, 4]"),
        "wasm output wrong: {}", stdout);
}

#[test]
fn gui_page_is_well_formed() {
    let manifest = env!("CARGO_MANIFEST_DIR");
    let read = |rel: &str| std::fs::read_to_string(format!("{}/../self_hosting/{}", manifest, rel)).expect("read");
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("gui_page_is_well_formed");
    let _ = std::fs::create_dir_all(&out_dir);

    // Run the GUI generator (html lib + demo) under the interpreter, with
    // cwd-relative output redirected into the temp dir
    let gui_src = format!("{}\n{}", read("lib/html.patlang"), read("examples/gui_demo.patlang"));
    let html_path = out_dir.join("gui_demo.html");
    let gui_src = gui_src.replace("write_file(\"gui_demo.html\"", &format!("write_file(\"{}\"", fwd(&html_path)));

    let mut parser = Stage0Parser::new(&gui_src).expect("lexer init");
    let ast = parser.parse().expect("gui source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    interp.run(&program).expect("gui demo should run");

    let html = std::fs::read_to_string(&html_path).expect("gui_demo.html written");
    assert!(html.starts_with("<!DOCTYPE html>"), "missing doctype");
    for needle in ["<html lang='en'>", "<meta charset='utf-8'>", "</head>", "<body>",
                   "<script>", "</script>", "</body>", "</html>", "const fib = [0, 1, 1, 2"] {
        assert!(html.contains(needle), "page missing {}: {}", needle, &html[..200.min(html.len())]);
    }
    // Balanced structural tags
    for tag in ["html", "head", "body", "script", "ul", "div"] {
        let opens = html.matches(&format!("<{}", tag)).count();
        let closes = html.matches(&format!("</{}>", tag)).count();
        assert!(opens >= closes && closes >= 1, "unbalanced <{}>: {} open / {} close", tag, opens, closes);
    }
}

#[test]
fn gui_server_serves_page_and_live_json() {
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping gui server test");
        return;
    }
    let manifest = env!("CARGO_MANIFEST_DIR");
    let read = |rel: &str| std::fs::read_to_string(format!("{}/../self_hosting/{}", manifest, rel)).expect("read");
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("gui_server_serves_page_and_live_json");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "gui_server.exe" } else { "gui_server" });

    // Compile (native) via the all-PatLang pipeline
    let program_src = format!("{}\n{}", read("lib/html.patlang"), read("examples/gui_server_demo.patlang"));
    let src_path = out_dir.join("gui_server_all.patlang");
    std::fs::write(&src_path, &program_src).expect("write combined gui server source");
    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        fwd(&src_path), fwd(&exe_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "COMPILED"), "gui server did not compile: {:?}", lines);

    // Spawn, read port, fetch page + data
    use std::io::{BufRead, BufReader, Read, Write};
    let mut child = KillOnDrop::new(std::process::Command::new(&exe_path)
        .stdout(std::process::Stdio::piped())
        .spawn().expect("spawn gui server"));
    let stdout = child.stdout.take().expect("child stdout");
    let mut reader = BufReader::new(stdout);
    let mut first = String::new();
    reader.read_line(&mut first).expect("read PORT line");
    let port: u16 = first.trim().strip_prefix("PORT: ").expect("PORT line").parse().expect("port");

    let get = |path: &str| -> String {
        let mut stream = std::net::TcpStream::connect(("127.0.0.1", port)).expect("connect");
        write!(stream, "GET {} HTTP/1.1\r\nHost: localhost\r\n\r\n", path).expect("send");
        let mut resp = String::new();
        stream.read_to_string(&mut resp).expect("read");
        resp
    };
    let page = get("/");
    assert!(page.contains("Content-Type: text/html"), "page content type: {}", &page[..80]);
    assert!(page.contains("<!DOCTYPE html>") && page.contains("fetch('/data')"), "page wrong");
    let data = get("/data");
    assert!(data.contains("Content-Type: application/json"), "data content type");
    assert!(data.contains("\"fib\": [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]"), "live data wrong: {}", data);
    let _ = get("/data"); // third request lets the server exit
    let status = child.wait().expect("server exit");
    assert!(status.success());
}

#[test]
fn stage1_escapes_and_short_circuit() {
    // String escapes decode in the Stage 1 lexer, and and/or short-circuit
    // in Stage-1-compiled code (missing_fn would error if evaluated)
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping");
        return;
    }
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("stage1_escapes_and_short_circuit");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "sc_test.exe" } else { "sc_test" });

    let program = "let x = false\n\
        if x and missing_fn(1) then\n  print(\"bad\")\nelse\n  print(\"and-sc\")\nend\n\
        if true or missing_fn(2) then\n  print(\"or-sc\")\nend\n\
        print(\"T[\t]Q[\\\"]N\")\n";
    let src_path = out_dir.join("sc_test.patlang");
    std::fs::write(&src_path, program).expect("write program");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        fwd(&src_path), fwd(&exe_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not compile: {:?}", lines);

    let out = std::process::Command::new(&exe_path).output().expect("run");
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("and-sc"), "and short-circuit: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("or-sc"), "or short-circuit: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("T[\t]Q[\"]N"), "escapes: {}", stdout);
}

#[test]
fn stage1_multiline_lists_and_calls() {
    // Regression: the Stage 1 self-hosted lexer emits an explicit NL token for
    // every newline (no bracket-depth suppression like the Stage 0 Rust
    // lexer), so list literals and call arguments spanning multiple lines
    // used to desugar into a parse Err silently swallowed as an empty
    // string/list. parser.patlang's list-literal and parse_args loops now
    // skip_nl around '[', ',', ']'/'(', ',', ')'.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping");
        return;
    }
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("stage1_multiline_lists_and_calls");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "ml_test.exe" } else { "ml_test" });

    let program = "let xs = [\n  1,\n  2,\n  3\n]\n\
        print(\"len: \" + xs.length)\n\
        make a function called add3 takes a, b, c returns r\n  return a + b + c\nend\n\
        print(\"sum: \" + add3(\n  1,\n  2,\n  3\n))\n";
    let src_path = out_dir.join("ml_test.patlang");
    std::fs::write(&src_path, program).expect("write program");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        fwd(&src_path), fwd(&exe_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not compile: {:?}", lines);

    let out = std::process::Command::new(&exe_path).output().expect("run");
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("len: 3"), "multi-line list: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("sum: 6"), "multi-line call args: {}", stdout);
}

#[test]
fn stage1_closures_native() {
    // Closures through the fully self-hosted pipeline (lexer, parser, lower,
    // codegen all PatLang), compiled to a native executable: basic capture,
    // a nested closure capturing its enclosing function's own parameter, and
    // a closure passed as a higher-order argument.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping");
        return;
    }
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("stage1_closures_native");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "closures_test.exe" } else { "closures_test" });

    let program = "let add_five = |x| do\n  return x + 5\nend\n\
        print(add_five(10))\n\n\
        make a function called make_adder takes n returns r\n\
          return |x| do\n    return x + n\n  end\n\
        end\n\
        let add_three = make_adder(3)\n\
        print(add_three(7))\n\n\
        make a function called twice takes f, x returns r\n\
          return f(f(x))\n\
        end\n\
        let inc = |x| do\n  return x + 1\nend\n\
        print(twice(inc, 10))\n";
    let src_path = out_dir.join("closures_test.patlang");
    std::fs::write(&src_path, program).expect("write program");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        fwd(&src_path), fwd(&exe_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not compile: {:?}", lines);

    let out = std::process::Command::new(&exe_path).output().expect("run");
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("15"), "basic closure: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("10"), "nested closure capturing outer param: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("12"), "closure as higher-order argument: {}", stdout);
}

#[test]
fn event_loop_closures_serve_and_stop() {
    // lib/event_loop.patlang: a JS-style event loop where callbacks are
    // ordinary closures (registered via event_loop_on_tick/event_loop_listen)
    // rather than the when/emit + set_var/get global-dispatch pattern. The
    // on_tick closure mutates shared state through the object store (captured
    // by name, so mutation is visible across calls despite closures snapshotting
    // captured values); on_request calls event_loop_stop(loop) from inside
    // itself once two requests are served, ending event_loop_run's while loop.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping event loop test");
        return;
    }
    let manifest = env!("CARGO_MANIFEST_DIR");
    let read = |rel: &str| std::fs::read_to_string(format!("{}/../self_hosting/{}", manifest, rel)).expect("read");
    let out_dir = std::env::temp_dir().join("patlang_targets_test").join("event_loop_closures_serve_and_stop");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "event_loop_demo.exe" } else { "event_loop_demo" });

    let program_src = format!("{}\n{}", read("lib/event_loop.patlang"), read("examples/event_loop_demo.patlang"));
    let src_path = out_dir.join("event_loop_all.patlang");
    std::fs::write(&src_path, &program_src).expect("write combined event loop source");
    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        fwd(&src_path), fwd(&exe_path)
    );
    let lines = run_pipeline(&driver);
    assert!(lines.iter().any(|l| l == "COMPILED"), "event loop demo did not compile: {:?}", lines);

    use std::io::{BufRead, BufReader, Read, Write};
    let mut child = KillOnDrop::new(std::process::Command::new(&exe_path)
        .stdout(std::process::Stdio::piped())
        .spawn().expect("spawn event loop demo"));
    let stdout = child.stdout.take().expect("child stdout");
    let mut reader = BufReader::new(stdout);
    let mut first = String::new();
    reader.read_line(&mut first).expect("read PORT line");
    let port: u16 = first.trim().strip_prefix("PORT: ").expect("PORT line").parse().expect("port");

    for path in ["/first", "/second"] {
        let mut stream = std::net::TcpStream::connect(("127.0.0.1", port)).expect("connect");
        write!(stream, "GET {} HTTP/1.1\r\nHost: localhost\r\n\r\n", path).expect("send");
        let mut resp = String::new();
        stream.read_to_string(&mut resp).expect("read");
        assert!(resp.starts_with("HTTP/1.1 200 OK"), "bad response: {}", resp);
        assert!(resp.contains(&format!("GET {} HTTP/1.1", path)), "echo missing: {}", resp);
    }

    let status = child.wait().expect("event loop demo exit");
    assert!(status.success(), "event loop demo exited with {:?}", status);
}
