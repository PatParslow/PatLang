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
        Value::String(s) => {
            // O(1) byte indexing for ASCII strings; chars().nth for the rest
            if s.is_ascii() {
                Ok(match s.as_bytes().get(idx) { Some(b) => Value::String((*b as char).to_string()), None => Value::String(String::new()) })
            } else {
                Ok(match s.chars().nth(idx) { Some(c) => Value::String(c.to_string()), None => Value::String(String::new()) })
            }
        }
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

pub fn host_list_set(args: &[Value]) -> Result<Value, String> {
    // list_set(list, index, value) -> new list with element replaced
    if args.len() != 3 { return Err("list_set: expected 3 args".into()); }
    let mut xs = match &args[0] {
        Value::List(xs) => xs.clone(),
        _ => return Err("list_set: expected list".into()),
    };
    let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(s) => s.parse::<usize>().unwrap_or(usize::MAX), _ => usize::MAX };
    if idx >= xs.len() { return Err(format!("list_set: index {} out of range (len {})", idx, xs.len())); }
    xs[idx] = args[2].clone();
    Ok(Value::List(xs))
}

pub fn host_char_code(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("char_code: expected 2 args".into()); }
    let s = match &args[0] { Value::String(s) => s.clone(), v => display_value(v) };
    let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(t) => t.parse::<usize>().unwrap_or(usize::MAX), _ => usize::MAX };
    if s.is_ascii() {
        return Ok(Value::Number(match s.as_bytes().get(idx) { Some(b) => *b as f64, None => -1.0 }));
    }
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
    if s.is_ascii() {
        let b = s.as_bytes();
        let st = start.min(b.len());
        let en = st.saturating_add(count).min(b.len());
        return Ok(Value::String(String::from_utf8_lossy(&b[st..en]).to_string()));
    }
    Ok(Value::String(s.chars().skip(start).take(count).collect()))
}

// --- Handle-based builders: O(1) push/index for large collections, avoiding
// the whole-list clone that value-semantics locals otherwise imply ---

thread_local! {
    static VECS: RefCell<Vec<Vec<Value>>> = RefCell::new(Vec::new());
    static SBUFS: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

fn arg_usize(args: &[Value], i: usize, what: &str) -> Result<usize, String> {
    match args.get(i) {
        Some(Value::Number(n)) => Ok(*n as usize),
        Some(Value::String(s)) => s.trim().parse::<usize>().map_err(|_| format!("{}: expected index", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

pub fn host_vec_new(_args: &[Value]) -> Result<Value, String> {
    let id = VECS.with(|v| { let mut b = v.borrow_mut(); b.push(Vec::new()); b.len() - 1 });
    Ok(Value::Number(id as f64))
}

pub fn host_vec_push(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "vec_push")?;
    let item = args.get(1).cloned().unwrap_or(Value::Unit);
    VECS.with(|v| {
        let mut b = v.borrow_mut();
        b.get_mut(id).ok_or_else(|| format!("vec_push: unknown vec {}", id)).map(|xs| xs.push(item))
    })?;
    Ok(Value::Unit)
}

pub fn host_vec_set(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "vec_set")?;
    let idx = arg_usize(args, 1, "vec_set")?;
    let item = args.get(2).cloned().unwrap_or(Value::Unit);
    VECS.with(|v| {
        let mut b = v.borrow_mut();
        let xs = b.get_mut(id).ok_or_else(|| format!("vec_set: unknown vec {}", id))?;
        if idx >= xs.len() { return Err(format!("vec_set: index {} out of range (len {})", idx, xs.len())); }
        xs[idx] = item;
        Ok(())
    })?;
    Ok(Value::Unit)
}

pub fn host_vec_get(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "vec_get")?;
    let idx = arg_usize(args, 1, "vec_get")?;
    VECS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("vec_get: unknown vec {}", id))
            .map(|xs| xs.get(idx).cloned().unwrap_or(Value::Unit))
    })
}

pub fn host_vec_len(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "vec_len")?;
    VECS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("vec_len: unknown vec {}", id)).map(|xs| Value::Number(xs.len() as f64))
    })
}

pub fn host_vec_to_list(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "vec_to_list")?;
    VECS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("vec_to_list: unknown vec {}", id)).map(|xs| Value::List(xs.clone()))
    })
}

// Interned read-only strings: O(1) handle passing for hot loops (the
// tokenizer indexes the whole source per character; a Value::String local
// would be cloned on every access)
thread_local! {
    static ISTRINGS: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

pub fn host_str_intern(args: &[Value]) -> Result<Value, String> {
    let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let id = ISTRINGS.with(|v| { let mut b = v.borrow_mut(); b.push(s); b.len() - 1 });
    Ok(Value::Number(id as f64))
}

pub fn host_sc_len(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sc_len")?;
    ISTRINGS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("sc_len: unknown string {}", id))
            .map(|s| Value::Number(if s.is_ascii() { s.len() as f64 } else { s.chars().count() as f64 }))
    })
}

pub fn host_sc_code(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sc_code")?;
    let idx = arg_usize(args, 1, "sc_code")?;
    ISTRINGS.with(|v| {
        let b = v.borrow();
        let s = b.get(id).ok_or_else(|| format!("sc_code: unknown string {}", id))?;
        if s.is_ascii() {
            return Ok(Value::Number(match s.as_bytes().get(idx) { Some(c) => *c as f64, None => -1.0 }));
        }
        Ok(Value::Number(match s.chars().nth(idx) { Some(c) => c as u32 as f64, None => -1.0 }))
    })
}

pub fn host_sc_char(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sc_char")?;
    let idx = arg_usize(args, 1, "sc_char")?;
    ISTRINGS.with(|v| {
        let b = v.borrow();
        let s = b.get(id).ok_or_else(|| format!("sc_char: unknown string {}", id))?;
        if s.is_ascii() {
            return Ok(match s.as_bytes().get(idx) { Some(c) => Value::String((*c as char).to_string()), None => Value::String(String::new()) });
        }
        Ok(match s.chars().nth(idx) { Some(c) => Value::String(c.to_string()), None => Value::String(String::new()) })
    })
}

pub fn host_sb_new(_args: &[Value]) -> Result<Value, String> {
    let id = SBUFS.with(|v| { let mut b = v.borrow_mut(); b.push(String::new()); b.len() - 1 });
    Ok(Value::Number(id as f64))
}

pub fn host_sb_push(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sb_push")?;
    let text = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    SBUFS.with(|v| {
        let mut b = v.borrow_mut();
        b.get_mut(id).ok_or_else(|| format!("sb_push: unknown buffer {}", id)).map(|s| s.push_str(&text))
    })?;
    Ok(Value::Unit)
}

pub fn host_sb_str(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sb_str")?;
    SBUFS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("sb_str: unknown buffer {}", id)).map(|s| Value::String(s.clone()))
    })
}

pub fn host_chr(args: &[Value]) -> Result<Value, String> {
    // chr(code) -> 1-char string (empty for invalid code points)
    let n = match args.get(0) { Some(Value::Number(n)) => *n, Some(Value::String(s)) => s.trim().parse::<f64>().unwrap_or(-1.0), _ => -1.0 };
    if n < 0.0 { return Ok(Value::String(String::new())); }
    Ok(Value::String(char::from_u32(n as u32).map(|c| c.to_string()).unwrap_or_default()))
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

pub fn host_write_file(args: &[Value]) -> Result<Value, String> {
    // write_file(path, contents) -> Bool
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let contents = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    if let Some(parent) = std::path::Path::new(&p).parent() { let _ = std::fs::create_dir_all(parent); }
    std::fs::write(&p, contents).map(|_| Value::Bool(true)).map_err(|e| format!("write_file: {}: {}", p, e))
}

pub fn host_now_ms(_args: &[Value]) -> Result<Value, String> {
    // now_ms() -> Number: milliseconds since the Unix epoch (monotonic-enough
    // for self-timing; under the browser WASI shim it maps to performance.now)
    let ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as f64)
        .unwrap_or(0.0);
    Ok(Value::Number(ms))
}

pub fn host_read_file_b64(args: &[Value]) -> Result<Value, String> {
    // read_file_b64(path) -> base64 of the raw bytes (for embedding binary
    // artifacts like .wasm in generated HTML). Builder-side host.
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let data = std::fs::read(&p).map_err(|e| format!("read_file_b64: {}: {}", p, e))?;
    const TBL: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = String::with_capacity((data.len() + 2) / 3 * 4);
    for chunk in data.chunks(3) {
        let b = [chunk[0], *chunk.get(1).unwrap_or(&0), *chunk.get(2).unwrap_or(&0)];
        let n = ((b[0] as u32) << 16) | ((b[1] as u32) << 8) | b[2] as u32;
        out.push(TBL[(n >> 18) as usize & 63] as char);
        out.push(TBL[(n >> 12) as usize & 63] as char);
        out.push(if chunk.len() > 1 { TBL[(n >> 6) as usize & 63] as char } else { '=' });
        out.push(if chunk.len() > 2 { TBL[n as usize & 63] as char } else { '=' });
    }
    Ok(Value::String(out))
}

pub fn host_exec_capture(args: &[Value]) -> Result<Value, String> {
    // exec_capture(path) -> stdout of running the program (no arguments).
    // Builder-side host for capturing native transcripts of compiled demos.
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("exec_capture: expected program path".into()) };
    let out = std::process::Command::new(&p).output().map_err(|e| format!("exec_capture: {}: {}", p, e))?;
    Ok(Value::String(String::from_utf8_lossy(&out.stdout).to_string()))
}

pub fn host_argv(args: &[Value]) -> Result<Value, String> {
    // argv() -> List of program arguments, normalized so the same PatLang code
    // works interpreted (`pat --ir-run script.patlang a b`) and compiled
    // (`prog.exe a b`): the runner exe, mode flags, and the script path are
    // stripped, leaving just the user arguments.
    let _ = args;
    let mut rest: Vec<String> = std::env::args().collect();
    if !rest.is_empty() { rest.remove(0); } // drop runner exe
    // drop a leading mode flag and the script path when running under pat
    if matches!(rest.first().map(|s| s.as_str()), Some("--ir-run") | Some("--build-run") | Some("--patc") | Some("--emit-rust") | Some("--compare")) {
        rest.remove(0);
        if !rest.is_empty() { rest.remove(0); } // script path
    }
    Ok(Value::List(rest.into_iter().map(Value::String).collect()))
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
        // String receiver reads from the named-object store (OO style), matching
        // the codegen template's `get` arm
        Value::String(name) => Ok(obj_get(name, &key).unwrap_or(Value::Unit)),
        Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
        _ => Ok(Value::Unit),
    }
}

// --- OO + logic state (mirrors the thread-locals in the codegen template) ---

use std::cell::RefCell;
use std::collections::HashMap;

thread_local! {
    static OBJECTS: RefCell<HashMap<String, HashMap<String, Value>>> = RefCell::new(HashMap::new());
    static FACTS: RefCell<HashMap<String, Vec<(String, String)>>> = RefCell::new(HashMap::new());
    static GOALS: RefCell<Vec<(String, Vec<String>)>> = RefCell::new(Vec::new());
}

fn obj_get(name: &str, prop: &str) -> Option<Value> {
    OBJECTS.with(|o| o.borrow().get(name).and_then(|m| m.get(prop)).cloned())
}

fn obj_set(name: &str, prop: &str, val: Value) {
    OBJECTS.with(|o| {
        let mut b = o.borrow_mut();
        b.entry(name.to_string()).or_insert_with(HashMap::new).insert(prop.to_string(), val);
    });
}

fn ensure_obj(name: &str, class: &str) {
    obj_set(name, "type", Value::String(class.to_string()));
    obj_set(name, "name", Value::String(name.to_string()));
}

/// Reset OO/logic state — call between independent runs (tests).
pub fn reset_world() {
    OBJECTS.with(|o| o.borrow_mut().clear());
    FACTS.with(|f| f.borrow_mut().clear());
    GOALS.with(|g| g.borrow_mut().clear());
}

fn to_s(v: &Value) -> String { display_value(v) }

pub fn host_fact(args: &[Value]) -> Result<Value, String> {
    // fact(pred, a, b) records a binary fact
    if args.len() != 3 { return Ok(Value::Unit); }
    let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let a = to_s(&args[1]);
    let b = to_s(&args[2]);
    FACTS.with(|f| f.borrow_mut().entry(pred).or_insert_with(Vec::new).push((a, b)));
    Ok(Value::Unit)
}

pub fn host_query(args: &[Value]) -> Result<Value, String> {
    // query(pred, a, _) -> Number of facts matching (pred, a, *)
    if args.len() != 3 { return Ok(Value::Number(0.0)); }
    let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let a = to_s(&args[1]);
    let count = FACTS.with(|f| {
        f.borrow().get(&pred).map(|v| v.iter().filter(|(x, _)| x == &a).count()).unwrap_or(0)
    });
    Ok(Value::Number(count as f64))
}

pub fn host_goal(args: &[Value]) -> Result<Value, String> {
    // goal(pred, items...) records a pending goal
    if args.is_empty() { return Ok(Value::Unit); }
    let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let items: Vec<String> = args[1..].iter().map(to_s).collect();
    GOALS.with(|g| g.borrow_mut().push((pred, items)));
    Ok(Value::Unit)
}

pub fn host_new(args: &[Value]) -> Result<Value, String> {
    // new(class, name) -> name, registering the object
    if args.len() != 2 { return Ok(Value::Unit); }
    let class = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let name = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
    if !name.is_empty() { ensure_obj(&name, &class); }
    Ok(Value::String(name))
}

pub fn host_set_var(args: &[Value]) -> Result<Value, String> {
    // set_var(key, val) stores into the shared __vars object
    if args.len() != 2 { return Ok(Value::Unit); }
    let key = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    if !key.is_empty() { obj_set("__vars", &key, args[1].clone()); }
    Ok(Value::Unit)
}

pub fn host_send(args: &[Value]) -> Result<Value, String> {
    // send(recv, method, args...) — supports "set" like the template arm
    if args.len() < 2 { return Ok(Value::Unit); }
    let recv = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let method = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
    let rest = &args[2..];
    match method.as_str() {
        "set" => {
            if rest.len() != 2 { return Ok(Value::Unit); }
            let prop = match &rest[0] { Value::String(s) => s.clone(), _ => String::new() };
            if !recv.is_empty() && !prop.is_empty() { obj_set(&recv, &prop, rest[1].clone()); }
            Ok(Value::Unit)
        }
        _ => Ok(Value::Unit),
    }
}

// --- AST-shape lowering: list-shaped AST (from the self-hosted parser) → IR Program ---
// Shape grammar:
//   ["Program", [stmts]]
//   ["Let", name, expr] | ["Print", expr]
//   ["Num", text] | ["Str", text] | ["Var", name] | ["Bin", op, lhs, rhs]

use super::types::{Program, Function, Instr, BinOpKind, UnOpKind};

fn shape_list(v: &Value) -> Result<&Vec<Value>, String> {
    match v { Value::List(xs) => Ok(xs), _ => Err(format!("compile_shape: expected list node, got {}", display_value(v))) }
}

fn shape_tag(xs: &[Value]) -> Result<&str, String> {
    match xs.get(0) { Some(Value::String(s)) => Ok(s.as_str()), _ => Err("compile_shape: node missing tag".into()) }
}

fn shape_str(xs: &[Value], i: usize, what: &str) -> Result<String, String> {
    match xs.get(i) { Some(Value::String(s)) => Ok(s.clone()), _ => Err(format!("compile_shape: expected string {} in node", what)) }
}

fn shape_stmt_list<'a>(xs: &'a [Value], i: usize, what: &str) -> Result<&'a Vec<Value>, String> {
    match xs.get(i) { Some(Value::List(s)) => Ok(s), _ => Err(format!("compile_shape: expected statement list {}", what)) }
}

struct ShapeCtx {
    user_fns: std::collections::HashSet<String>,
}

fn lower_shape_expr(v: &Value, f: &mut Function, ctx: &ShapeCtx) -> Result<(), String> {
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
        "Bool" => {
            let text = shape_str(xs, 1, "bool text")?;
            f.body.push(Instr::Const(Value::Bool(text == "true")));
        }
        "Var" => {
            let name = shape_str(xs, 1, "variable name")?;
            f.body.push(Instr::LoadLocal(name));
        }
        "Bin" => {
            let op = shape_str(xs, 1, "operator")?;
            let lhs = xs.get(2).ok_or("compile_shape: Bin missing lhs")?;
            let rhs = xs.get(3).ok_or("compile_shape: Bin missing rhs")?;
            lower_shape_expr(lhs, f, ctx)?;
            lower_shape_expr(rhs, f, ctx)?;
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
                // Note: unlike the Stage 0 lowerer these do not short-circuit;
                // both operands are evaluated, then combined by truthiness.
                "and" => BinOpKind::And,
                "or" => BinOpKind::Or,
                other => return Err(format!("compile_shape: unknown operator '{}'", other)),
            };
            f.body.push(Instr::BinOp(kind));
        }
        "Un" => {
            let op = shape_str(xs, 1, "unary operator")?;
            let e = xs.get(2).ok_or("compile_shape: Un missing operand")?;
            lower_shape_expr(e, f, ctx)?;
            match op.as_str() {
                "-" => f.body.push(Instr::UnOp(UnOpKind::Neg)),
                "not" => f.body.push(Instr::UnOp(UnOpKind::Not)),
                other => return Err(format!("compile_shape: unknown unary operator '{}'", other)),
            }
        }
        "Call" => {
            let name = shape_str(xs, 1, "call name")?;
            let args = shape_stmt_list(xs, 2, "in Call")?;
            for a in args { lower_shape_expr(a, f, ctx)?; }
            if ctx.user_fns.contains(&name) {
                f.body.push(Instr::Call(name, args.len()));
            } else {
                f.body.push(Instr::CallHost(name, args.len()));
            }
        }
        "List" => {
            let items = shape_stmt_list(xs, 1, "in List")?;
            for it in items { lower_shape_expr(it, f, ctx)?; }
            f.body.push(Instr::BuildList(items.len()));
        }
        "Index" => {
            let obj = xs.get(1).ok_or("compile_shape: Index missing object")?;
            let idx = xs.get(2).ok_or("compile_shape: Index missing index")?;
            lower_shape_expr(obj, f, ctx)?;
            lower_shape_expr(idx, f, ctx)?;
            f.body.push(Instr::CallHost("list_get".into(), 2));
        }
        "Member" => {
            let obj = xs.get(1).ok_or("compile_shape: Member missing object")?;
            let prop = shape_str(xs, 2, "member name")?;
            lower_shape_expr(obj, f, ctx)?;
            if prop == "length" || prop == "len" {
                f.body.push(Instr::CallHost("len".into(), 1));
            } else {
                f.body.push(Instr::Const(Value::String(prop)));
                f.body.push(Instr::CallHost("get".into(), 2));
            }
        }
        other => return Err(format!("compile_shape: unknown expr node '{}'", other)),
    }
    Ok(())
}

fn lower_shape_stmt(v: &Value, f: &mut Function, ctx: &ShapeCtx) -> Result<(), String> {
    let xs = shape_list(v)?;
    match shape_tag(xs)? {
        "Let" => {
            let name = shape_str(xs, 1, "let name")?;
            let expr = xs.get(2).ok_or("compile_shape: Let missing expr")?;
            lower_shape_expr(expr, f, ctx)?;
            f.body.push(Instr::StoreLocal(name));
        }
        "Print" => {
            // legacy alias for ["Expr", ["Call", "print", [e]]]
            let expr = xs.get(1).ok_or("compile_shape: Print missing expr")?;
            lower_shape_expr(expr, f, ctx)?;
            f.body.push(Instr::CallHost("print".into(), 1));
        }
        "Expr" => {
            let expr = xs.get(1).ok_or("compile_shape: Expr missing expr")?;
            lower_shape_expr(expr, f, ctx)?;
        }
        "Return" => {
            let expr = xs.get(1).ok_or("compile_shape: Return missing expr")?;
            lower_shape_expr(expr, f, ctx)?;
            f.body.push(Instr::Return);
        }
        "If" => {
            let cond = xs.get(1).ok_or("compile_shape: If missing cond")?;
            let then_stmts = shape_stmt_list(xs, 2, "in If then-branch")?;
            let else_stmts = shape_stmt_list(xs, 3, "in If else-branch")?;
            lower_shape_expr(cond, f, ctx)?;
            let jif_idx = f.body.len();
            f.body.push(Instr::JumpIfFalse(usize::MAX));
            for s in then_stmts { lower_shape_stmt(s, f, ctx)?; }
            let jmp_idx = f.body.len();
            f.body.push(Instr::Jump(usize::MAX));
            let else_pc = f.body.len();
            if let Instr::JumpIfFalse(ref mut t) = f.body[jif_idx] { *t = else_pc; }
            for s in else_stmts { lower_shape_stmt(s, f, ctx)?; }
            let after = f.body.len();
            if let Instr::Jump(ref mut t) = f.body[jmp_idx] { *t = after; }
        }
        "While" => {
            let cond = xs.get(1).ok_or("compile_shape: While missing cond")?;
            let body = shape_stmt_list(xs, 2, "in While body")?;
            let loop_start = f.body.len();
            lower_shape_expr(cond, f, ctx)?;
            let jif_idx = f.body.len();
            f.body.push(Instr::JumpIfFalse(usize::MAX));
            for s in body { lower_shape_stmt(s, f, ctx)?; }
            f.body.push(Instr::Jump(loop_start));
            let after = f.body.len();
            if let Instr::JumpIfFalse(ref mut t) = f.body[jif_idx] { *t = after; }
        }
        "Err" => {
            return Err(format!("compile_shape: parse error node: {}", shape_str(xs, 1, "message").unwrap_or_default()));
        }
        other => return Err(format!("compile_shape: unknown stmt node '{}'", other)),
    }
    Ok(())
}

/// Convert a list-shaped AST into an IR Program: Func nodes become functions,
/// When nodes become event handlers, everything else lowers into main.
pub fn shape_to_program(v: &Value) -> Result<Program, String> {
    let xs = shape_list(v)?;
    if shape_tag(xs)? != "Program" { return Err("compile_shape: root node must be Program".into()); }
    let stmts = match xs.get(1) { Some(Value::List(s)) => s, _ => return Err("compile_shape: Program missing statement list".into()) };

    // Pass 1: collect user function names so calls lower to Call, not CallHost
    let mut ctx = ShapeCtx { user_fns: std::collections::HashSet::new() };
    for s in stmts {
        if let Ok(nx) = shape_list(s) {
            if shape_tag(nx) == Ok("Func") {
                ctx.user_fns.insert(shape_str(nx, 1, "function name")?);
            }
        }
    }

    let mut program = Program::default();
    program.entry = "main".into();
    let mut main_fn = Function { name: "main".into(), ..Default::default() };
    let mut handler_counter = 0usize;

    for s in stmts {
        let nx = shape_list(s)?;
        match shape_tag(nx)? {
            "Func" => {
                let name = shape_str(nx, 1, "function name")?;
                let params: Vec<String> = match nx.get(2) {
                    Some(Value::List(ps)) => ps.iter().map(|p| match p {
                        Value::String(s) => Ok(s.clone()),
                        _ => Err("compile_shape: function param must be a string".to_string()),
                    }).collect::<Result<_, _>>()?,
                    _ => return Err("compile_shape: Func missing params".into()),
                };
                let body = shape_stmt_list(nx, 3, "in Func body")?;
                let mut f = Function { name: name.clone(), params, ..Default::default() };
                for st in body { lower_shape_stmt(st, &mut f, &ctx)?; }
                f.body.push(Instr::Return);
                program.functions.insert(name, f);
            }
            "When" => {
                let event = shape_str(nx, 1, "event name")?;
                let body = shape_stmt_list(nx, 2, "in When body")?;
                handler_counter += 1;
                let hname = format!("__when_{}_{}", event, handler_counter);
                let mut hf = Function {
                    name: hname.clone(),
                    params: vec!["event_name".into(), "event_data".into()],
                    ..Default::default()
                };
                for st in body { lower_shape_stmt(st, &mut hf, &ctx)?; }
                hf.body.push(Instr::Return);
                program.functions.insert(hname.clone(), hf);
                program.event_handlers.entry(event).or_default().push(hname);
            }
            _ => lower_shape_stmt(s, &mut main_fn, &ctx)?,
        }
    }
    main_fn.body.push(Instr::Return);
    program.functions.insert("main".into(), main_fn);
    Ok(program)
}

/// Shared tail: write Rust source to a temp file and compile it with rustc.
/// `target`: optional rustc target triple (e.g. "wasm32-wasip1").
fn compile_source_to_exe(rust_src: &str, out: &str, what: &str, target: Option<&str>) -> Result<Value, String> {
    use std::sync::atomic::{AtomicUsize, Ordering};
    static SEQ: AtomicUsize = AtomicUsize::new(0);
    let mut tmp = std::env::temp_dir();
    tmp.push("patlang_shape_compile");
    std::fs::create_dir_all(&tmp).map_err(|e| format!("{}: temp dir: {}", what, e))?;
    // Unique per process+invocation: parallel test threads must not clobber
    // each other's source while rustc is reading it
    let src_path = tmp.join(format!(
        "shape_main_{}_{}.rs",
        std::process::id(),
        SEQ.fetch_add(1, Ordering::Relaxed)
    ));
    std::fs::write(&src_path, rust_src).map_err(|e| format!("{}: write {}: {}", what, src_path.display(), e))?;

    if let Some(parent) = std::path::Path::new(out).parent() { let _ = std::fs::create_dir_all(parent); }
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let mut cmd = std::process::Command::new(&rustc);
    cmd.arg("-O").arg(&src_path).arg("-o").arg(out);
    if let Some(t) = target { cmd.arg("--target").arg(t); }
    let status = cmd.status().map_err(|e| format!("{}: failed to run rustc: {}", what, e))?;
    if !status.success() { return Err(format!("{}: rustc failed with status {}", what, status)); }
    let p = std::path::Path::new(out);
    let abs = std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf());
    Ok(Value::String(abs.display().to_string()))
}

/// Shared back half: emit Rust for a Program and compile it with rustc.
fn compile_program_to_exe(program: &Program, out: &str, what: &str) -> Result<Value, String> {
    let cg = super::codegen::RustCodegen::new();
    let rust_src = cg.emit_rust(program);
    compile_source_to_exe(&rust_src, out, what, None)
}

/// codegen_prelude() -> the static runtime library text embedded in every
/// emitted program. Self-hosted codegen concatenates this with its own
/// generated build_program section.
pub fn host_codegen_prelude(_args: &[Value]) -> Result<Value, String> {
    Ok(Value::String(super::codegen::RustCodegen::prelude().to_string()))
}

/// rustc_build(rust_source, out_path[, target_triple]) -> compiled artifact path.
/// The dumbest possible back end: write the given Rust source and run rustc.
/// Pass a target triple (e.g. "wasm32-wasip1") to cross-compile.
pub fn host_rustc_build(args: &[Value]) -> Result<Value, String> {
    let src = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("rustc_build: expected Rust source string".into()) };
    let out = match args.get(1) {
        Some(Value::String(s)) if !s.trim().is_empty() => s.clone(),
        _ => return Err("rustc_build: expected output path as second argument".into()),
    };
    let target = match args.get(2) { Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()), _ => None };
    compile_source_to_exe(&src, &out, "rustc_build", target.as_deref())
}

/// compile_shape(ast_shape, out_path) -> compiled exe path.
/// Lowers the list-shaped AST to IR (host-side), emits Rust, compiles with rustc.
pub fn host_compile_shape(args: &[Value]) -> Result<Value, String> {
    let shape = args.get(0).ok_or("compile_shape: expected AST shape")?;
    let out = match args.get(1) {
        Some(Value::String(s)) if !s.trim().is_empty() => s.clone(),
        _ => return Err("compile_shape: expected output path as second argument".into()),
    };
    let program = shape_to_program(shape)?;
    compile_program_to_exe(&program, &out, "compile_shape")
}

// --- IR-shape decoding: list-shaped IR produced by the PatLang lowerer ---
// ["ProgramIR", entry, [functions], [events]]
//   function: ["FuncIR", name, [param strings], [instrs]]
//   event:    ["EventIR", event_name, handler_fn_name]
//   instr:    ["Const", "num"|"str"|"bool", text] | ["Load", name] | ["Store", name]
//             ["Bin", op] | ["Un", op] | ["Jump", n] | ["JumpIfFalse", n]
//             ["CallHost", name, argc] | ["Call", name, argc]
//             ["BuildList", n] | ["Return"]

fn shape_num(xs: &[Value], i: usize, what: &str) -> Result<f64, String> {
    match xs.get(i) {
        Some(Value::Number(n)) => Ok(*n),
        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| format!("compile_ir: expected number {}", what)),
        _ => Err(format!("compile_ir: expected number {}", what)),
    }
}

fn decode_ir_instr(v: &Value) -> Result<Instr, String> {
    let xs = shape_list(v)?;
    let instr = match shape_tag(xs)? {
        "Const" => {
            let kind = shape_str(xs, 1, "const kind")?;
            let text = shape_str(xs, 2, "const text")?;
            let val = match kind.as_str() {
                "num" => Value::Number(text.trim().parse::<f64>().map_err(|_| format!("compile_ir: bad number '{}'", text))?),
                "str" => Value::String(text),
                "bool" => Value::Bool(text == "true"),
                other => return Err(format!("compile_ir: unknown const kind '{}'", other)),
            };
            Instr::Const(val)
        }
        "Load" => Instr::LoadLocal(shape_str(xs, 1, "load name")?),
        "Store" => Instr::StoreLocal(shape_str(xs, 1, "store name")?),
        "Bin" => {
            let op = shape_str(xs, 1, "bin op")?;
            let kind = match op.as_str() {
                "+" => BinOpKind::Add, "-" => BinOpKind::Sub, "*" => BinOpKind::Mul,
                "/" => BinOpKind::Div, "%" => BinOpKind::Mod,
                "==" => BinOpKind::Eq, "!=" => BinOpKind::Ne,
                "<" => BinOpKind::Lt, "<=" => BinOpKind::Le,
                ">" => BinOpKind::Gt, ">=" => BinOpKind::Ge,
                "and" => BinOpKind::And, "or" => BinOpKind::Or,
                other => return Err(format!("compile_ir: unknown bin op '{}'", other)),
            };
            Instr::BinOp(kind)
        }
        "Un" => {
            let op = shape_str(xs, 1, "un op")?;
            match op.as_str() {
                "-" => Instr::UnOp(UnOpKind::Neg),
                "not" => Instr::UnOp(UnOpKind::Not),
                other => return Err(format!("compile_ir: unknown unary op '{}'", other)),
            }
        }
        "Jump" => Instr::Jump(shape_num(xs, 1, "jump target")? as usize),
        "JumpIfFalse" => Instr::JumpIfFalse(shape_num(xs, 1, "jump target")? as usize),
        "CallHost" => Instr::CallHost(shape_str(xs, 1, "host name")?, shape_num(xs, 2, "argc")? as usize),
        "Call" => Instr::Call(shape_str(xs, 1, "function name")?, shape_num(xs, 2, "argc")? as usize),
        "BuildList" => Instr::BuildList(shape_num(xs, 1, "count")? as usize),
        "Return" => Instr::Return,
        other => return Err(format!("compile_ir: unknown instruction '{}'", other)),
    };
    Ok(instr)
}

/// Convert a list-shaped IR (produced by the PatLang lowerer) into a Program.
pub fn ir_shape_to_program(v: &Value) -> Result<Program, String> {
    let xs = shape_list(v)?;
    if shape_tag(xs)? != "ProgramIR" { return Err("compile_ir: root node must be ProgramIR".into()); }
    let entry = shape_str(xs, 1, "entry name")?;
    let funcs = shape_stmt_list(xs, 2, "in ProgramIR functions")?;
    let events = shape_stmt_list(xs, 3, "in ProgramIR events")?;

    let mut program = Program::default();
    program.entry = entry;
    for fv in funcs {
        let fx = shape_list(fv)?;
        if shape_tag(fx)? != "FuncIR" { return Err("compile_ir: expected FuncIR node".into()); }
        let name = shape_str(fx, 1, "function name")?;
        let params: Vec<String> = match fx.get(2) {
            Some(Value::List(ps)) => ps.iter().map(|p| match p {
                Value::String(s) => Ok(s.clone()),
                _ => Err("compile_ir: param must be a string".to_string()),
            }).collect::<Result<_, _>>()?,
            _ => return Err("compile_ir: FuncIR missing params".into()),
        };
        let instrs = shape_stmt_list(fx, 3, "in FuncIR body")?;
        let mut f = Function { name: name.clone(), params, ..Default::default() };
        for iv in instrs { f.body.push(decode_ir_instr(iv)?); }
        program.functions.insert(name, f);
    }
    for ev in events {
        let ex = shape_list(ev)?;
        if shape_tag(ex)? != "EventIR" { return Err("compile_ir: expected EventIR node".into()); }
        let event = shape_str(ex, 1, "event name")?;
        let handler = shape_str(ex, 2, "handler name")?;
        program.event_handlers.entry(event).or_default().push(handler);
    }
    Ok(program)
}

/// compile_ir(ir_shape, out_path) -> compiled exe path.
/// The lowering has already happened in PatLang; this only decodes the IR
/// shape, emits Rust, and runs rustc.
pub fn host_compile_ir(args: &[Value]) -> Result<Value, String> {
    let shape = args.get(0).ok_or("compile_ir: expected IR shape")?;
    let out = match args.get(1) {
        Some(Value::String(s)) if !s.trim().is_empty() => s.clone(),
        _ => return Err("compile_ir: expected output path as second argument".into()),
    };
    let program = ir_shape_to_program(shape)?;
    compile_program_to_exe(&program, &out, "compile_ir")
}

// --- Networking hosts (blocking TCP; async/event-loop model is future work) ---
// tcp_listen(port) -> Number actual bound port (use 0 for OS-assigned)
// tcp_accept(port) -> Number connection id (blocks)
// tcp_read(conn)   -> String (single read, up to 64 KiB, lossy UTF-8)
// tcp_write(conn, data) -> Bool
// tcp_close(conn)  -> Unit

thread_local! {
    static LISTENERS: RefCell<HashMap<u16, std::net::TcpListener>> = RefCell::new(HashMap::new());
    static CONNS: RefCell<HashMap<usize, std::net::TcpStream>> = RefCell::new(HashMap::new());
    static NEXT_CONN: RefCell<usize> = RefCell::new(1);
}

fn arg_num(args: &[Value], i: usize, what: &str) -> Result<f64, String> {
    match args.get(i) {
        Some(Value::Number(n)) => Ok(*n),
        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| format!("{}: expected number", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

pub fn host_tcp_listen(args: &[Value]) -> Result<Value, String> {
    let port = arg_num(args, 0, "tcp_listen")? as u16;
    let listener = std::net::TcpListener::bind(("127.0.0.1", port))
        .map_err(|e| format!("tcp_listen: bind {}: {}", port, e))?;
    let actual = listener.local_addr().map_err(|e| format!("tcp_listen: {}", e))?.port();
    LISTENERS.with(|l| l.borrow_mut().insert(actual, listener));
    Ok(Value::Number(actual as f64))
}

pub fn host_tcp_accept(args: &[Value]) -> Result<Value, String> {
    let port = arg_num(args, 0, "tcp_accept")? as u16;
    let listener = LISTENERS.with(|l| {
        l.borrow().get(&port).map(|x| x.try_clone())
    }).ok_or_else(|| format!("tcp_accept: no listener on port {}", port))?
        .map_err(|e| format!("tcp_accept: {}", e))?;
    let (stream, _) = listener.accept().map_err(|e| format!("tcp_accept: {}", e))?;
    let id = NEXT_CONN.with(|n| { let mut b = n.borrow_mut(); let v = *b; *b += 1; v });
    CONNS.with(|c| c.borrow_mut().insert(id, stream));
    Ok(Value::Number(id as f64))
}

pub fn host_sleep_ms(args: &[Value]) -> Result<Value, String> {
    let ms = arg_num(args, 0, "sleep_ms")?.max(0.0) as u64;
    std::thread::sleep(std::time::Duration::from_millis(ms));
    Ok(Value::Unit)
}

pub fn host_tcp_accept_timeout(args: &[Value]) -> Result<Value, String> {
    // tcp_accept_timeout(port, ms) -> conn id, or -1 if nothing arrived in
    // time. The non-blocking primitive under PatLang event loops.
    let port = arg_num(args, 0, "tcp_accept_timeout")? as u16;
    let ms = arg_num(args, 1, "tcp_accept_timeout")?.max(0.0) as u64;
    let listener = LISTENERS.with(|l| l.borrow().get(&port).map(|x| x.try_clone()))
        .ok_or_else(|| format!("tcp_accept_timeout: no listener on port {}", port))?
        .map_err(|e| format!("tcp_accept_timeout: {}", e))?;
    listener.set_nonblocking(true).map_err(|e| format!("tcp_accept_timeout: {}", e))?;
    let deadline = std::time::Instant::now() + std::time::Duration::from_millis(ms);
    loop {
        match listener.accept() {
            Ok((stream, _)) => {
                let _ = stream.set_nonblocking(false);
                let id = NEXT_CONN.with(|n| { let mut b = n.borrow_mut(); let v = *b; *b += 1; v });
                CONNS.with(|c| c.borrow_mut().insert(id, stream));
                return Ok(Value::Number(id as f64));
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                if std::time::Instant::now() >= deadline { return Ok(Value::Number(-1.0)); }
                std::thread::sleep(std::time::Duration::from_millis(2));
            }
            Err(e) => return Err(format!("tcp_accept_timeout: {}", e)),
        }
    }
}

pub fn host_tcp_read(args: &[Value]) -> Result<Value, String> {
    use std::io::Read;
    let id = arg_num(args, 0, "tcp_read")? as usize;
    let mut stream = CONNS.with(|c| c.borrow().get(&id).map(|s| s.try_clone()))
        .ok_or_else(|| format!("tcp_read: unknown connection {}", id))?
        .map_err(|e| format!("tcp_read: {}", e))?;
    let mut buf = vec![0u8; 65536];
    let n = stream.read(&mut buf).map_err(|e| format!("tcp_read: {}", e))?;
    Ok(Value::String(String::from_utf8_lossy(&buf[..n]).to_string()))
}

pub fn host_tcp_write(args: &[Value]) -> Result<Value, String> {
    use std::io::Write;
    let id = arg_num(args, 0, "tcp_write")? as usize;
    let data = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let mut stream = CONNS.with(|c| c.borrow().get(&id).map(|s| s.try_clone()))
        .ok_or_else(|| format!("tcp_write: unknown connection {}", id))?
        .map_err(|e| format!("tcp_write: {}", e))?;
    stream.write_all(data.as_bytes()).map_err(|e| format!("tcp_write: {}", e))?;
    let _ = stream.flush();
    Ok(Value::Bool(true))
}

pub fn host_tcp_close(args: &[Value]) -> Result<Value, String> {
    use std::io::Read;
    let id = arg_num(args, 0, "tcp_close")? as usize;
    if let Some(stream) = CONNS.with(|c| c.borrow_mut().remove(&id)) {
        // Drain any unread inbound bytes and half-close, so the peer receives
        // a graceful FIN instead of an RST that could clobber our response
        let _ = stream.set_nonblocking(true);
        let mut sink = [0u8; 4096];
        let mut s = stream;
        loop {
            match s.read(&mut sink) {
                Ok(0) => break,
                Ok(_) => continue,
                Err(_) => break,
            }
        }
        let _ = s.shutdown(std::net::Shutdown::Write);
    }
    Ok(Value::Unit)
}

/// Register the Stage 0 string/list/file shims on an interpreter.
pub fn register_stage0_shims(interp: &mut Interpreter) {
    interp.host.insert("len", host_len);
    interp.host.insert("get", host_get);
    interp.host.insert("list_get", host_list_get);
    interp.host.insert("list_len", host_list_len);
    interp.host.insert("list_push", host_list_push);
    interp.host.insert("list_set", host_list_set);
    interp.host.insert("vec_new", host_vec_new);
    interp.host.insert("vec_push", host_vec_push);
    interp.host.insert("vec_set", host_vec_set);
    interp.host.insert("vec_get", host_vec_get);
    interp.host.insert("vec_len", host_vec_len);
    interp.host.insert("vec_to_list", host_vec_to_list);
    interp.host.insert("sb_new", host_sb_new);
    interp.host.insert("sb_push", host_sb_push);
    interp.host.insert("sb_str", host_sb_str);
    interp.host.insert("str_intern", host_str_intern);
    interp.host.insert("sc_len", host_sc_len);
    interp.host.insert("sc_code", host_sc_code);
    interp.host.insert("sc_char", host_sc_char);
    interp.host.insert("char_code", host_char_code);
    interp.host.insert("substr", host_substr);
    interp.host.insert("chr", host_chr);
    interp.host.insert("to_num", host_to_num);
    interp.host.insert("read_file", host_read_file);
    interp.host.insert("write_file", host_write_file);
    interp.host.insert("argv", host_argv);
    interp.host.insert("now_ms", host_now_ms);
    interp.host.insert("read_file_b64", host_read_file_b64);
    interp.host.insert("exec_capture", host_exec_capture);
    interp.host.insert("compile_shape", host_compile_shape);
    interp.host.insert("compile_ir", host_compile_ir);
    interp.host.insert("codegen_prelude", host_codegen_prelude);
    interp.host.insert("rustc_build", host_rustc_build);
    // OO + logic hosts (state shared per thread, matching compiled semantics)
    interp.host.insert("fact", host_fact);
    interp.host.insert("query", host_query);
    interp.host.insert("goal", host_goal);
    interp.host.insert("new", host_new);
    interp.host.insert("set_var", host_set_var);
    interp.host.insert("send", host_send);
    // networking
    interp.host.insert("tcp_listen", host_tcp_listen);
    interp.host.insert("tcp_accept", host_tcp_accept);
    interp.host.insert("tcp_accept_timeout", host_tcp_accept_timeout);
    interp.host.insert("sleep_ms", host_sleep_ms);
    interp.host.insert("tcp_read", host_tcp_read);
    interp.host.insert("tcp_write", host_tcp_write);
    interp.host.insert("tcp_close", host_tcp_close);
}
