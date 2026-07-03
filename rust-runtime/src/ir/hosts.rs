//! Shared Stage 0 host shims for the IR interpreter.
//! Kept in sync with the arms in the codegen template so interpreted and
//! compiled programs observe the same host semantics.

use super::interpreter::Interpreter;
use super::types::Value;

fn display_value(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => if n.fract() == 0.0 { format!("{}", *n as i64) } else { n.to_string() },
        Value::String(s) => s.clone(),
        Value::List(xs) => {
            let parts: Vec<String> = xs.iter().map(display_value).collect();
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

pub fn host_list_get(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("list_get: expected 2 args".into()); }
    let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(s) => s.parse::<usize>().unwrap_or(usize::MAX), _ => usize::MAX };
    match &args[0] {
        Value::List(xs) => Ok(xs.get(idx).cloned().unwrap_or(Value::Unit)),
        Value::String(s) => Ok(match s.chars().nth(idx) { Some(c) => Value::String(c.to_string()), None => Value::String(String::new()) }),
        _ => Ok(Value::Unit),
    }
}

pub fn host_list_len(args: &[Value]) -> Result<Value, String> {
    if args.len() != 1 { return Err("list_len: expected 1 arg".into()); }
    let n = match &args[0] {
        Value::List(xs) => xs.len(),
        Value::String(s) => s.chars().count(),
        _ => 0,
    };
    Ok(Value::String(n.to_string()))
}

pub fn host_list_push(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("list_push: expected 2 args".into()); }
    let mut xs = match &args[0] {
        Value::List(xs) => xs.clone(),
        Value::Unit => Vec::new(),
        _ => return Err("list_push: expected list".into()),
    };
    xs.push(args[1].clone());
    Ok(Value::List(xs))
}

pub fn host_char_code(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("char_code: expected 2 args".into()); }
    let s = match &args[0] { Value::String(s) => s.clone(), v => display_value(v) };
    let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(t) => t.parse::<usize>().unwrap_or(usize::MAX), _ => usize::MAX };
    match s.chars().nth(idx) {
        Some(c) => Ok(Value::Number(c as u32 as f64)),
        None => Ok(Value::Number(-1.0)),
    }
}

pub fn host_substr(args: &[Value]) -> Result<Value, String> {
    if args.len() != 3 { return Err("substr: expected 3 args".into()); }
    let s = match &args[0] { Value::String(s) => s.clone(), v => display_value(v) };
    let start = match &args[1] { Value::Number(n) => (*n).max(0.0) as usize, Value::String(t) => t.parse::<usize>().unwrap_or(0), _ => 0 };
    let count = match &args[2] { Value::Number(n) => (*n).max(0.0) as usize, Value::String(t) => t.parse::<usize>().unwrap_or(0), _ => 0 };
    Ok(Value::String(s.chars().skip(start).take(count).collect()))
}

pub fn host_to_num(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).cloned().unwrap_or(Value::Unit);
    let n = match v {
        Value::Number(n) => n,
        Value::String(s) => s.trim().parse::<f64>().unwrap_or(0.0),
        Value::Bool(b) => if b { 1.0 } else { 0.0 },
        _ => 0.0,
    };
    Ok(Value::Number(n))
}

pub fn host_read_file(args: &[Value]) -> Result<Value, String> {
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    std::fs::read_to_string(&p).map(Value::String).map_err(|e| format!("read_file: {}: {}", p, e))
}

pub fn host_len(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).cloned().unwrap_or(Value::Unit);
    let n = match v {
        Value::String(ref s) => s.chars().count() as f64,
        Value::List(ref xs) => xs.len() as f64,
        Value::Object(ref m) => m.len() as f64,
        _ => 0.0,
    };
    Ok(Value::Number(n))
}

pub fn host_get(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("expected 2 args".into()); }
    let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
    match &args[0] {
        Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
        _ => Ok(Value::Unit),
    }
}

// --- AST-shape lowering: list-shaped AST (from the self-hosted parser) → IR Program ---
// Shape grammar:
//   ["Program", [stmts]]
//   ["Let", name, expr] | ["Print", expr]
//   ["Num", text] | ["Str", text] | ["Var", name] | ["Bin", op, lhs, rhs]

use super::types::{Program, Function, Instr, BinOpKind};

fn shape_list(v: &Value) -> Result<&Vec<Value>, String> {
    match v { Value::List(xs) => Ok(xs), _ => Err(format!("compile_shape: expected list node, got {}", display_value(v))) }
}

fn shape_tag(xs: &[Value]) -> Result<&str, String> {
    match xs.get(0) { Some(Value::String(s)) => Ok(s.as_str()), _ => Err("compile_shape: node missing tag".into()) }
}

fn shape_str(xs: &[Value], i: usize, what: &str) -> Result<String, String> {
    match xs.get(i) { Some(Value::String(s)) => Ok(s.clone()), _ => Err(format!("compile_shape: expected string {} in node", what)) }
}

fn lower_shape_expr(v: &Value, f: &mut Function) -> Result<(), String> {
    let xs = shape_list(v)?;
    match shape_tag(xs)? {
        "Num" => {
            let text = shape_str(xs, 1, "number text")?;
            let n = text.trim().parse::<f64>().map_err(|_| format!("compile_shape: bad number '{}'", text))?;
            f.body.push(Instr::Const(Value::Number(n)));
        }
        "Str" => {
            let text = shape_str(xs, 1, "string text")?;
            f.body.push(Instr::Const(Value::String(text)));
        }
        "Var" => {
            let name = shape_str(xs, 1, "variable name")?;
            f.body.push(Instr::LoadLocal(name));
        }
        "Bin" => {
            let op = shape_str(xs, 1, "operator")?;
            let lhs = xs.get(2).ok_or("compile_shape: Bin missing lhs")?;
            let rhs = xs.get(3).ok_or("compile_shape: Bin missing rhs")?;
            lower_shape_expr(lhs, f)?;
            lower_shape_expr(rhs, f)?;
            let kind = match op.as_str() {
                "+" => BinOpKind::Add,
                "-" => BinOpKind::Sub,
                "*" => BinOpKind::Mul,
                "/" => BinOpKind::Div,
                "%" => BinOpKind::Mod,
                "==" => BinOpKind::Eq,
                "!=" => BinOpKind::Ne,
                "<" => BinOpKind::Lt,
                "<=" => BinOpKind::Le,
                ">" => BinOpKind::Gt,
                ">=" => BinOpKind::Ge,
                other => return Err(format!("compile_shape: unknown operator '{}'", other)),
            };
            f.body.push(Instr::BinOp(kind));
        }
        other => return Err(format!("compile_shape: unknown expr node '{}'", other)),
    }
    Ok(())
}

fn lower_shape_stmt(v: &Value, f: &mut Function) -> Result<(), String> {
    let xs = shape_list(v)?;
    match shape_tag(xs)? {
        "Let" => {
            let name = shape_str(xs, 1, "let name")?;
            let expr = xs.get(2).ok_or("compile_shape: Let missing expr")?;
            lower_shape_expr(expr, f)?;
            f.body.push(Instr::StoreLocal(name));
        }
        "Print" => {
            let expr = xs.get(1).ok_or("compile_shape: Print missing expr")?;
            lower_shape_expr(expr, f)?;
            f.body.push(Instr::CallHost("print".into(), 1));
        }
        "Err" => {
            return Err(format!("compile_shape: parse error node: {}", shape_str(xs, 1, "message").unwrap_or_default()));
        }
        other => return Err(format!("compile_shape: unknown stmt node '{}'", other)),
    }
    Ok(())
}

/// Convert a list-shaped AST into an IR Program with a single main function.
pub fn shape_to_program(v: &Value) -> Result<Program, String> {
    let xs = shape_list(v)?;
    if shape_tag(xs)? != "Program" { return Err("compile_shape: root node must be Program".into()); }
    let stmts = match xs.get(1) { Some(Value::List(s)) => s, _ => return Err("compile_shape: Program missing statement list".into()) };
    let mut f = Function { name: "main".into(), ..Default::default() };
    for s in stmts { lower_shape_stmt(s, &mut f)?; }
    f.body.push(Instr::Return);
    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);
    Ok(program)
}

/// compile_shape(ast_shape, out_path) -> compiled exe path.
/// Lowers the list-shaped AST to IR, emits Rust, and compiles with rustc.
pub fn host_compile_shape(args: &[Value]) -> Result<Value, String> {
    let shape = args.get(0).ok_or("compile_shape: expected AST shape")?;
    let out = match args.get(1) {
        Some(Value::String(s)) if !s.trim().is_empty() => s.clone(),
        _ => return Err("compile_shape: expected output path as second argument".into()),
    };
    let program = shape_to_program(shape)?;
    let cg = super::codegen::RustCodegen::new();
    let rust_src = cg.emit_rust(&program);

    let mut tmp = std::env::temp_dir();
    tmp.push("patlang_shape_compile");
    std::fs::create_dir_all(&tmp).map_err(|e| format!("compile_shape: temp dir: {}", e))?;
    let src_path = tmp.join("shape_main.rs");
    std::fs::write(&src_path, &rust_src).map_err(|e| format!("compile_shape: write {}: {}", src_path.display(), e))?;

    if let Some(parent) = std::path::Path::new(&out).parent() { let _ = std::fs::create_dir_all(parent); }
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let status = std::process::Command::new(&rustc)
        .arg("-O")
        .arg(&src_path)
        .arg("-o")
        .arg(&out)
        .status()
        .map_err(|e| format!("compile_shape: failed to run rustc: {}", e))?;
    if !status.success() { return Err(format!("compile_shape: rustc failed with status {}", status)); }
    let p = std::path::Path::new(&out);
    let abs = std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf());
    Ok(Value::String(abs.display().to_string()))
}

/// Register the Stage 0 string/list/file shims on an interpreter.
pub fn register_stage0_shims(interp: &mut Interpreter) {
    interp.host.insert("len", host_len);
    interp.host.insert("get", host_get);
    interp.host.insert("list_get", host_list_get);
    interp.host.insert("list_len", host_list_len);
    interp.host.insert("list_push", host_list_push);
    interp.host.insert("char_code", host_char_code);
    interp.host.insert("substr", host_substr);
    interp.host.insert("to_num", host_to_num);
    interp.host.insert("read_file", host_read_file);
    interp.host.insert("compile_shape", host_compile_shape);
}
