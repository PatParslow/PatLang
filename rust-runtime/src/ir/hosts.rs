//! Shared Stage 0 host shims for the IR interpreter.
//! Kept in sync with the arms in the codegen template so interpreted and
//! compiled programs observe the same host semantics.

use super::interpreter::Interpreter;
use super::types::Value;
use super::ops::{self, v_to_string, as_index};
use super::numeric::{normalize, make_rational};
use num_bigint::BigInt;

// Kept as a thin wrapper: delegates to ops::v_to_string so display formatting
// stays in one place across the numeric tower's new variants.
fn display_value(v: &Value) -> String {
    v_to_string(v)
}

// Best-effort index extraction for the ad hoc `Value::Number(n) => *n as
// usize, Value::String(s) => ..., _ => usize::MAX` call sites below: unlike
// `as_index` (which errors on bad input), these sites historically fell back
// to usize::MAX / 0 rather than propagating an error, so we preserve that by
// treating an as_index error as the same fallback the String-parse arm uses.
fn number_or_max(v: &Value) -> Option<usize> { as_index(v).ok() }

// `print` isn't part of register_stage0_shims's set below historically --
// main.rs's --ir-run mode registers its own local `ir_host_print` directly
// on the top-level Interpreter instead. That means any code that spawns a
// *fresh* Interpreter and only calls register_stage0_shims (fiber_new's and
// parallel_map's worker threads) doesn't have `print` available at all,
// which surfaces as a confusing "host fn 'print' not found" the first time
// fiber/budgeted-block code tries to print. Registered here so every
// shims-only interpreter gets it too.
pub fn host_print(args: &[Value]) -> Result<Value, String> {
    if let Some(arg0) = args.get(0) {
        println!("{}", display_value(arg0));
    } else {
        println!();
    }
    Ok(Value::Unit)
}

pub fn host_list_get(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("list_get: expected 2 args".into()); }
    let idx = match &args[1] { Value::String(s) => s.parse::<usize>().unwrap_or(usize::MAX), v => number_or_max(v).unwrap_or(usize::MAX) };
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
    let idx = match &args[1] { Value::String(s) => s.parse::<usize>().unwrap_or(usize::MAX), v => number_or_max(v).unwrap_or(usize::MAX) };
    if idx >= xs.len() { return Err(format!("list_set: index {} out of range (len {})", idx, xs.len())); }
    xs[idx] = args[2].clone();
    Ok(Value::List(xs))
}

pub fn host_char_code(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("char_code: expected 2 args".into()); }
    let s = match &args[0] { Value::String(s) => s.clone(), v => display_value(v) };
    let idx = match &args[1] { Value::String(t) => t.parse::<usize>().unwrap_or(usize::MAX), v => number_or_max(v).unwrap_or(usize::MAX) };
    if s.is_ascii() {
        return Ok(Value::Int(match s.as_bytes().get(idx) { Some(b) => *b as i64, None => -1 }));
    }
    match s.chars().nth(idx) {
        Some(c) => Ok(Value::Int(c as u32 as i64)),
        None => Ok(Value::Int(-1)),
    }
}

pub fn host_substr(args: &[Value]) -> Result<Value, String> {
    if args.len() != 3 { return Err("substr: expected 3 args".into()); }
    let s = match &args[0] { Value::String(s) => s.clone(), v => display_value(v) };
    let start = match &args[1] { Value::String(t) => t.parse::<usize>().unwrap_or(0), v => number_or_max(v).unwrap_or(0) };
    let count = match &args[2] { Value::String(t) => t.parse::<usize>().unwrap_or(0), v => number_or_max(v).unwrap_or(0) };
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
        Some(Value::String(s)) => s.trim().parse::<usize>().map_err(|_| format!("{}: expected index", what)),
        Some(v) => as_index(v).map_err(|_| format!("{}: expected number", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

pub fn host_vec_new(_args: &[Value]) -> Result<Value, String> {
    let id = VECS.with(|v| { let mut b = v.borrow_mut(); b.push(Vec::new()); b.len() - 1 });
    Ok(Value::Int(id as i64))
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
        b.get(id).ok_or_else(|| format!("vec_len: unknown vec {}", id)).map(|xs| Value::Int(xs.len() as i64))
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
    Ok(Value::Int(id as i64))
}

pub fn host_sc_len(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sc_len")?;
    ISTRINGS.with(|v| {
        let b = v.borrow();
        b.get(id).ok_or_else(|| format!("sc_len: unknown string {}", id))
            .map(|s| Value::Int(if s.is_ascii() { s.len() as i64 } else { s.chars().count() as i64 }))
    })
}

pub fn host_sc_code(args: &[Value]) -> Result<Value, String> {
    let id = arg_usize(args, 0, "sc_code")?;
    let idx = arg_usize(args, 1, "sc_code")?;
    ISTRINGS.with(|v| {
        let b = v.borrow();
        let s = b.get(id).ok_or_else(|| format!("sc_code: unknown string {}", id))?;
        if s.is_ascii() {
            return Ok(Value::Int(match s.as_bytes().get(idx) { Some(c) => *c as i64, None => -1 }));
        }
        Ok(Value::Int(match s.chars().nth(idx) { Some(c) => c as u32 as i64, None => -1 }))
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
    Ok(Value::Int(id as i64))
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
    let n = match args.get(0) { Some(Value::String(s)) => s.trim().parse::<f64>().unwrap_or(-1.0), Some(v) => v.as_number().unwrap_or(-1.0), _ => -1.0 };
    if n < 0.0 { return Ok(Value::String(String::new())); }
    Ok(Value::String(char::from_u32(n as u32).map(|c| c.to_string()).unwrap_or_default()))
}

pub fn host_to_num(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).cloned().unwrap_or(Value::Unit);
    // Preserve the value's own numeric kind where possible (e.g. Value::Int
    // stays Int) rather than always collapsing to Float.
    match v {
        Value::Int(_) | Value::Float(_) | Value::BigInt(_) | Value::Rational(_, _) => Ok(v),
        Value::String(s) => {
            let t = s.trim();
            if let Ok(i) = t.parse::<i64>() { Ok(Value::Int(i)) } else { Ok(Value::Float(t.parse::<f64>().unwrap_or(0.0))) }
        }
        Value::Bool(b) => Ok(Value::Int(if b { 1 } else { 0 })),
        _ => Ok(Value::Int(0)),
    }
}

pub fn host_read_file(args: &[Value]) -> Result<Value, String> {
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    std::fs::read_to_string(&p).map(Value::String).map_err(|e| format!("read_file: {}: {}", p, e))
}

pub fn host_file_exists(args: &[Value]) -> Result<Value, String> {
    // file_exists(path) -> "1" or "0" (legacy string-bool convention, kept
    // consistent with the codegen template's arm of the same name)
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let exists = std::path::Path::new(&p).exists();
    Ok(Value::String(if exists { "1".into() } else { "0".into() }))
}

pub fn host_hash_string(args: &[Value]) -> Result<Value, String> {
    // hash_string(s) -> lowercase hex FNV-1a 64-bit digest. Deterministic
    // and stable across runs/platforms; used for build-cache invalidation
    // (compare a source's hash against a previously recorded one to skip
    // an unchanged rustc invocation).
    let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let mut hash: u64 = 0xcbf29ce484222325;
    for b in s.as_bytes() {
        hash ^= *b as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    Ok(Value::String(format!("{:016x}", hash)))
}

pub fn host_write_file(args: &[Value]) -> Result<Value, String> {
    // write_file(path, contents) -> Bool
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let contents = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    if let Some(parent) = std::path::Path::new(&p).parent() { let _ = std::fs::create_dir_all(parent); }
    std::fs::write(&p, contents).map(|_| Value::Bool(true)).map_err(|e| format!("write_file: {}: {}", p, e))
}

pub fn host_list_dir(args: &[Value]) -> Result<Value, String> {
    // list_dir(path) -> List of entry names; directories are suffixed with
    // "/" so callers can tell them apart from files without a second host
    // call. Non-recursive (one level), matching readdir semantics. Entries
    // are sorted for deterministic output across platforms/filesystems.
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let mut names: Vec<String> = std::fs::read_dir(&p)
        .map_err(|e| format!("list_dir: {}: {}", p, e))?
        .filter_map(|entry| entry.ok())
        .map(|entry| {
            let name = entry.file_name().to_string_lossy().to_string();
            let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
            if is_dir { format!("{}/", name) } else { name }
        })
        .collect();
    names.sort();
    Ok(Value::List(names.into_iter().map(Value::String).collect()))
}

pub fn host_rename_file(args: &[Value]) -> Result<Value, String> {
    // rename_file(from, to) -> Bool. Creates the destination's parent
    // directory if needed (matching write_file's own auto-mkdir behavior).
    let from = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    let to = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    if let Some(parent) = std::path::Path::new(&to).parent() { let _ = std::fs::create_dir_all(parent); }
    std::fs::rename(&from, &to).map(|_| Value::Bool(true)).map_err(|e| format!("rename_file: {} -> {}: {}", from, to, e))
}

pub fn host_byte_length(args: &[Value]) -> Result<Value, String> {
    // byte_length(s) -> Number of UTF-8 bytes (unlike .length, which counts
    // chars) - needed for exact HTTP Content-Length framing of any non-ASCII
    // text.
    let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
    Ok(Value::Int(s.len() as i64))
}

pub fn host_read_line(_args: &[Value]) -> Result<Value, String> {
    // read_line() -> String: one line from stdin, without the trailing
    // newline, or "" at EOF.
    use std::io::BufRead;
    let mut line = String::new();
    let n = std::io::stdin().lock().read_line(&mut line).map_err(|e| format!("read_line: {}", e))?;
    if n == 0 { return Ok(Value::String(String::new())); }
    while line.ends_with('\n') || line.ends_with('\r') { line.pop(); }
    Ok(Value::String(line))
}

pub fn host_now_ms(_args: &[Value]) -> Result<Value, String> {
    // now_ms() -> Number: milliseconds since the Unix epoch (monotonic-enough
    // for self-timing; under the browser WASI shim it maps to performance.now)
    let ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    Ok(Value::Int(ms))
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
    // exec_capture(path, [arg1, arg2, ...]) -> stdout of running the program.
    // Trailing string args (if any) are passed through as argv to the child.
    // Builder-side host for capturing native transcripts of compiled demos.
    // If the process exits with failure (e.g. an unhandled contract
    // violation), stderr is appended too, so transcripts of intentionally
    // failing demos still show the violation message.
    let p = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("exec_capture: expected program path".into()) };
    let extra: Vec<String> = args[1..].iter().filter_map(|v| match v { Value::String(s) => Some(s.clone()), _ => None }).collect();
    let out = std::process::Command::new(&p).args(&extra).output().map_err(|e| format!("exec_capture: {}: {}", p, e))?;
    let mut text = String::from_utf8_lossy(&out.stdout).to_string();
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr);
        if !err.trim().is_empty() {
            if !text.is_empty() && !text.ends_with('\n') { text.push('\n'); }
            text.push_str(&err);
        }
    }
    Ok(Value::String(text))
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
        Value::String(ref s) => s.chars().count() as i64,
        Value::List(ref xs) => xs.len() as i64,
        Value::Object(ref m) => m.len() as i64,
        _ => 0,
    };
    Ok(Value::Int(n))
}

pub fn host_get(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("expected 2 args".into()); }
    let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
    match &args[0] {
        // String receiver reads from the named-object store (OO style), matching
        // the codegen template's `get` arm
        Value::String(name) => Ok(obj_get(name, &key).unwrap_or(Value::Unit)),
        Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
        // Primitive receivers (Number/Bool/List) have no property store, but do
        // support a small set of Ruby-style built-in methods called without
        // parens (e.g. `2.34.to_s`), lowered here since a paren-less `Member`
        // expression goes through `get`, not `send`.
        recv => Ok(builtin_primitive_method(recv, &key).unwrap_or(Value::Unit)),
    }
}

/// Ruby-style built-in methods available on any primitive value, regardless of
/// receiver kind. Returns `None` if `method` isn't one of these built-ins, so
/// callers can fall back to their own "unknown property/method" behavior.
fn builtin_primitive_method(recv: &Value, method: &str) -> Option<Value> {
    match method {
        "to_s" => Some(Value::String(display_value(recv))),
        _ => None,
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
    if args.len() != 3 { return Ok(Value::Int(0)); }
    let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let a = to_s(&args[1]);
    let count = FACTS.with(|f| {
        f.borrow().get(&pred).map(|v| v.iter().filter(|(x, _)| x == &a).count()).unwrap_or(0)
    });
    Ok(Value::Int(count as i64))
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
    let recv = &args[0];
    let method = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
    let rest = &args[2..];
    match method.as_str() {
        "set" => {
            let recv_name = match recv { Value::String(s) => s.clone(), _ => String::new() };
            if rest.len() != 2 { return Ok(Value::Unit); }
            let prop = match &rest[0] { Value::String(s) => s.clone(), _ => String::new() };
            if !recv_name.is_empty() && !prop.is_empty() { obj_set(&recv_name, &prop, rest[1].clone()); }
            Ok(Value::Unit)
        }
        // Ruby-style built-in methods callable with parens (e.g. `2.34.to_s()`),
        // available on any receiver kind — mirrors the paren-less path in
        // `host_get`/`builtin_primitive_method`.
        _ => Ok(builtin_primitive_method(recv, &method).unwrap_or(Value::Unit)),
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
            // Mirrors the lexer's own Int-by-default/Float-if-decimal-point
            // discrimination (Stage 36): whole-number literals stay on the
            // fast Int path, only `.`-containing text becomes Float.
            let t = text.trim();
            let v = if t.contains('.') {
                Value::Float(t.parse::<f64>().map_err(|_| format!("compile_shape: bad number '{}'", text))?)
            } else {
                Value::Int(t.parse::<i64>().map_err(|_| format!("compile_shape: bad number '{}'", text))?)
            };
            f.body.push(Instr::Const(v));
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
fn compile_source_to_exe(rust_src: &str, out: &str, what: &str, target: Option<&str>, opt_level: Option<&str>) -> Result<Value, String> {
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
    // Size-optimize + strip WASM builds: identical program correctness, but
    // ~7x smaller and faster to compile than the default (measured: a
    // feature-complete demo went from 2.1MB/-O to 310KB/opt-level=z, both
    // producing byte-identical stdout). Native builds keep full -O since
    // the portfolio's benchmark card reports real timings -- unless the
    // caller explicitly overrides via opt_level (needed for unusually large
    // generated sources: rustc's optimizer has been observed to blow up to
    // 30GB+ RAM, or separately hang indefinitely burning CPU at opt-level 1,
    // on the self-hosted compiler's own ~1.6MB generated interpreter source;
    // opt-level 0 compiles that same source correctly in ~10s).
    let is_wasm = target.map(|t| t.contains("wasm")).unwrap_or(false);
    if let Some(lvl) = opt_level {
        cmd.arg("-C").arg(format!("opt-level={}", lvl));
    } else if is_wasm {
        cmd.arg("-C").arg("opt-level=z");
    } else {
        cmd.arg("-O");
    }
    cmd.arg("-C").arg("strip=symbols");
    cmd.arg(&src_path).arg("-o").arg(out);
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
    compile_source_to_exe(&rust_src, out, what, None, None)
}

/// codegen_prelude() -> the static runtime library text embedded in every
/// emitted program. Self-hosted codegen concatenates this with its own
/// generated build_program section.
pub fn host_codegen_prelude(_args: &[Value]) -> Result<Value, String> {
    Ok(Value::String(super::codegen::RustCodegen::prelude().to_string()))
}

/// codegen_prelude_chunk(name) -> the raw text of a single named prelude
/// chunk (Stage 37A), or the dispatch-glue text alone via the sentinel name
/// `"__dispatch_all__"`. Used by the redesigned per-chunk parity test
/// (`selfhost_runtime_text_parity`) to compare each chunk individually
/// against its `self_hosting/lib/runtime_rs.patlang` mirror.
pub fn host_codegen_prelude_chunk(args: &[Value]) -> Result<Value, String> {
    let name = match args.get(0) {
        Some(Value::String(s)) => s.clone(),
        _ => return Err("codegen_prelude_chunk: expected chunk name string".into()),
    };
    super::codegen::RustCodegen::chunk_text_by_name(&name)
        .map(Value::String)
        .ok_or_else(|| format!("codegen_prelude_chunk: unknown chunk '{}'", name))
}

/// rustc_build(rust_source, out_path[, target_triple[, opt_level]]) -> compiled artifact path.
/// The dumbest possible back end: write the given Rust source and run rustc.
/// Pass a target triple (e.g. "wasm32-wasip1") to cross-compile. Pass an
/// opt_level ("0".."3", "s", "z") to override the default -O -- see
/// compile_source_to_exe's comment for why this exists.
pub fn host_rustc_build(args: &[Value]) -> Result<Value, String> {
    let src = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("rustc_build: expected Rust source string".into()) };
    let out = match args.get(1) {
        Some(Value::String(s)) if !s.trim().is_empty() => s.clone(),
        _ => return Err("rustc_build: expected output path as second argument".into()),
    };
    let target = match args.get(2) { Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()), _ => None };
    let opt_level = match args.get(3) { Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()), _ => None };
    compile_source_to_exe(&src, &out, "rustc_build", target.as_deref(), opt_level.as_deref())
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
        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| format!("compile_ir: expected number {}", what)),
        Some(v) => v.as_number().map_err(|_| format!("compile_ir: expected number {}", what)),
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
                // Same Int-by-default/Float-if-decimal-point rule as
                // lower_shape_expr's "Num" arm (Stage 36).
                "num" => {
                    let t = text.trim();
                    if t.contains('.') {
                        Value::Float(t.parse::<f64>().map_err(|_| format!("compile_ir: bad number '{}'", text))?)
                    } else {
                        Value::Int(t.parse::<i64>().map_err(|_| format!("compile_ir: bad number '{}'", text))?)
                    }
                }
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
        "MakeClosure" => {
            let func_name = shape_str(xs, 1, "closure func name")?;
            let names_list = shape_stmt_list(xs, 2, "in MakeClosure")?;
            let mut captured_names = Vec::with_capacity(names_list.len());
            for nv in names_list {
                captured_names.push(match nv { Value::String(s) => s.clone(), _ => return Err("compile_ir: captured name must be a string".into()) });
            }
            Instr::MakeClosure(func_name, captured_names)
        }
        "CallValue" => Instr::CallValue(shape_num(xs, 1, "argc")? as usize),
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
        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| format!("{}: expected number", what)),
        Some(v) => v.as_number().map_err(|_| format!("{}: expected number", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

pub fn host_tcp_listen(args: &[Value]) -> Result<Value, String> {
    let port = arg_num(args, 0, "tcp_listen")? as u16;
    let listener = std::net::TcpListener::bind(("127.0.0.1", port))
        .map_err(|e| format!("tcp_listen: bind {}: {}", port, e))?;
    let actual = listener.local_addr().map_err(|e| format!("tcp_listen: {}", e))?.port();
    LISTENERS.with(|l| l.borrow_mut().insert(actual, listener));
    Ok(Value::Int(actual as i64))
}

pub fn host_tcp_connect(args: &[Value]) -> Result<Value, String> {
    // tcp_connect(host, port) -> Number connection id (blocks until connected)
    let host = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("tcp_connect: expected host string".into()) };
    let port = arg_num(args, 1, "tcp_connect")? as u16;
    let stream = std::net::TcpStream::connect((host.as_str(), port))
        .map_err(|e| format!("tcp_connect: {}:{}: {}", host, port, e))?;
    let id = NEXT_CONN.with(|n| { let mut b = n.borrow_mut(); let v = *b; *b += 1; v });
    CONNS.with(|c| c.borrow_mut().insert(id, stream));
    Ok(Value::Int(id as i64))
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
    Ok(Value::Int(id as i64))
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
                return Ok(Value::Int(id as i64));
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                if std::time::Instant::now() >= deadline { return Ok(Value::Int(-1)); }
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

/// contract_check(func_name, kind, text, ok) — the shared design-by-contract
/// enforcement primitive. `kind` is "require" | "ensure" | "assert". This is a
/// VM-level semantic: it behaves identically whether the program is
/// interpreted, executed via run_ir (no rustc — e.g. the browser playground),
/// or compiled natively, because the same logic is duplicated verbatim into
/// the codegen template's host arm.
pub fn host_contract_check(args: &[Value]) -> Result<Value, String> {
    if args.len() != 4 { return Err("contract_check: expected 4 args".into()); }
    let func = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
    let kind = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
    let text = match &args[2] { Value::String(s) => s.clone(), _ => String::new() };
    let ok = args[3].as_bool().unwrap_or(false);
    if ok {
        Ok(Value::Unit)
    } else {
        let label = match kind.as_str() {
            "require" => "precondition",
            "ensure" => "postcondition",
            _ => "assertion",
        };
        Err(format!("contract violation: {} failed in {}(): {}", label, func, text))
    }
}

fn playground_print(args: &[Value]) -> Result<Value, String> {
    if let Some(v) = args.get(0) {
        println!("{}", display_value(v));
        use std::io::Write;
        let _ = std::io::stdout().flush();
    }
    Ok(Value::Unit)
}

/// run_ir(ir_shape) -> executes a freshly lowered IR shape on a nested
/// interpreter with the standard hosts. The playground back end: no rustc.
pub fn host_run_ir(args: &[Value]) -> Result<Value, String> {
    let shape = args.get(0).ok_or("run_ir: expected IR shape")?;
    let program = ir_shape_to_program(shape)?;
    let mut interp = Interpreter::new();
    interp.host.insert("print", playground_print);
    register_stage0_shims(&mut interp);
    interp.run(&program).map(|_| Value::Unit).map_err(|e| format!("run_ir: {}", e))
}

// --- Stage 39 — Math library primitives ---
// These are the small set of Host:: arms that need direct access to tower
// internals (exactness checks, BigInt sqrt, etc); everything expressible in
// terms of these primitives instead lives in self_hosting/lib/math.patlang.
// Mirrored in the `math` codegen chunk (both codegen.rs and
// runtime_rs.patlang) for the compiled path, and every name here MUST also be
// added to `Lowerer::is_allowed_host`'s allowlist in ir/lowering.rs or it gets
// silently dropped from top-level statements.

fn arg_f64(args: &[Value], i: usize, what: &str) -> Result<f64, String> {
    args.get(i).ok_or_else(|| format!("{}: expected numeric arg", what))?.as_number()
}

/// Integer square root (floor of the true square root) via Newton's method,
/// for a non-negative BigInt. Used to test perfect-square-ness exactly rather
/// than via a lossy f64 round-trip, which would be wrong for large magnitudes.
fn bigint_isqrt(n: &BigInt) -> BigInt {
    let zero = BigInt::from(0);
    if *n <= zero { return zero; }
    if *n < BigInt::from(4) { return BigInt::from(1); }
    let bits = n.bits();
    let mut x = BigInt::from(1) << (bits / 2 + 1);
    loop {
        let y = (&x + n / &x) / BigInt::from(2);
        if y >= x { break; }
        x = y;
    }
    x
}

/// sqrt of a value already known to be non-negative: exact Int/BigInt/Rational
/// result for perfect squares (numerator and denominator each perfect
/// squares, for Rational), Float otherwise.
fn sqrt_nonneg(v: &Value) -> Result<Value, String> {
    match v {
        Value::Int(n) => {
            let bi = BigInt::from(*n);
            let r = bigint_isqrt(&bi);
            if &r * &r == bi { Ok(normalize(Value::BigInt(r))) } else { Ok(Value::Float((*n as f64).sqrt())) }
        }
        Value::BigInt(b) => {
            let r = bigint_isqrt(b);
            if &r * &r == *b { Ok(normalize(Value::BigInt(r))) } else { Ok(Value::Float(v.as_number()?.sqrt())) }
        }
        Value::Rational(n, d) => {
            let rn = bigint_isqrt(n);
            let rd = bigint_isqrt(d);
            if &rn * &rn == *n && &rd * &rd == *d {
                Ok(make_rational(rn, rd))
            } else {
                Ok(Value::Float(v.as_number()?.sqrt()))
            }
        }
        Value::Float(f) => Ok(Value::Float(f.sqrt())),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("sqrt: expected numeric value".into()),
    }
}

fn is_negative(v: &Value) -> bool {
    match v {
        Value::Int(n) => *n < 0,
        Value::Float(f) => *f < 0.0,
        Value::BigInt(b) => *b < BigInt::from(0),
        Value::Rational(n, _) => *n < BigInt::from(0),
        _ => false,
    }
}

/// sqrt(x): exact Int/BigInt/Rational for perfect squares, Float otherwise,
/// for x >= 0. For x < 0, returns Complex(0, sqrt(-x)) — the doc's named
/// trigger case for producing a Complex value from PatLang source.
pub fn host_sqrt(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("sqrt: expected 1 arg")?;
    if matches!(v, Value::Complex(_, _)) { return Err("sqrt: complex input not supported".into()); }
    if is_negative(v) {
        let pos = ops::negate(v)?;
        let root = sqrt_nonneg(&pos)?;
        Ok(normalize(Value::Complex(Box::new(Value::Int(0)), Box::new(root))))
    } else {
        sqrt_nonneg(v)
    }
}

/// pow(base, exp): integer exponent on an integer/rational base stays exact
/// via repeated squaring routed through the same `ops::mul`/`ops::div`
/// arithmetic used by `*`/`/` (so it naturally promotes to BigInt on
/// overflow); non-integer exponent or float base falls back to f64::powf.
pub fn host_pow(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("pow: expected 2 args".into()); }
    let base = &args[0];
    let exp = &args[1];
    let base_is_exact = matches!(base, Value::Int(_) | Value::BigInt(_) | Value::Rational(_, _));
    let exp_int: Option<i64> = match exp {
        Value::Int(n) => Some(*n),
        Value::BigInt(b) => i64::try_from(b).ok(),
        _ => None,
    };
    if let (true, Some(e)) = (base_is_exact, exp_int) {
        return int_pow_exact(base, e);
    }
    let b = base.as_number()?;
    let e = exp.as_number()?;
    Ok(Value::Float(b.powf(e)))
}

fn int_pow_exact(base: &Value, exp: i64) -> Result<Value, String> {
    if exp == 0 { return Ok(Value::Int(1)); }
    if exp < 0 {
        let pos = int_pow_exact(base, -exp)?;
        return ops::div(&Value::Int(1), &pos);
    }
    let mut result = Value::Int(1);
    let mut b = base.clone();
    let mut e = exp as u64;
    while e > 0 {
        if e & 1 == 1 { result = ops::mul(&result, &b)?; }
        e >>= 1;
        if e > 0 { b = ops::mul(&b, &b)?; }
    }
    Ok(result)
}

pub fn host_sin(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "sin")?.sin())) }
pub fn host_cos(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "cos")?.cos())) }
pub fn host_tan(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "tan")?.tan())) }
pub fn host_asin(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "asin")?.asin())) }
pub fn host_acos(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "acos")?.acos())) }
pub fn host_atan(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "atan")?.atan())) }
pub fn host_atan2(args: &[Value]) -> Result<Value, String> {
    let y = arg_f64(args, 0, "atan2")?;
    let x = arg_f64(args, 1, "atan2")?;
    Ok(Value::Float(y.atan2(x)))
}
pub fn host_log(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "log")?.ln())) }
pub fn host_exp(args: &[Value]) -> Result<Value, String> { Ok(Value::Float(arg_f64(args, 0, "exp")?.exp())) }

/// floor/ceil/round/trunc: exact for Int/BigInt/Rational (integer division
/// done directly on the BigInt numerator/denominator, never via a lossy f64
/// round-trip), Float fallback for Float input.
fn round_like(args: &[Value], mode: &str) -> Result<Value, String> {
    let v = args.get(0).ok_or_else(|| format!("{}: expected 1 arg", mode))?;
    match v {
        Value::Int(_) | Value::BigInt(_) => Ok(v.clone()),
        Value::Rational(n, d) => {
            // Invariant (numeric.rs::make_rational): d is always > 0.
            let q = n / d; // truncates toward zero
            let r = n - &q * d; // remainder, same sign as n (or zero)
            let zero = BigInt::from(0);
            let result = match mode {
                "trunc" => q,
                "floor" => if r != zero && *n < zero { &q - 1 } else { q },
                "ceil" => if r != zero && *n > zero { &q + 1 } else { q },
                "round" => {
                    let two_r = &r * BigInt::from(2);
                    let past_half = if *n >= zero { two_r >= *d } else { -&two_r >= *d };
                    if past_half { if *n >= zero { &q + 1 } else { &q - 1 } } else { q }
                }
                _ => q,
            };
            Ok(normalize(Value::BigInt(result)))
        }
        Value::Float(f) => Ok(Value::Float(match mode {
            "floor" => f.floor(),
            "ceil" => f.ceil(),
            "round" => f.round(),
            "trunc" => f.trunc(),
            _ => *f,
        })),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err(format!("{}: expected numeric value", mode)),
    }
}

pub fn host_floor(args: &[Value]) -> Result<Value, String> { round_like(args, "floor") }
pub fn host_ceil(args: &[Value]) -> Result<Value, String> { round_like(args, "ceil") }
pub fn host_round(args: &[Value]) -> Result<Value, String> { round_like(args, "round") }
pub fn host_trunc(args: &[Value]) -> Result<Value, String> { round_like(args, "trunc") }

/// abs(x): exact for all real kinds (Int/BigInt/Rational — just clear the
/// sign, reusing ops::negate so overflow of i64::MIN is handled the same way
/// `-x` already is), complex modulus (sqrt(re^2+im^2), itself going through
/// host_sqrt) for Complex.
pub fn host_abs(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("abs: expected 1 arg")?;
    match v {
        Value::Int(_) | Value::BigInt(_) | Value::Rational(_, _) => {
            if is_negative(v) { ops::negate(v) } else { Ok(v.clone()) }
        }
        Value::Float(f) => Ok(Value::Float(f.abs())),
        Value::Complex(re, im) => {
            let re2 = ops::mul(re, re)?;
            let im2 = ops::mul(im, im)?;
            let sum = ops::add(&re2, &im2)?;
            host_sqrt(&[sum])
        }
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("abs: expected numeric value".into()),
    }
}

/// numeric_kind(x) -> "int"|"float"|"bigint"|"rational"|"complex"|"other":
/// runtime introspection since PatLang has no source-level type annotations,
/// so a program needs some way to branch on what representation a value
/// ended up in after tower promotion.
pub fn host_numeric_kind(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("numeric_kind: expected 1 arg")?;
    let s = match v {
        Value::Int(_) => "int",
        Value::Float(_) => "float",
        Value::BigInt(_) => "bigint",
        Value::Rational(_, _) => "rational",
        Value::Complex(_, _) => "complex",
        _ => "other",
    };
    Ok(Value::String(s.to_string()))
}

/// type_of(x) -> "unit"|"bool"|"int"|"float"|"bigint"|"rational"|"complex"|
/// "string"|"list"|"object"|"closure": general runtime reflection over every
/// `Value` variant (numeric_kind above only covers the numeric tower and
/// falls back to "other" for everything else). Self-hosted PatLang code has
/// no way to see into the actual in-memory `Value` representation, so this
/// is necessarily a native host primitive -- it's the one piece of the
/// reflection/transpilation work that can't be pushed into self-hosted
/// PatLang the way ast-to-JSON and the Ruby emitter are.
pub fn host_type_of(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("type_of: expected 1 arg")?;
    let s = match v {
        Value::Unit => "unit",
        Value::Bool(_) => "bool",
        Value::Int(_) => "int",
        Value::Float(_) => "float",
        Value::BigInt(_) => "bigint",
        Value::Rational(_, _) => "rational",
        Value::Complex(_, _) => "complex",
        Value::String(_) => "string",
        Value::List(_) => "list",
        Value::HostFunction(_) => "closure",
        Value::Object(_) => "object",
        Value::Closure { .. } => "closure",
    };
    Ok(Value::String(s.to_string()))
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
    interp.host.insert("file_exists", host_file_exists);
    interp.host.insert("list_dir", host_list_dir);
    interp.host.insert("rename_file", host_rename_file);
    interp.host.insert("hash_string", host_hash_string);
    interp.host.insert("argv", host_argv);
    interp.host.insert("now_ms", host_now_ms);
    interp.host.insert("read_line", host_read_line);
    interp.host.insert("byte_length", host_byte_length);
    interp.host.insert("read_file_b64", host_read_file_b64);
    interp.host.insert("exec_capture", host_exec_capture);
    interp.host.insert("compile_shape", host_compile_shape);
    interp.host.insert("compile_ir", host_compile_ir);
    interp.host.insert("run_ir", host_run_ir);
    interp.host.insert("contract_check", host_contract_check);
    interp.host.insert("codegen_prelude", host_codegen_prelude);
    interp.host.insert("codegen_prelude_chunk", host_codegen_prelude_chunk);
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
    interp.host.insert("tcp_connect", host_tcp_connect);
    interp.host.insert("tcp_accept", host_tcp_accept);
    interp.host.insert("tcp_accept_timeout", host_tcp_accept_timeout);
    interp.host.insert("sleep_ms", host_sleep_ms);
    interp.host.insert("tcp_read", host_tcp_read);
    interp.host.insert("tcp_write", host_tcp_write);
    interp.host.insert("tcp_close", host_tcp_close);
    // math library primitives (Stage 39)
    interp.host.insert("sqrt", host_sqrt);
    interp.host.insert("pow", host_pow);
    interp.host.insert("sin", host_sin);
    interp.host.insert("cos", host_cos);
    interp.host.insert("tan", host_tan);
    interp.host.insert("asin", host_asin);
    interp.host.insert("acos", host_acos);
    interp.host.insert("atan", host_atan);
    interp.host.insert("atan2", host_atan2);
    interp.host.insert("log", host_log);
    interp.host.insert("exp", host_exp);
    interp.host.insert("floor", host_floor);
    interp.host.insert("ceil", host_ceil);
    interp.host.insert("round", host_round);
    interp.host.insert("trunc", host_trunc);
    interp.host.insert("abs", host_abs);
    interp.host.insert("numeric_kind", host_numeric_kind);
    interp.host.insert("type_of", host_type_of);
}
