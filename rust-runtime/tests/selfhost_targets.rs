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

fn capture_print(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() },
        Some(Value::Bool(b)) => b.to_string(),
        _ => String::new(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s));
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
    let out_dir = std::env::temp_dir().join("patlang_targets_test");
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
    let out_dir = std::env::temp_dir().join("patlang_targets_test");
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
    let out_dir = std::env::temp_dir().join("patlang_targets_test");
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
    let mut child = std::process::Command::new(&exe_path)
        .stdout(std::process::Stdio::piped())
        .spawn().expect("spawn gui server");
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
