mod event_system;
mod message_queue;
mod error_handler;
mod secure_distributed_code_support;


use std::env;
use std::process;
use std::fs;
use patlang_runtime::{core_evaluator, parser::Parser, ir::{Lowerer, Interpreter, Value, RustCodegen}};

fn main() {
    let args: Vec<String> = env::args().collect();
    // Modes:
    //   --ir-run <file.pat>
    //   --emit-rust <file.pat> [--out <file.rs>]
    //   --build-run <file.pat>  (emit, compile with rustc, then run)
    //   --compare <file.pat> [--time]  (run interpreter vs compiled and compare outputs, optionally timings)
    let mut mode = "eval".to_string();
    let mut filename: Option<&str> = None;
    let mut out_file: Option<&str> = None;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--ir-run" => { mode = "ir-run".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--emit-rust" => { mode = "emit-rust".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--build-run" => { mode = "build-run".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--compare" => { mode = "compare".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--time" => { /* handled later via env flag */ }
            "--out" => { if i+1 < args.len() { out_file = Some(&args[i+1]); i+=1; } }
            s if !s.starts_with("--") && filename.is_none() => { filename = Some(s); }
            _ => {}
        }
        i+=1;
    }
    let filename = match filename { Some(f) => f, None => { eprintln!("Usage: {} [--ir-run|--emit-rust] <file.pat> [--out file.rs]", args[0]); process::exit(1); } };
    let source = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading file '{}': {}", filename, e);
            process::exit(1);
        }
    };
    if mode == "ir-run" || mode == "emit-rust" || mode == "build-run" || mode == "compare" {
        // Guardrail: quick scan for unsupported high-level constructs before parsing
        let unsupported_markers = [
            "reasoning mode",
            "pursue ",
            "constrain ",
        ];
        if unsupported_markers.iter().any(|m| source.contains(m)) {
            eprintln!("This file uses constructs not yet supported by the Stage 0 IR/compare pipeline (functions, facts/rules/goals, reasoning mode, or object literals).\nTry running without IR flags, or select a simpler example like 'simple_expressions.pat'.");
            process::exit(2);
        }
        // Parse → Lower to IR → Run interpreter
        let mut parser = match Parser::new(&source) {
            Ok(p) => p,
            Err(e) => { eprintln!("Parse error: {:?}", e); process::exit(1); }
        };
        let ast = match parser.parse() {
            Ok(a) => a,
            Err(e) => {
                eprintln!("Parse error: {:?}", e);
                eprintln!("Hint: The IR/compare path currently supports expressions, let/return, if/else, lists, boolean ops, and simple host calls. For reasoning/functions/goals, use the default evaluator or phase1 backend.");
                process::exit(1);
            }
        };
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);

    if mode == "emit-rust" || mode == "build-run" || mode == "compare" {
        let cg = RustCodegen::new();
        let rust_src = cg.emit_rust(&program);
        if mode == "emit-rust" {
            if let Some(path) = out_file {
                if let Err(e) = fs::write(path, &rust_src) {
                    eprintln!("Failed to write {}: {}", path, e);
                    process::exit(1);
                } else {
                    println!("Wrote {}", path);
                }
            } else {
                println!("{}", rust_src);
            }
            return;
        }
        // build-run or compare: write to temp, rustc, then run
        let mut tmp = std::env::temp_dir();
        tmp.push("patlang_emit");
        let _ = std::fs::create_dir_all(&tmp);
        let src_path = tmp.join("generated_main.rs");
        if let Err(e) = fs::write(&src_path, &rust_src) {
            eprintln!("Failed to write {}: {}", src_path.display(), e);
            process::exit(1);
        }
        let exe_path = if cfg!(windows) { tmp.join("generated_main.exe") } else { tmp.join("generated_main") };
        let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
        let status = std::process::Command::new(&rustc)
            .arg("-O")
            .arg(&src_path)
            .arg("-o")
            .arg(&exe_path)
            .status();
        match status {
            Ok(st) if st.success() => {
                if mode == "build-run" {
                    let output = std::process::Command::new(&exe_path)
                        .output()
                        .unwrap_or_else(|e| { eprintln!("Failed to run {}: {}", exe_path.display(), e); process::exit(1); });
                    print!("{}", String::from_utf8_lossy(&output.stdout));
                    if !output.status.success() {
                        eprintln!("Child exited with status: {}", output.status);
                        eprint!("{}", String::from_utf8_lossy(&output.stderr));
                        process::exit(output.status.code().unwrap_or(1));
                    }
                    return;
                } else {
                    // compare: run interpreter and compiled, compare outputs; optional timings
                    let want_time = args.iter().any(|a| a == "--time");
                    // Interp run and capture string form
                    let interp_start = std::time::Instant::now();
                    let interp_v = {
                        let mut interp = Interpreter::new();
                        // register same hosts as IR mode
                        interp.host.insert("print", ir_host_print);
                        interp.host.insert("add", |args| host_bin_num(args, |a,b| a + b));
                        interp.host.insert("multiply", |args| host_bin_num(args, |a,b| a * b));
                        interp.host.insert("subtract", |args| host_bin_num(args, |a,b| a - b));
                        interp.host.insert("max", |args| host_bin_num(args, |a,b| a.max(b)));
                        interp.host.insert("min", |args| host_bin_num(args, |a,b| a.min(b)));
                        interp.host.insert("calculate", |_args| Ok(Value::Number(0.0)));
                        interp.host.insert("calculate_result", |_args| Ok(Value::Number(0.0)));
                        interp.host.insert("get_value", |_args| Ok(Value::Number(0.0)));
                        interp.host.insert("process", |_args| Ok(Value::Bool(true)));
                        interp.host.insert("validate", |_args| Ok(Value::Bool(true)));
                        interp.host.insert("len", |args| {
                            let v = args.get(0).cloned().unwrap_or(Value::Unit);
                            let n = match v {
                                Value::String(ref s) => s.chars().count() as f64,
                                Value::List(ref xs) => xs.len() as f64,
                                Value::Object(ref m) => m.len() as f64,
                                Value::Unit => 0.0,
                                _ => 0.0,
                            }; Ok(Value::Number(n))
                        });
                        interp.host.insert("get", |args| {
                            if args.len() != 2 { return Err("expected 2 args".into()); }
                            let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
                            match &args[0] { Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)), _ => Ok(Value::Unit), }
                        });
                        interp.run(&program).unwrap_or(Value::Unit)
                    };
                    let interp_dur = interp_start.elapsed();
                    let interp_str = display_value(&interp_v);

                    // Compiled run
                    let comp_start = std::time::Instant::now();
                    let output = std::process::Command::new(&exe_path)
                        .output()
                        .unwrap_or_else(|e| { eprintln!("Failed to run {}: {}", exe_path.display(), e); process::exit(1); });
                    let comp_dur = comp_start.elapsed();
                    if !output.status.success() {
                        eprintln!("Compiled program failed: {}", output.status);
                        eprint!("{}", String::from_utf8_lossy(&output.stderr));
                        process::exit(output.status.code().unwrap_or(1));
                    }
                    let compiled_out = String::from_utf8_lossy(&output.stdout).trim().to_string();
                    let ok = compiled_out == interp_str;
                    println!("compare: {}", if ok { "OK" } else { "MISMATCH" });
                    if !ok {
                        println!("  interp:   {}", interp_str);
                        println!("  compiled: {}", compiled_out);
                        process::exit(2);
                    }
                    if want_time {
                        println!("timings: interp={}ms compiled={}ms", interp_dur.as_millis(), comp_dur.as_millis());
                    }
                    return;
                }
            }
            Ok(st) => { eprintln!("rustc failed with status: {}", st); process::exit(1); }
            Err(e) => { eprintln!("Failed to invoke rustc: {}", e); process::exit(1); }
        }
    }

    let mut interp = Interpreter::new();
    // Provide basic host built-ins for IR mode
    interp.host.insert("print", ir_host_print);
    interp.host.insert("add", |args| host_bin_num(args, |a,b| a + b));
    interp.host.insert("multiply", |args| host_bin_num(args, |a,b| a * b));
    interp.host.insert("subtract", |args| host_bin_num(args, |a,b| a - b));
    interp.host.insert("max", |args| host_bin_num(args, |a,b| a.max(b)));
    interp.host.insert("min", |args| host_bin_num(args, |a,b| a.min(b)));
    // placeholder demo functions
    interp.host.insert("calculate", |_args| Ok(Value::Number(0.0)));
    interp.host.insert("calculate_result", |_args| Ok(Value::Number(0.0)));
    // additional stubs used in examples
    interp.host.insert("get_value", |_args| Ok(Value::Number(0.0)));
    interp.host.insert("process", |_args| Ok(Value::Bool(true)));
    interp.host.insert("validate", |_args| Ok(Value::Bool(true)));
    interp.host.insert("len", |args| {
        let v = args.get(0).cloned().unwrap_or(Value::Unit);
        let n = match v {
            Value::String(ref s) => s.chars().count() as f64,
            Value::List(ref xs) => xs.len() as f64,
            Value::Object(ref m) => m.len() as f64,
            Value::Unit => 0.0,
            _ => 0.0,
        };
        Ok(Value::Number(n))
    });
    interp.host.insert("get", |args| {
        // get(obj, key) -> returns value or Unit
        if args.len() != 2 { return Err("expected 2 args".into()); }
        let obj = &args[0];
        let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
        match obj {
            Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
            _ => Ok(Value::Unit),
        }
    });
    match interp.run(&program) {
            Ok(v) => {
                println!("{}", display_value(&v));
            }
            Err(e) => {
                eprintln!("IR runtime error: {}", e);
                process::exit(1);
            }
        }
    return;
    }

    match core_evaluator::evaluate_patlang_source(&source) {
        Ok(result) => {
            println!("{}", result.message);
            // crude keepalive: if runtime requested, sleep loop
            if let Some(keep) = result.objects.iter().find(|(n, _)| n == "__runtime") {
                let has = keep.1.iter().any(|(k, v)| k == "keepalive" && v == "true");
                if has {
                    println!("WebServer running. Press Ctrl+C to stop.");
                    loop { std::thread::sleep(std::time::Duration::from_secs(3600)); }
                }
            }
        },
        Err(err) => {
            eprintln!("{}", err.message);
            process::exit(1);
        }
    }
}

fn display_value(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => {
            // trim trailing .0 for integers
            if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() }
        }
        Value::String(s) => s.clone(),
        Value::List(xs) => {
            let parts: Vec<String> = xs.iter().map(|x| display_value(x)).collect();
            format!("[{}]", parts.join(", "))
        }
        Value::HostFunction(_) => "<hostfn>".into(),
        Value::Object(map) => {
            let mut kvs: Vec<String> = map.iter().map(|(k, v)| format!("{}: {}", k, display_value(v))).collect();
            kvs.sort();
            format!("{{{}}}", kvs.join(", "))
        }
    }
}

fn ir_host_print(args: &[Value]) -> Result<Value, String> {
    if let Some(arg0) = args.get(0) {
        println!("{}", display_value(arg0));
    } else {
        println!("");
    }
    Ok(Value::Unit)
}

fn host_bin_num(args: &[Value], f: fn(f64, f64) -> f64) -> Result<Value, String> {
    let a = args.get(0).ok_or("expected 2 args")?;
    let b = args.get(1).ok_or("expected 2 args")?;
    let an = match a { Value::Number(n) => *n, _ => return Err("expected number".into()) };
    let bn = match b { Value::Number(n) => *n, _ => return Err("expected number".into()) };
    Ok(Value::Number(f(an, bn)))
}
