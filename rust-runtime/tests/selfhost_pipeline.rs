//! Regression test for the Stage 1 self-hosting pipeline:
//! PatLang-written lexer + parser (self_hosting/lib) run under the Stage 0 IR
//! interpreter, produce a list-shaped AST for a small program, and
//! compile_shape lowers + compiles it to a native executable whose output is
//! verified.

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
/// (an identically-shaped test in selfhost_targets.rs).
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
        Some(v @ (Value::Int(_)|Value::Float(_)|Value::BigInt(_)|Value::Rational(_,_))) => patlang_runtime::ir::ops::v_to_string(v),
        Some(Value::Bool(b)) => b.to_string(),
        _ => String::new(),
    };
    PRINTED.with(|p| p.borrow_mut().push(s));
    Ok(Value::Unit)
}

#[test]
fn selfhost_pipeline_compiles_feature_demo() {
    // Full feature matrix through the PatLang front-end: functions/recursion,
    // if/while, lists/index/member, events (when/emit), logic (fact/query),
    // OO (new/send/get) — compiled natively and output-verified.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping feature demo test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");
    let demo_path = format!("{}/../self_hosting/examples/feature_demo.patlang", manifest).replace('\\', "/");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test").join("selfhost_pipeline_compiles_feature_demo");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "feature_demo.exe" } else { "feature_demo" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let exe = compile_shape(ast, \"{}\")\n\
         print(\"COMPILED\")\n",
        demo_path, exe_str
    );
    let full_src = format!("{}\n{}\n{}", lexer_lib, parser_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    patlang_runtime::ir::hosts::reset_world();

    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("feature pipeline should run");
    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("fib(10) = 55"), "recursion: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("sum = 10"), "lists/while: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("sum ok"), "if/else: {}", stdout);
    assert_eq!(printed.get(3).copied(), Some("event received: hello events"), "events: {}", stdout);
    assert_eq!(printed.get(4).copied(), Some("alice children: 2"), "logic facts/query: {}", stdout);
    assert_eq!(printed.get(5).copied(), Some("kim age: 42"), "OO new/send/get: {}", stdout);
    assert_eq!(printed.get(6).copied(), Some("doubled: [2, 4, 6, 8]"), "functional map via apply: {}", stdout);
    assert_eq!(printed.get(7).copied(), Some("evens: [2, 4]"), "functional filter via apply: {}", stdout);
}

#[test]
fn selfhost_stage3_lowering_in_patlang() {
    // Fixpoint step 1: lexing, parsing, AND lowering all happen in PatLang;
    // the compile_ir host only decodes finished IR and runs codegen + rustc.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping stage 3 test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");
    let lower_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lower.patlang", manifest)).expect("read lower lib");
    let demo_path = format!("{}/../self_hosting/examples/feature_demo.patlang", manifest).replace('\\', "/");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test").join("selfhost_stage3_lowering_in_patlang");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "stage3_demo.exe" } else { "stage3_demo" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let exe = compile_ir(ir, \"{}\")\n\
         print(\"COMPILED\")\n",
        demo_path, exe_str
    );
    let full_src = format!("{}\n{}\n{}\n{}", lexer_lib, parser_lib, lower_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("stage 3 pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("stage 3 pipeline should run");
    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    // Identical output to the host-lowered stage 2 pipeline
    assert_eq!(printed.get(0).copied(), Some("fib(10) = 55"), "recursion: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("sum = 10"), "lists/while: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("sum ok"), "if/else: {}", stdout);
    assert_eq!(printed.get(3).copied(), Some("event received: hello events"), "events: {}", stdout);
    assert_eq!(printed.get(4).copied(), Some("alice children: 2"), "logic: {}", stdout);
    assert_eq!(printed.get(5).copied(), Some("kim age: 42"), "OO: {}", stdout);
    assert_eq!(printed.get(6).copied(), Some("doubled: [2, 4, 6, 8]"), "functional map: {}", stdout);
    assert_eq!(printed.get(7).copied(), Some("evens: [2, 4]"), "functional filter: {}", stdout);
}

#[test]
fn selfhost_runtime_text_parity() {
    // Stage 37A: the runtime prelude is split into named chunks on both
    // sides (rust-runtime/src/ir/codegen.rs's ChunkId constants vs
    // self_hosting/lib/runtime_rs.patlang's emit_chunk_<name>() functions).
    // Assert each chunk reproduces its host counterpart byte-for-byte
    // (better failure localization than the old all-or-nothing diff), then
    // keep one whole-program assertion that concatenating every chunk (plus
    // the dynamically-assembled call_dispatch glue) on both sides still
    // agrees -- a regression guard that the split itself didn't change the
    // concatenated output.
    let manifest = env!("CARGO_MANIFEST_DIR");
    let codegen_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/codegen.patlang", manifest)).expect("read codegen lib");
    let runtime_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/runtime_rs.patlang", manifest)).expect("read runtime lib");

    let chunk_names = [
        "core", "strings_ext", "collections_handles", "files", "io_misc",
        "oo", "logic", "contracts", "networking", "codegen_bootstrap",
        "numeric_tower", "math",
    ];

    let mut driver = String::new();
    for name in chunk_names {
        driver.push_str(&format!(
            "let a_{name} = emit_chunk_{name}()\nlet b_{name} = codegen_prelude_chunk(\"{name}\")\nif a_{name} == b_{name} then\n  print(\"PARITY-OK-{name}\")\nelse\n  print(\"PARITY-MISMATCH-{name}\")\nend\n",
            name = name
        ));
    }
    // Whole-program regression guard: all chunks concatenated (+ dispatch glue).
    driver.push_str(
        "let all_a = emit_runtime_rs()\nlet all_b = codegen_prelude()\nif all_a == all_b then\n  print(\"PARITY-OK-all\")\nelse\n  print(\"PARITY-MISMATCH-all\")\nend\n"
    );

    let full_src = format!("{}\n{}\n{}", codegen_lib, runtime_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("parity source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("parity check should run");
    let lines = PRINTED.with(|p| p.borrow().clone());

    let mut failed: Vec<&str> = Vec::new();
    for name in chunk_names.iter().chain(std::iter::once(&"all")) {
        let ok = format!("PARITY-OK-{}", name);
        if !lines.iter().any(|l| l == &ok) {
            failed.push(name);
        }
    }
    assert!(failed.is_empty(),
        "PatLang runtime chunk(s) differ from host template chunk(s) {:?} — regenerate runtime_rs.patlang: {:?}", failed, lines);
}

#[test]
fn selfhost_stage4_codegen_in_patlang() {
    // Fixpoint step 2a: lexing, parsing, lowering, AND Rust code generation
    // all happen in PatLang; the host only supplies the fixed runtime prelude
    // (codegen_prelude) and writes+compiles the source (rustc_build).
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping stage 4 test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");
    let lower_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lower.patlang", manifest)).expect("read lower lib");
    let codegen_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/codegen.patlang", manifest)).expect("read codegen lib");
    let runtime_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/runtime_rs.patlang", manifest)).expect("read runtime lib");
    let demo_path = format!("{}/../self_hosting/examples/feature_demo.patlang", manifest).replace('\\', "/");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test").join("selfhost_stage4_codegen_in_patlang");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "stage4_demo.exe" } else { "stage4_demo" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"COMPILED\")\n",
        demo_path, exe_str
    );
    let full_src = format!("{}\n{}\n{}\n{}\n{}\n{}", lexer_lib, parser_lib, lower_lib, codegen_lib, runtime_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("stage 4 pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("stage 4 pipeline should run");
    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    // Identical output to the stage 2 and 3 pipelines
    assert_eq!(printed.get(0).copied(), Some("fib(10) = 55"), "recursion: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("sum = 10"), "lists/while: {}", stdout);
    assert_eq!(printed.get(2).copied(), Some("sum ok"), "if/else: {}", stdout);
    assert_eq!(printed.get(3).copied(), Some("event received: hello events"), "events: {}", stdout);
    assert_eq!(printed.get(4).copied(), Some("alice children: 2"), "logic: {}", stdout);
    assert_eq!(printed.get(5).copied(), Some("kim age: 42"), "OO: {}", stdout);
    assert_eq!(printed.get(6).copied(), Some("doubled: [2, 4, 6, 8]"), "functional map: {}", stdout);
    assert_eq!(printed.get(7).copied(), Some("evens: [2, 4]"), "functional filter: {}", stdout);
}

#[test]
#[ignore = "full bootstrap takes ~7 minutes; run with: cargo test --test selfhost_pipeline -- --ignored"]
fn selfhost_fixpoint_patc_compiles_itself() {
    // The true fixpoint (step 2b):
    //   Gen A: the interpreter runs the PatLang compiler to compile the
    //          compiler's own source into a native patc1
    //   Gen B: patc1 compiles the feature demo (native compiler works)
    //   Gen C: patc1 compiles its own source into patc2; patc2 compiles the
    //          feature demo with identical output
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping fixpoint test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let repo_root = std::path::Path::new(manifest).parent().unwrap().to_path_buf();
    let read = |rel: &str| std::fs::read_to_string(repo_root.join(rel)).unwrap_or_else(|e| panic!("read {}: {}", rel, e));

    // Concatenate the compiler's own source (same as build_patc1.patlang)
    let compiler_src = format!(
        "{}\n{}\n{}\n{}\n{}\n{}",
        read("self_hosting/lib/lexer.patlang"),
        read("self_hosting/lib/parser.patlang"),
        read("self_hosting/lib/lower.patlang"),
        read("self_hosting/lib/codegen.patlang"),
        read("self_hosting/lib/runtime_rs.patlang"),
        read("self_hosting/patc1_main.patlang"),
    );

    let out_dir = std::env::temp_dir().join("patlang_fixpoint_test");
    let _ = std::fs::create_dir_all(&out_dir);
    let all_src_path = out_dir.join("patc1_all.patlang");
    std::fs::write(&all_src_path, &compiler_src).expect("write combined compiler source");
    let exe = |n: &str| out_dir.join(if cfg!(windows) { format!("{}.exe", n) } else { n.to_string() });
    let (patc1, patc2, demo_b, demo_c) = (exe("patc1"), exe("patc2"), exe("demo_b"), exe("demo_c"));
    let fwd = |p: &std::path::Path| p.display().to_string().replace('\\', "/");

    // --- Gen A: interpreter runs the PatLang compiler on its own source ---
    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let ir = lower_program(ast)\n\
         let rs = emit_program_rs(ir)\n\
         let exe = rustc_build(rs, \"{}\")\n\
         print(\"GEN A OK\")\n",
        fwd(&all_src_path), fwd(&patc1)
    );
    let gen_a_src = format!("{}\n{}", compiler_src, driver);
    let mut parser = Stage0Parser::new(&gen_a_src).expect("lexer init");
    let ast = parser.parse().expect("gen A source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("gen A should run");
    assert!(patc1.exists(), "gen A did not produce patc1");

    // patc1 resolves the prelude relative to its CWD; run from repo root
    let run_patc = |compiler: &std::path::Path, input: &std::path::Path, output: &std::path::Path| {
        let st = std::process::Command::new(compiler)
            .arg(fwd(input)).arg(fwd(output))
            .current_dir(&repo_root)
            .status().expect("run self-hosted compiler");
        assert!(st.success(), "{} failed on {}", compiler.display(), input.display());
    };

    // --- Gen B: native compiler compiles the feature demo ---
    let demo_src = repo_root.join("self_hosting/examples/feature_demo.patlang");
    run_patc(&patc1, &demo_src, &demo_b);
    let out_b = std::process::Command::new(&demo_b).output().expect("run demo B");
    let text_b = String::from_utf8_lossy(&out_b.stdout).to_string();
    assert!(text_b.contains("fib(10) = 55") && text_b.contains("evens: [2, 4]"), "demo B wrong: {}", text_b);

    // --- Gen C: patc1 compiles its own source; patc2 must behave identically ---
    run_patc(&patc1, &all_src_path, &patc2);
    run_patc(&patc2, &demo_src, &demo_c);
    let out_c = std::process::Command::new(&demo_c).output().expect("run demo C");
    let text_c = String::from_utf8_lossy(&out_c.stdout).to_string();
    assert_eq!(text_b, text_c, "fixpoint broken: Gen B and Gen C outputs differ");
}

#[test]
fn selfhost_pipeline_compiles_tcp_echo_server() {
    // Networking through the self-hosted front-end: the Stage 1 echo server
    // compiles natively, binds a TCP port, and answers two HTTP requests.
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping echo server test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");
    let demo_path = format!("{}/../self_hosting/examples/echo_server.patlang", manifest).replace('\\', "/");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test").join("selfhost_pipeline_compiles_tcp_echo_server");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "echo_server.exe" } else { "echo_server" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    let driver = format!(
        "let source = read_file(\"{}\")\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let exe = compile_shape(ast, \"{}\")\n\
         print(\"COMPILED\")\n",
        demo_path, exe_str
    );
    let full_src = format!("{}\n{}\n{}", lexer_lib, parser_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);
    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("echo server pipeline should run");
    assert!(exe_path.exists(), "compiled echo server not found at {}", exe_path.display());

    // Spawn the server, read the bound port from its stdout, hit it twice
    use std::io::{BufRead, BufReader, Read, Write};
    let mut child = KillOnDrop::new(std::process::Command::new(&exe_path)
        .stdout(std::process::Stdio::piped())
        .spawn()
        .expect("spawn echo server"));
    let stdout = child.stdout.take().expect("child stdout");
    let mut reader = BufReader::new(stdout);
    let mut first = String::new();
    reader.read_line(&mut first).expect("read PORT line");
    let port: u16 = first.trim().strip_prefix("PORT: ").expect("PORT line").parse().expect("port number");

    for path in ["/hello", "/again"] {
        let mut stream = std::net::TcpStream::connect(("127.0.0.1", port)).expect("connect");
        write!(stream, "GET {} HTTP/1.1\r\nHost: localhost\r\n\r\n", path).expect("send request");
        let mut resp = String::new();
        stream.read_to_string(&mut resp).expect("read response");
        assert!(resp.starts_with("HTTP/1.1 200 OK"), "bad response: {}", resp);
        assert!(resp.contains(&format!("echo: GET {} HTTP/1.1", path)), "echo missing: {}", resp);
    }

    let status = child.wait().expect("server exit");
    assert!(status.success(), "server exited with {:?}", status);
}

#[test]
fn selfhost_pipeline_compiles_program_via_patlang_frontend() {
    // rustc is required to complete the pipeline; skip when unavailable
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_err() {
        eprintln!("rustc not found; skipping selfhost pipeline test");
        return;
    }

    let manifest = env!("CARGO_MANIFEST_DIR");
    let lexer_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/lexer.patlang", manifest)).expect("read lexer lib");
    let parser_lib = std::fs::read_to_string(format!("{}/../self_hosting/lib/parser.patlang", manifest)).expect("read parser lib");

    let out_dir = std::env::temp_dir().join("patlang_selfhost_pipeline_test").join("selfhost_pipeline_compiles_program_via_patlang_frontend");
    let _ = std::fs::create_dir_all(&out_dir);
    let exe_path = out_dir.join(if cfg!(windows) { "pipeline_out.exe" } else { "pipeline_out" });
    let exe_str = exe_path.display().to_string().replace('\\', "/");

    // Driver: lex + parse a tiny program with the PatLang front-end, then compile it
    let driver = format!(
        "let source = \"let x = 40\\nlet y = x + 2\\nprint(\\\"answer: \\\" + y)\\nprint(y * 10)\\n\"\n\
         let toks = tokenize(source)\n\
         let ast = parse_program(toks)\n\
         let exe = compile_shape(ast, \"{}\")\n\
         print(\"COMPILED\")\n",
        exe_str
    );
    let full_src = format!("{}\n{}\n{}", lexer_lib, parser_lib, driver);

    let mut parser = Stage0Parser::new(&full_src).expect("lexer init");
    let ast = parser.parse().expect("pipeline source should parse");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    let mut interp = Interpreter::new();
    interp.host.insert("print", capture_print);
    register_stage0_shims(&mut interp);

    PRINTED.with(|p| p.borrow_mut().clear());
    interp.run(&program).expect("pipeline should run");

    let lines = PRINTED.with(|p| p.borrow().clone());
    assert!(lines.iter().any(|l| l == "COMPILED"), "pipeline did not reach compile step: {:?}", lines);
    assert!(exe_path.exists(), "compiled executable not found at {}", exe_path.display());

    // Run the native executable produced by the PatLang front-end
    let out = std::process::Command::new(&exe_path).output().expect("run compiled exe");
    assert!(out.status.success(), "compiled exe failed: {:?}", out.status);
    let stdout = String::from_utf8_lossy(&out.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.get(0).copied(), Some("answer: 42"), "unexpected output: {}", stdout);
    assert_eq!(printed.get(1).copied(), Some("420"), "unexpected output: {}", stdout);
}
