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
    //   --patc <file.pat> [--out <file.exe>] (compile to native exe, no run)
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
            "--patc" => { mode = "patc".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--compare" => { mode = "compare".into(); if i+1 < args.len() { filename = Some(&args[i+1]); i+=1; } }
            "--time" => { /* handled later via env flag */ }
            "--out" => { if i+1 < args.len() { out_file = Some(&args[i+1]); i+=1; } }
            s if !s.starts_with("--") && filename.is_none() => { filename = Some(s); }
            _ => {}
        }
        i+=1;
    }
    let filename = match filename { Some(f) => f, None => { eprintln!("Usage: {} [--ir-run|--emit-rust|--build-run|--patc|--compare] <file.pat> [--out <path>]", args[0]); process::exit(1); } };
    let source = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading file '{}': {}", filename, e);
            process::exit(1);
        }
    };
    // Expand include "path" lines relative to the script's directory
    let base_dir = std::path::Path::new(filename).parent().map(|p| p.to_path_buf()).unwrap_or_else(|| std::path::PathBuf::from("."));
    let source = match patlang_runtime::preprocess::expand_includes(&source, &base_dir) {
        Ok(s) => s,
        Err(e) => { eprintln!("Include error: {}", e); process::exit(1); }
    };
    if mode == "ir-run" || mode == "emit-rust" || mode == "build-run" || mode == "compare" || mode == "patc" {
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

    if mode == "emit-rust" || mode == "build-run" || mode == "compare" || mode == "patc" {
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
        // build-run, patc, or compare: write to temp, rustc, then run/emit
        let mut tmp = std::env::temp_dir();
        tmp.push("patlang_emit");
        let _ = std::fs::create_dir_all(&tmp);
        let src_path = tmp.join("generated_main.rs");
        if let Err(e) = fs::write(&src_path, &rust_src) {
            eprintln!("Failed to write {}: {}", src_path.display(), e);
            process::exit(1);
        }
        use std::path::{Path, PathBuf};
        // Destination path for patc, if requested (we will emit directly to this path)
        let patc_dest: Option<PathBuf> = if mode == "patc" {
            if let Some(out) = out_file { Some(PathBuf::from(out)) } else {
                let in_path = Path::new(filename);
                let stem = in_path.file_stem().and_then(|s| s.to_str()).unwrap_or("a");
                let parent = in_path.parent().unwrap_or_else(|| Path::new("."));
                let mut out = parent.join(stem);
                if cfg!(windows) { out.set_extension("exe"); }
                Some(out)
            }
        } else { None };
        // Determine the output path for rustc -o
        let compile_exe_path = if let Some(dest) = &patc_dest {
            // Ensure parent dir exists for destination
            if let Some(parent) = dest.parent() { let _ = std::fs::create_dir_all(parent); }
            dest.clone()
        } else {
            if cfg!(windows) { tmp.join("generated_main.exe") } else { tmp.join("generated_main") }
        };
        let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
        if mode == "patc" { eprintln!("[patc] Compiling with {} -> {}", rustc, compile_exe_path.display()); }
        let status = std::process::Command::new(&rustc)
            .arg("-O")
            .arg(&src_path)
            .arg("-o")
            .arg(&compile_exe_path)
            .status();
        match status {
            Ok(st) if st.success() => {
                if mode == "patc" {
                    let dest = compile_exe_path;
                    let abs = std::fs::canonicalize(&dest).unwrap_or(dest);
                    println!("Wrote {}", abs.display());
                    return;
                }
                if mode == "build-run" {
                    let output = std::process::Command::new(&compile_exe_path)
                        .output()
                        .unwrap_or_else(|e| { eprintln!("Failed to run {}: {}", compile_exe_path.display(), e); process::exit(1); });
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
                        // For compare, have print return the printed text so the final value reflects stdout
                        interp.host.insert("print", ir_host_print_ret);
                        interp.host.insert("sed", ir_host_sed);
                        // emit is a no-op in pure interpreter for this compare path
                        interp.host.insert("emit", |_args| Ok(Value::Unit));
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
                        register_stage0_shims(&mut interp);
                        interp.run(&program).unwrap_or(Value::Unit)
                    };
                    let interp_dur = interp_start.elapsed();
                    let interp_str = display_value(&interp_v);

                    // Compiled run
                    let comp_start = std::time::Instant::now();
                    let output = std::process::Command::new(&compile_exe_path)
                        .output()
                        .unwrap_or_else(|e| { eprintln!("Failed to run {}: {}", compile_exe_path.display(), e); process::exit(1); });
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
    interp.host.insert("sed", ir_host_sed);
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
    register_stage0_shims(&mut interp);
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

// Variant used in --compare: also returns the printed text so the interpreter's final value
// can be compared against the compiled program's stdout.
fn ir_host_print_ret(args: &[Value]) -> Result<Value, String> {
    let s = if let Some(arg0) = args.get(0) {
        display_value(arg0)
    } else {
        String::new()
    };
    println!("{}", s);
    Ok(Value::String(s))
}

fn ir_host_sed(args: &[Value]) -> Result<Value, String> {
    // sed("s/pat/repl/[flags]", input)
    let cmd = match args.get(0) { Some(Value::String(s)) => s.as_str(), _ => return Ok(Value::Unit) };
    let dv;
    let input: &str = match args.get(1) {
        Some(Value::String(s)) => s.as_str(),
        Some(v) => { dv = display_value(v); dv.as_str() },
        None => "",
    };
    let out = sed_command(cmd, input);
    Ok(Value::String(out))
}

fn sed_command(cmd: &str, input: &str) -> String {
    // Minimal sed: supports s/pat/repl/[g|i|gi]
    if !cmd.starts_with('s') { return input.to_string(); }
    let mut parts = cmd.splitn(4, '/');
    let _s = parts.next(); // "s"
    let pat = match parts.next() { Some(p) => p, None => return input.to_string() };
    let repl = match parts.next() { Some(r) => r, None => return input.to_string() };
    let flags = parts.next().unwrap_or("");
    let global = flags.contains('g');
    let ci = flags.contains('i');
    replace_lit(input, pat, repl, global, ci)
}

fn replace_lit(hay: &str, pat: &str, rep: &str, global: bool, ci: bool) -> String {
    if pat.is_empty() { return hay.to_string(); }
    if !ci {
        if !global {
            if let Some(pos) = hay.find(pat) {
                let mut out = String::with_capacity(hay.len());
                out.push_str(&hay[..pos]);
                out.push_str(rep);
                out.push_str(&hay[pos+pat.len()..]);
                return out;
            }
            return hay.to_string();
        } else {
            let mut out = String::with_capacity(hay.len());
            let mut start = 0usize;
            let mut rest = hay;
            while let Some(pos) = rest.find(pat) {
                let abs = start + pos;
                out.push_str(&hay[start..abs]);
                out.push_str(rep);
                start = abs + pat.len();
                rest = &hay[start..];
            }
            out.push_str(&hay[start..]);
            return out;
        }
    }
    // case-insensitive: naive ASCII-only approach
    let hay_l = hay.to_ascii_lowercase();
    let pat_l = pat.to_ascii_lowercase();
    if !global {
        if let Some(pos) = hay_l.find(&pat_l) {
            let mut out = String::with_capacity(hay.len());
            out.push_str(&hay[..pos]);
            out.push_str(rep);
            out.push_str(&hay[pos+pat.len()..]);
            return out;
        }
        return hay.to_string();
    } else {
        let mut out = String::with_capacity(hay.len());
        let mut start = 0usize;
        let mut idx = 0usize;
        while idx <= hay_l.len() {
            if let Some(pos) = hay_l[idx..].find(&pat_l) {
                let abs = idx + pos;
                out.push_str(&hay[start..abs]);
                out.push_str(rep);
                start = abs + pat.len();
                idx = start;
            } else { break; }
        }
        out.push_str(&hay[start..]);
        return out;
    }
}

fn host_bin_num(args: &[Value], f: fn(f64, f64) -> f64) -> Result<Value, String> {
    let a = args.get(0).ok_or("expected 2 args")?;
    let b = args.get(1).ok_or("expected 2 args")?;
    let an = match a { Value::Number(n) => *n, _ => return Err("expected number".into()) };
    let bn = match b { Value::Number(n) => *n, _ => return Err("expected number".into()) };
    Ok(Value::Number(f(an, bn)))
}

// Stage 0 string/list host shims live in the library so tests and other
// consumers register the same set: patlang_runtime::ir::hosts
use patlang_runtime::ir::hosts::register_stage0_shims;
