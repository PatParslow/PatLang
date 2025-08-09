mod event_system;
mod message_queue;
mod error_handler;
mod secure_distributed_code_support;


use std::env;
use std::process;
use std::fs;
use patlang_runtime::{core_evaluator, parser::Parser, ir::{Lowerer, Interpreter, Value}};

fn main() {
    let args: Vec<String> = env::args().collect();
    // Support optional IR mode: app --ir-run <file.pat>
    let (ir_mode, filename) = if args.len() == 3 && args[1] == "--ir-run" {
        (true, &args[2])
    } else if args.len() == 2 {
        (false, &args[1])
    } else {
        eprintln!("Usage: {} [--ir-run] <file.pat>", args[0]);
        process::exit(1);
    };
    let source = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading file '{}': {}", filename, e);
            process::exit(1);
        }
    };
    if ir_mode {
        // Parse → Lower to IR → Run interpreter
        let mut parser = match Parser::new(&source) {
            Ok(p) => p,
            Err(e) => { eprintln!("Parse error: {:?}", e); process::exit(1); }
        };
        let ast = match parser.parse() {
            Ok(a) => a,
            Err(e) => { eprintln!("Parse error: {:?}", e); process::exit(1); }
        };
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
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
