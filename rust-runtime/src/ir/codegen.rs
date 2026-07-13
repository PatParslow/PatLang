use super::logging::{log_to_file, debug};
use super::file_ops::{create_temp_file, write_to_file, move_or_copy, file_exists, ensure_dir};
use super::types::*;

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ChunkId {
    Core,
    StringsExt,
    CollectionsHandles,
    Files,
    IoMisc,
    Oo,
    Logic,
    Contracts,
    Networking,
    CodegenBootstrap,
    NumericTower,
    Math,
}

impl ChunkId {
    pub const CANONICAL_ORDER: &'static [ChunkId] = &[
        ChunkId::Core,
        ChunkId::StringsExt,
        ChunkId::CollectionsHandles,
        ChunkId::Files,
        ChunkId::IoMisc,
        ChunkId::Oo,
        ChunkId::Logic,
        ChunkId::Contracts,
        ChunkId::Networking,
        ChunkId::CodegenBootstrap,
        ChunkId::NumericTower,
        ChunkId::Math,
    ];

    pub fn name(&self) -> &'static str {
        match self {
            ChunkId::Core => "core",
            ChunkId::StringsExt => "strings_ext",
            ChunkId::CollectionsHandles => "collections_handles",
            ChunkId::Files => "files",
            ChunkId::IoMisc => "io_misc",
            ChunkId::Oo => "oo",
            ChunkId::Logic => "logic",
            ChunkId::Contracts => "contracts",
            ChunkId::Networking => "networking",
            ChunkId::CodegenBootstrap => "codegen_bootstrap",
            ChunkId::NumericTower => "numeric_tower",
            ChunkId::Math => "math",
        }
    }

    pub fn from_name(s: &str) -> Option<ChunkId> {
        Self::CANONICAL_ORDER.iter().copied().find(|c| c.name() == s)
    }

    fn text(&self) -> &'static str {
        match self {
            ChunkId::Core => RustCodegen::PRELUDE_CORE,
            ChunkId::StringsExt => RustCodegen::PRELUDE_STRINGS_EXT,
            ChunkId::CollectionsHandles => RustCodegen::PRELUDE_COLLECTIONS_HANDLES,
            ChunkId::Files => RustCodegen::PRELUDE_FILES,
            ChunkId::IoMisc => RustCodegen::PRELUDE_IO_MISC,
            ChunkId::Oo => RustCodegen::PRELUDE_OO,
            ChunkId::Logic => RustCodegen::PRELUDE_LOGIC,
            ChunkId::Contracts => RustCodegen::PRELUDE_CONTRACTS,
            ChunkId::Networking => RustCodegen::PRELUDE_NETWORKING,
            ChunkId::CodegenBootstrap => RustCodegen::PRELUDE_CODEGEN_BOOTSTRAP,
            ChunkId::NumericTower => RustCodegen::PRELUDE_NUMERIC_TOWER,
            ChunkId::Math => RustCodegen::PRELUDE_MATH,
        }
    }
}

/// Static host-function-name -> chunk table, derived from the same
/// regrouping as the prelude split above.
const HOST_CHUNK_TABLE: &[(&str, ChunkId)] = &[
    ("list_get", ChunkId::Core),
    ("list_len", ChunkId::Core),
    ("list_push", ChunkId::Core),
    ("list_set", ChunkId::Core),
    ("type_of", ChunkId::Core),
    ("bit_get", ChunkId::Core),
    ("bit_set", ChunkId::Core),
    ("bit_slice", ChunkId::Core),
    ("bit_set_slice", ChunkId::Core),
    ("vfs_read", ChunkId::Core),
    ("vfs_write", ChunkId::Core),
    ("vfs_exists", ChunkId::Core),
    ("vfs_list", ChunkId::Core),
    ("vfs_delete", ChunkId::Core),
    ("vfs_flush_to_disk", ChunkId::Core),
    ("char_code", ChunkId::StringsExt),
    ("substr", ChunkId::StringsExt),
    ("chr", ChunkId::StringsExt),
    ("to_num", ChunkId::StringsExt),
    ("hash_string", ChunkId::StringsExt),
    ("vec_new", ChunkId::CollectionsHandles),
    ("vec_push", ChunkId::CollectionsHandles),
    ("vec_set", ChunkId::CollectionsHandles),
    ("vec_get", ChunkId::CollectionsHandles),
    ("vec_len", ChunkId::CollectionsHandles),
    ("vec_to_list", ChunkId::CollectionsHandles),
    ("str_intern", ChunkId::CollectionsHandles),
    ("sc_len", ChunkId::CollectionsHandles),
    ("sc_code", ChunkId::CollectionsHandles),
    ("sc_char", ChunkId::CollectionsHandles),
    ("sb_new", ChunkId::CollectionsHandles),
    ("sb_push", ChunkId::CollectionsHandles),
    ("sb_str", ChunkId::CollectionsHandles),
    ("read_file", ChunkId::Files),
    ("write_file", ChunkId::Files),
    ("touch_file", ChunkId::Files),
    ("file_exists", ChunkId::Files),
    ("list_dir", ChunkId::Files),
    ("rename_file", ChunkId::Files),
    ("exec_capture", ChunkId::Files),
    ("now_ms", ChunkId::IoMisc),
    ("byte_length", ChunkId::IoMisc),
    ("read_line", ChunkId::IoMisc),
    ("argv", ChunkId::IoMisc),
    ("print", ChunkId::IoMisc),
    ("sed", ChunkId::IoMisc),
    ("add", ChunkId::IoMisc),
    ("multiply", ChunkId::IoMisc),
    ("subtract", ChunkId::IoMisc),
    ("max", ChunkId::IoMisc),
    ("min", ChunkId::IoMisc),
    ("calculate", ChunkId::IoMisc),
    ("calculate_result", ChunkId::IoMisc),
    ("get_value", ChunkId::IoMisc),
    ("process", ChunkId::IoMisc),
    ("validate", ChunkId::IoMisc),
    ("len", ChunkId::IoMisc),
    ("new", ChunkId::Oo),
    ("set_var", ChunkId::Oo),
    ("get", ChunkId::Oo),
    ("send", ChunkId::Oo),
    ("infer_type_for", ChunkId::Logic),
    ("fact", ChunkId::Logic),
    ("goal", ChunkId::Logic),
    ("query", ChunkId::Logic),
    ("rule_add", ChunkId::Logic),
    ("solve", ChunkId::Logic),
    ("action_add", ChunkId::Logic),
    ("plan", ChunkId::Logic),
    ("contract_check", ChunkId::Contracts),
    ("tcp_listen", ChunkId::Networking),
    ("tcp_try_listen", ChunkId::Networking),
    ("tcp_connect", ChunkId::Networking),
    ("tcp_accept", ChunkId::Networking),
    ("sleep_ms", ChunkId::Networking),
    ("tcp_accept_timeout", ChunkId::Networking),
    ("tcp_read", ChunkId::Networking),
    ("tcp_write", ChunkId::Networking),
    ("tcp_close", ChunkId::Networking),
    ("parse_tiny_source", ChunkId::CodegenBootstrap),
    ("lower_and_compile", ChunkId::CodegenBootstrap),
    ("emit_rust_for", ChunkId::CodegenBootstrap),
    ("copy_file", ChunkId::CodegenBootstrap),
    ("patc_compile_from_argv", ChunkId::CodegenBootstrap),
    ("get_argv", ChunkId::CodegenBootstrap),
    ("rustc_build", ChunkId::CodegenBootstrap),
    ("run_ir", ChunkId::CodegenBootstrap),
    ("sqrt", ChunkId::Math),
    ("pow", ChunkId::Math),
    ("sin", ChunkId::Math),
    ("cos", ChunkId::Math),
    ("tan", ChunkId::Math),
    ("asin", ChunkId::Math),
    ("acos", ChunkId::Math),
    ("atan", ChunkId::Math),
    ("atan2", ChunkId::Math),
    ("log", ChunkId::Math),
    ("exp", ChunkId::Math),
    ("floor", ChunkId::Math),
    ("ceil", ChunkId::Math),
    ("round", ChunkId::Math),
    ("trunc", ChunkId::Math),
    ("abs", ChunkId::Math),
    ("numeric_kind", ChunkId::Math),
];

/// Cross-chunk dependency edges between non-`core` chunks, for
/// `required_chunks`'s transitive closure. Stage 39 adds the first real
/// entry: `math`'s chunk text is written entirely in terms of the full
/// numeric tower's `Value` variants (BigInt/Rational/Complex) and its
/// NumT/BigIntT/RationalT/ComplexT helper types, so a program that calls
/// e.g. `sqrt(4)` with NO ordinary arithmetic `BinOp` anywhere (which would
/// otherwise leave `required_chunks` selecting the FAST plain-`Number(f64)`
/// `Value` definition per Stage 38's existing rule) must still pull in
/// `numeric_tower` -- otherwise `math`'s chunk text fails to compile against
/// the fast `Value` definition, which has no `BigInt`/`Rational`/`Complex`
/// variants at all.
///
/// `oo -> logic`: found via the benchmark suite (a program using `send()`
/// but no `fact`/`query`/`goal`). `host_call_oo_inner`'s `send()` dispatcher
/// has a `"infer_relations"` method arm that reads the `FACTS` thread-local
/// -- but `FACTS` is only *declared* in `PRELUDE_LOGIC`'s text. Since chunks
/// are selected whole-chunk (not per-match-arm), any program calling `send`
/// at all pulls in this arm's text regardless of which method name it
/// actually uses at runtime, so `oo` unconditionally needs `logic`'s
/// declarations to compile, even though nothing in the portfolio's own demo
/// cards happened to exercise `send` without also using `fact`/`query`
/// (which is why this went unnoticed until now).
const CROSS_CHUNK_EDGES: &[(ChunkId, ChunkId)] = &[
    (ChunkId::Math, ChunkId::NumericTower),
    (ChunkId::Oo, ChunkId::Logic),
    // contract_check's success path now records a fact via `RULES`/`LogicRule`,
    // both declared only in PRELUDE_LOGIC's text -- any program calling
    // contract_check (via require/ensure/assert) needs Logic's declarations
    // to compile, same rationale as the Oo -> Logic edge above.
    (ChunkId::Contracts, ChunkId::Logic),
];

pub struct RustCodegen;

impl RustCodegen {
    pub fn new() -> Self { Self }

    // The static runtime library embedded in every emitted program. Exposed
    // separately so self-hosted codegen (PatLang) can build the full source
    // text itself: prelude + generated build_program section.
    // ---------------------------------------------------------------
    // Host-function prelude chunking (Stage 37A). The runtime library
    // text embedded in every emitted program used to be one ~1600-line
    // `&'static str` (see git history). It is now split into named,
    // independently-emittable chunks derived directly from the original
    // `Host::call` match arms (a regrouping, not a redesign): every arm's
    // body below is byte-for-byte the same code that used to live inline
    // in the monolithic match statement, just relocated into its chunk's
    // own `host_call_<chunk>_inner` function.
    //
    // `numeric_tower` (Stage 38) and `math` (Stage 39) plug in as future
    // ChunkId variants once those chunks have real content -- not added
    // here, out of scope for this task.
    // ---------------------------------------------------------------

    const PRELUDE_CORE: &'static str = r##"// Auto-generated by patlang IR->Rust codegen (Stage 0)
#![allow(dead_code, unused_imports, unused_variables, unused_mut)]
// Standalone runtime + embedded program


use std::collections::HashMap;
use std::cell::RefCell;
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
use std::sync::{Arc, Condvar, Mutex, OnceLock};
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
use std::sync::atomic::{AtomicU64, Ordering};

// OBJECTS (new/send/get's backing store) is shared across OS threads
// (fiber threads, parallel_map workers, WASI-threads Workers) rather than
// thread_local, for the same visibility reason as EVENT_HANDLERS below --
// an object created via `new(...)` on one parallel_map worker thread must
// still be visible to `get`/`send` calls on any other thread. Gated on
// target_feature = "atomics" (not target_arch = "wasm32") for the same
// reason as EVENT_HANDLERS/VFS.
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
thread_local! {
    static OBJECTS: RefCell<HashMap<String, HashMap<String, Value>>> = RefCell::new(HashMap::new());
}
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
static OBJECTS: OnceLock<Mutex<HashMap<String, HashMap<String, Value>>>> = OnceLock::new();

// EVENT_HANDLERS is shared across OS threads (fiber threads, parallel_map
// workers, WASI-threads Workers) rather than thread_local, so a `when`
// handler registered on one thread is visible to `emit(...)` called from
// any other -- otherwise every real OS thread this runtime spawns starts
// with its own fresh, empty copy of the registry, and emit from inside a
// fiber/parallel_map worker is a silent no-op (handlers registered but
// never found). Gated on target_feature = "atomics" (not target_arch =
// "wasm32") for the same reason as `mod fibers` below: that's the real
// "can this target ever have more than one OS thread" signal -- ordinary
// wasm32-wasip1 can't spawn a second thread at all, so a thread_local
// there is already equivalent to a single shared instance, and Mutex/
// OnceLock aren't even importable without atomics.
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
thread_local! {
    static EVENT_HANDLERS: RefCell<HashMap<String, Vec<String>>> = RefCell::new(HashMap::new());
}
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn event_handlers_get(ev: &str) -> Vec<String> {
    EVENT_HANDLERS.with(|m| m.borrow().get(ev).cloned().unwrap_or_default())
}
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn event_handlers_register(ev: String, handler: String) {
    EVENT_HANDLERS.with(|m| m.borrow_mut().entry(ev).or_insert_with(Vec::new).push(handler));
}

#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
static EVENT_HANDLERS: OnceLock<Mutex<HashMap<String, Vec<String>>>> = OnceLock::new();
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn event_handlers_get(ev: &str) -> Vec<String> {
    EVENT_HANDLERS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().get(ev).cloned().unwrap_or_default()
}
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn event_handlers_register(ev: String, handler: String) {
    EVENT_HANDLERS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().entry(ev).or_insert_with(Vec::new).push(handler);
}

// vfs_*: an always-available (including WASM) in-memory virtual
// filesystem, distinct from read_file/write_file/etc (real std::fs,
// native-only) -- deliberately different function names rather than the
// same names silently switching behavior by target, which would be a
// footgun. Shared across OS threads for the same parallel_map-worker-
// visibility reason as EVENT_HANDLERS above, not thread_local.
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
thread_local! {
    static VFS: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
}
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn vfs_get(path: &str) -> Option<String> { VFS.with(|m| m.borrow().get(path).cloned()) }
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn vfs_set(path: String, contents: String) { VFS.with(|m| { m.borrow_mut().insert(path, contents); }); }
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn vfs_del(path: &str) -> bool { VFS.with(|m| m.borrow_mut().remove(path).is_some()) }
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn vfs_keys() -> Vec<String> { VFS.with(|m| m.borrow().keys().cloned().collect()) }

#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
static VFS: OnceLock<Mutex<HashMap<String, String>>> = OnceLock::new();
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn vfs_get(path: &str) -> Option<String> { VFS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().get(path).cloned() }
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn vfs_set(path: String, contents: String) { VFS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().insert(path, contents); }
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn vfs_del(path: &str) -> bool { VFS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().remove(path).is_some() }
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn vfs_keys() -> Vec<String> { VFS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().keys().cloned().collect() }

fn arg_usize(args: &[Value], i: usize, what: &str) -> Result<usize, String> {
    match args.get(i) {
        Some(Value::Number(n)) => Ok(*n as usize),
        Some(Value::String(s)) => s.trim().parse::<usize>().map_err(|_| format!("{}: expected index", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

fn arg_num(args: &[Value], i: usize, what: &str) -> Result<f64, String> {
    match args.get(i) {
        Some(Value::Number(n)) => Ok(*n),
        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| format!("{}: expected number", what)),
        _ => Err(format!("{}: expected number", what)),
    }
}

#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn obj_get(name: &str, prop: &str) -> Option<Value> {
    OBJECTS.with(|o| {
        let b = o.borrow();
        b.get(name).and_then(|m| m.get(prop)).cloned()
    })
}
#[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
fn obj_set(name: &str, prop: &str, val: Value) {
    OBJECTS.with(|o| {
        let mut b = o.borrow_mut();
        let m = b.entry(name.to_string()).or_insert_with(HashMap::new);
        m.insert(prop.to_string(), val);
    });
}

#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn obj_get(name: &str, prop: &str) -> Option<Value> {
    OBJECTS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap().get(name).and_then(|m| m.get(prop)).cloned()
}
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
fn obj_set(name: &str, prop: &str, val: Value) {
    let mut b = OBJECTS.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap();
    b.entry(name.to_string()).or_insert_with(HashMap::new).insert(prop.to_string(), val);
}

fn ensure_obj(name: &str, class: &str) {
    obj_set(name, "type", Value::String(class.to_string()));
    obj_set(name, "name", Value::String(name.to_string()));
}

// NOTE: `enum Value` and its `impl` (as_number/as_bool), plus display_value,
// add/sub/mul/div/modu/cmp/to_s/neg, used to live inline here. As of Stage 38
// they are provided by exactly one of two mutually-exclusive value-modules
// selected per compiled program by `prelude_for` (never both, never
// neither): `PRELUDE_VALUE_FAST` (today's plain `Number(f64)` + new cheap
// `Int(i64)`/`Float(f64)` fast-path variants, no bignum) when the program's
// IR contains no numeric operator at all, or `PRELUDE_NUMERIC_TOWER` (adds
// BigInt/Rational/Complex, hand-rolled, no external crates) when it does.
// This split exists because `Value`'s definition is shared/monomorphic
// across every other chunk's text, so its variant set can't differ chunk by
// chunk within a single build -- see the doc comment on `PRELUDE_VALUE_FAST`
// for the full rationale (Stage 38, "risky shared-dependency edit").

#[derive(Clone, Debug, PartialEq)]
enum BinOpKind { Add, Sub, Mul, Div, Mod, Eq, Ne, Lt, Le, Gt, Ge, And, Or, BitAnd, BitOr, BitXor, Shl, Shr }
#[derive(Clone, Debug, PartialEq)]
enum UnOpKind { Neg, Not, BitNot }

#[derive(Clone, Debug, PartialEq)]
enum Instr {
    Const(Value),
    LoadLocal(String),
    StoreLocal(String),
    BinOp(BinOpKind),
    UnOp(UnOpKind),
    Jump(usize),
    JumpIfFalse(usize),
    CallHost(String, usize),
    Call(String, usize),
    MakeClosure(String, Vec<String>),
    CallValue(usize),
    BuildList(usize),
    Return,
}

struct Host;

// Stage 38: literals now emit `Value::Int`/`Value::Float` by default (see
// `emit_value`), not `Value::Number`, so that `div`'s int/int exactness check
// can tell them apart. Every host function OTHER than the arithmetic BinOp
// dispatch (add/sub/mul/div/modu/cmp, handled directly in `run_function`, not
// via `Host::call`) still pattern-matches `Value::Number` explicitly in its
// own unmodified chunk text (list indices, counts, etc.) -- per Stage 38's
// "minimal blast radius" goal those chunks are left untouched. Instead,
// arguments are coerced back to plain `Number(f64)` right at the `Host::call`
// boundary, restoring pre-Stage-38 behavior for every non-arithmetic host
// function regardless of which value-module (`PRELUDE_VALUE_FAST` or
// `PRELUDE_NUMERIC_TOWER`) is selected.
fn host_coerce_arg(v: &Value) -> Value {
    match v {
        Value::Int(n) => Value::Number(*n as f64),
        Value::Float(n) => Value::Number(*n),
        // BigInt/Rational/Complex are passed through UNCHANGED, not lossily
        // flattened: `print`/`display_value` (and anything else that just
        // consumes a `Value` generically rather than pattern-matching
        // `Value::Number` for an index/count) must see the exact tower value,
        // or e.g. `print(10 / 3)` would silently lose exactness at this
        // boundary and print a lossy float instead of "10/3". Any
        // non-arithmetic host function that genuinely expected a plain index
        // here already had no better fallback pre-Stage-38 either (a
        // non-`Number`/`String` arg always fell through to that function's
        // own `_ => default` arm).
        other => other.clone(),
    }
}

impl Host {
    fn call(name: &str, args: &[Value]) -> Result<Value, String> {
        // type_of needs to see the pre-coercion value (host_coerce_arg below
        // flattens Int/Float down to Number for every other host call,
        // which would make type_of(1) wrongly report "float" instead of
        // "int" -- checked before the generic coercion, matching how the
        // interpreter's own host_type_of (ir/hosts.rs) never coerces at all).
        if name == "type_of" { return Ok(type_of_impl(args)); }
        let __coerced_args: Vec<Value> = args.iter().map(host_coerce_arg).collect();
        let args: &[Value] = &__coerced_args;
        match name {
"list_get" => {
                // list_get(list, index)
                if args.len() != 2 { return Err("expected 2 args".into()); }
                let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(s) => s.parse::<usize>().unwrap_or(0), _ => 0 };
                match &args[0] {
                    Value::List(xs) => Ok(xs.get(idx).cloned().unwrap_or(Value::Unit)),
                    Value::String(s) => {
                        if s.is_ascii() {
                            return Ok(match s.as_bytes().get(idx) { Some(b) => Value::String((*b as char).to_string()), None => Value::String(String::new()) });
                        }
                        let ch = s.chars().nth(idx).unwrap_or('\0');
                        Ok(Value::String(if ch == '\0' { String::new() } else { ch.to_string() }))
                    }
                    _ => Ok(Value::Unit),
                }
            }
            "list_len" => {
                // list_len(listOrString) -> String count (to match Stage 0 builtins)
                if args.len() != 1 { return Err("expected 1 arg".into()); }
                let n = match &args[0] {
                    Value::List(xs) => xs.len(),
                    Value::String(s) => s.chars().count(),
                    _ => 0,
                };
                Ok(Value::String(n.to_string()))
            }
            "list_push" => {
                // list_push(list, item) -> new list with item appended
                if args.len() != 2 { return Err("list_push: expected 2 args".into()); }
                let mut xs = match &args[0] {
                    Value::List(xs) => xs.clone(),
                    Value::Unit => Vec::new(),
                    _ => return Err("list_push: expected list".into()),
                };
                xs.push(args[1].clone());
                Ok(Value::List(xs))
            }
            "list_set" => {
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
            "bit_get" => {
                if args.len() != 2 { return Err("bit_get: expected 2 args (n, pos)".into()); }
                let n = bits_of(&args[0])?;
                let pos = bits_of(&args[1])?;
                if !(0..64).contains(&pos) { return Err(format!("bit_get: pos {} out of range 0..63", pos)); }
                Ok(Value::Int((n >> pos) & 1))
            }
            "bit_set" => {
                if args.len() != 3 { return Err("bit_set: expected 3 args (n, pos, val)".into()); }
                let n = bits_of(&args[0])?;
                let pos = bits_of(&args[1])?;
                let val = bits_of(&args[2])?;
                if !(0..64).contains(&pos) { return Err(format!("bit_set: pos {} out of range 0..63", pos)); }
                let mask = 1i64 << pos;
                Ok(Value::Int(if val != 0 { n | mask } else { n & !mask }))
            }
            "bit_slice" => {
                if args.len() != 3 { return Err("bit_slice: expected 3 args (n, start, width)".into()); }
                let n = bits_of(&args[0])?;
                let start = bits_of(&args[1])?;
                let width = bits_of(&args[2])?;
                if !(0..64).contains(&start) { return Err(format!("bit_slice: start {} out of range 0..63", start)); }
                if !(0..=64).contains(&width) || start + width > 64 { return Err(format!("bit_slice: width {} at start {} out of range", width, start)); }
                if width == 0 { return Ok(Value::Int(0)); }
                let mask: i64 = if width == 64 { -1 } else { (1i64 << width) - 1 };
                Ok(Value::Int((n >> start) & mask))
            }
            "bit_set_slice" => {
                if args.len() != 4 { return Err("bit_set_slice: expected 4 args (n, start, width, val)".into()); }
                let n = bits_of(&args[0])?;
                let start = bits_of(&args[1])?;
                let width = bits_of(&args[2])?;
                let val = bits_of(&args[3])?;
                if !(0..64).contains(&start) { return Err(format!("bit_set_slice: start {} out of range 0..63", start)); }
                if !(0..=64).contains(&width) || start + width > 64 { return Err(format!("bit_set_slice: width {} at start {} out of range", width, start)); }
                if width == 0 { return Ok(Value::Int(n)); }
                let mask: i64 = if width == 64 { -1 } else { (1i64 << width) - 1 };
                let cleared = n & !(mask << start);
                Ok(Value::Int(cleared | ((val & mask) << start)))
            }
            "vfs_read" => {
                let path = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                vfs_get(&path).map(Value::String).ok_or_else(|| format!("vfs_read: not found: {}", path))
            }
            "vfs_write" => {
                let path = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                let contents = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                vfs_set(path, contents);
                Ok(Value::Bool(true))
            }
            "vfs_exists" => {
                let path = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                Ok(Value::String(if vfs_get(&path).is_some() { "1".into() } else { "0".into() }))
            }
            "vfs_list" => {
                let prefix = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                let mut matching: Vec<String> = vfs_keys().into_iter().filter(|k| k.starts_with(&prefix)).collect();
                matching.sort();
                Ok(Value::List(matching.into_iter().map(Value::String).collect()))
            }
            "vfs_delete" => {
                let path = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                Ok(Value::Bool(vfs_del(&path)))
            }
            #[cfg(not(target_arch = "wasm32"))]
            "vfs_flush_to_disk" => {
                let prefix = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                let real_dir = match args.get(1) { Some(Value::String(s)) => s.clone(), _ => return Err("vfs_flush_to_disk: expected real_dir as second arg".into()) };
                let allowed_root = match std::env::var("PATLANG_VFS_ALLOWED_ROOT") {
                    Ok(p) => std::path::PathBuf::from(p),
                    Err(_) => std::env::current_dir().map_err(|e| format!("vfs_flush_to_disk: current_dir: {}", e))?,
                };
                let allowed_root = std::fs::canonicalize(&allowed_root)
                    .map_err(|e| format!("vfs_flush_to_disk: canonicalize allowed root {}: {}", allowed_root.display(), e))?;
                std::fs::create_dir_all(&real_dir).map_err(|e| format!("vfs_flush_to_disk: create_dir_all {}: {}", real_dir, e))?;
                let target_canon = std::fs::canonicalize(&real_dir)
                    .map_err(|e| format!("vfs_flush_to_disk: canonicalize {}: {}", real_dir, e))?;
                if !target_canon.starts_with(&allowed_root) {
                    return Err(format!("vfs_flush_to_disk: {} is outside the allowed root {} (set PATLANG_VFS_ALLOWED_ROOT to permit it)", target_canon.display(), allowed_root.display()));
                }
                let mut count: i64 = 0;
                for key in vfs_keys() {
                    if !key.starts_with(&prefix) { continue; }
                    if let Some(contents) = vfs_get(&key) {
                        let rel = key[prefix.len()..].trim_start_matches('/');
                        let out_path = target_canon.join(rel);
                        if let Some(parent) = out_path.parent() { let _ = std::fs::create_dir_all(parent); }
                        std::fs::write(&out_path, contents).map_err(|e| format!("vfs_flush_to_disk: write {}: {}", out_path.display(), e))?;
                        count += 1;
                    }
                }
                Ok(Value::Int(count))
            }
            #[cfg(target_arch = "wasm32")]
            "vfs_flush_to_disk" => {
                Err("vfs_flush_to_disk: not available under WASM (no real filesystem access)".into())
            }
                        _ => call_dispatch(name, args),
        }
    }
}

// display_value now comes from whichever value-module is selected (see the
// note above `enum BinOpKind`).

// bit_get/bit_set/bit_slice/bit_set_slice (ChunkId::Core, always present)
// need an integer extractor that works regardless of which Value-shape
// chunk is paired alongside PRELUDE_CORE -- Value::Int exists in both, but
// arithmetic results in the "fast" shape can come back as Value::Number.
fn bits_of(v: &Value) -> Result<i64, String> {
    match v { Value::Int(n) => Ok(*n), Value::Number(n) => Ok(*n as i64), _ => Err("expected an integer".into()) }
}

#[derive(Clone)]
struct Function { name: String, params: Vec<String>, body: Vec<Instr> }

#[derive(Clone)]
struct Program { functions: HashMap<String, Function>, entry: String }

fn run(program: &Program) -> Result<Value,String> {
    let entry = program.functions.get(&program.entry).ok_or("entry not found")?;
    run_function(program, entry, &[])
}

// Fibers: Ruby-style cooperative green threads on top of real OS threads,
// ported directly from rust-runtime/src/ir/fiber.rs's interpreter-side
// implementation -- same mutex+condvar design, just resolving/calling
// program functions via this file's own `run_function`/`Program::clone()`
// instead of `Interpreter::call_function`. Not available on an ordinary
// wasm32 build: that target has no std::thread support (see the `main()`
// split below for the same constraint already handled once). It IS
// available on a wasm32 build compiled with atomics (e.g.
// wasm32-wasip1-threads), where std::thread/Mutex/Condvar are real --
// hence gating on target_feature = "atomics" rather than target_arch.
#[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
mod fibers {
    use super::{Program, Value, run_function};
    use std::collections::HashMap;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::{Arc, Condvar, Mutex, OnceLock};

    enum FiberMsg {
        Yielded(Value),
        Done(Result<Value, String>),
    }

    struct FiberBox {
        to_fiber: Option<Value>,
        from_fiber: Option<FiberMsg>,
        alive: bool,
        budget_deadline_ms: Option<i64>,
        budget_last_check_ms: Option<i64>,
        recent_durations: Vec<i64>,
    }

    struct FiberHandle {
        state: Mutex<FiberBox>,
        cv: Condvar,
    }

    fn registry() -> &'static Mutex<HashMap<u64, Arc<FiberHandle>>> {
        static REGISTRY: OnceLock<Mutex<HashMap<u64, Arc<FiberHandle>>>> = OnceLock::new();
        REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
    }

    fn next_id() -> u64 {
        static NEXT: AtomicU64 = AtomicU64::new(1);
        NEXT.fetch_add(1, Ordering::Relaxed)
    }

    thread_local! {
        static CURRENT_FIBER: std::cell::Cell<Option<u64>> = std::cell::Cell::new(None);
    }

    fn now_ms_i64() -> i64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0)
    }

    pub fn fiber_new(program: &Program, func_name: String) -> Result<Value, String> {
        if !program.functions.contains_key(&func_name) {
            return Err(format!("fiber_new: function '{}' not found", func_name));
        }
        let id = next_id();
        let handle = Arc::new(FiberHandle {
            state: Mutex::new(FiberBox {
                to_fiber: None, from_fiber: None, alive: true,
                budget_deadline_ms: None, budget_last_check_ms: None, recent_durations: Vec::new(),
            }),
            cv: Condvar::new(),
        });
        registry().lock().unwrap().insert(id, Arc::clone(&handle));

        let program_owned = program.clone();
        std::thread::spawn(move || {
            CURRENT_FIBER.with(|c| c.set(Some(id)));
            let first_arg = {
                let mut st = handle.state.lock().unwrap();
                while st.to_fiber.is_none() {
                    st = handle.cv.wait(st).unwrap();
                }
                st.to_fiber.take().unwrap()
            };
            let callee = program_owned.functions.get(&func_name).unwrap().clone();
            let result = run_function(&program_owned, &callee, &[first_arg]);
            let mut st = handle.state.lock().unwrap();
            st.alive = false;
            st.from_fiber = Some(FiberMsg::Done(result));
            handle.cv.notify_all();
        });

        Ok(Value::Int(id as i64))
    }

    fn handle_for(id: u64) -> Result<Arc<FiberHandle>, String> {
        registry().lock().unwrap().get(&id).cloned().ok_or_else(|| format!("fiber: unknown fiber id {}", id))
    }

    fn id_from_value(v: &Value) -> Result<u64, String> {
        match v {
            Value::Int(n) if *n >= 0 => Ok(*n as u64),
            other => Err(format!("fiber: expected a fiber id, got {:?}", other)),
        }
    }

    pub fn fiber_resume(id_val: &Value, arg: Value) -> Result<Value, String> {
        let id = id_from_value(id_val)?;
        let handle = handle_for(id)?;
        let mut st = handle.state.lock().unwrap();
        if !st.alive {
            return Err(format!("fiber_resume: fiber {} has already finished", id));
        }
        st.to_fiber = Some(arg);
        handle.cv.notify_all();
        while st.from_fiber.is_none() {
            st = handle.cv.wait(st).unwrap();
        }
        match st.from_fiber.take().unwrap() {
            FiberMsg::Yielded(v) => Ok(v),
            FiberMsg::Done(r) => r,
        }
    }

    pub fn fiber_yield(value: Value) -> Result<Value, String> {
        let id = CURRENT_FIBER.with(|c| c.get()).ok_or_else(|| "fiber_yield: not running inside a fiber".to_string())?;
        let handle = handle_for(id)?;
        let mut st = handle.state.lock().unwrap();
        st.from_fiber = Some(FiberMsg::Yielded(value));
        handle.cv.notify_all();
        while st.to_fiber.is_none() {
            st = handle.cv.wait(st).unwrap();
        }
        Ok(st.to_fiber.take().unwrap())
    }

    pub fn fiber_alive(id_val: &Value) -> Result<Value, String> {
        let id = id_from_value(id_val)?;
        let handle = handle_for(id)?;
        let st = handle.state.lock().unwrap();
        Ok(Value::Bool(st.alive))
    }

    const DURATION_WINDOW: usize = 16;

    fn predict_next_duration_ms(samples: &[i64]) -> i64 {
        let n = samples.len();
        if n == 0 { return 0; }
        if n < 2 { return samples[n - 1]; }
        let n_f = n as f64;
        let sum_x: f64 = (0..n).map(|i| i as f64).sum();
        let sum_y: f64 = samples.iter().map(|&v| v as f64).sum();
        let sum_xy: f64 = samples.iter().enumerate().map(|(i, &v)| i as f64 * v as f64).sum();
        let sum_xx: f64 = (0..n).map(|i| (i as f64) * (i as f64)).sum();
        let denom = n_f * sum_xx - sum_x * sum_x;
        let (slope, intercept) = if denom.abs() < f64::EPSILON {
            (0.0, sum_y / n_f)
        } else {
            let slope = (n_f * sum_xy - sum_x * sum_y) / denom;
            let intercept = (sum_y - slope * sum_x) / n_f;
            (slope, intercept)
        };
        let regression_estimate = slope * n_f + intercept;
        let recent_max = *samples.iter().max().unwrap_or(&0);
        (regression_estimate.max(0.0) as i64).max(recent_max)
    }

    pub fn budgeted_run(program: &Program, ms: i64, func_name: &str, captured: Value, existing_fiber_id: &Value) -> Result<Value, String> {
        let (id_value, first_call) = match existing_fiber_id {
            Value::Unit | Value::Bool(false) => (fiber_new(program, func_name.to_string())?, true),
            v => (v.clone(), false),
        };
        let id = id_from_value(&id_value)?;
        let deadline = now_ms_i64() + ms;
        {
            let handle = handle_for(id)?;
            let mut st = handle.state.lock().unwrap();
            st.budget_deadline_ms = Some(deadline);
            st.budget_last_check_ms = None;
        }
        let resume_arg = if first_call { captured } else { Value::Unit };
        let result = fiber_resume(&id_value, resume_arg)?;
        let still_alive = {
            let handle = handle_for(id)?;
            let st = handle.state.lock().unwrap();
            st.alive
        };
        if still_alive {
            Ok(Value::List(vec![Value::String("paused".into()), id_value]))
        } else {
            Ok(Value::List(vec![Value::String("done".into()), result]))
        }
    }

    pub fn budget_check() -> Result<(), String> {
        let id = match CURRENT_FIBER.with(|c| c.get()) {
            Some(id) => id,
            None => return Ok(()),
        };
        let handle = handle_for(id)?;
        let now = now_ms_i64();
        let (deadline, predicted) = {
            let mut st = handle.state.lock().unwrap();
            if let Some(prev) = st.budget_last_check_ms {
                let dur = (now - prev).max(0);
                st.recent_durations.push(dur);
                if st.recent_durations.len() > DURATION_WINDOW {
                    st.recent_durations.remove(0);
                }
            }
            st.budget_last_check_ms = Some(now);
            let predicted = predict_next_duration_ms(&st.recent_durations);
            (st.budget_deadline_ms, predicted)
        };
        if let Some(dl) = deadline {
            if now + predicted >= dl {
                fiber_yield(Value::Unit)?;
            }
        }
        Ok(())
    }
}

fn run_function(program: &Program, func: &Function, args: &[Value]) -> Result<Value,String> {
    let mut pc: usize = 0;
    let mut stack: Vec<Value> = Vec::new();
    let mut locals: HashMap<String, Value> = HashMap::new();
    // bind params
    for (i, p) in func.params.iter().enumerate() { if let Some(v) = args.get(i) { locals.insert(p.clone(), v.clone()); } }
    while pc < func.body.len() {
        match &func.body[pc] {
            Instr::Const(v) => stack.push(v.clone()),
            Instr::LoadLocal(n) => stack.push(locals.get(n).cloned().unwrap_or(Value::Unit)),
            Instr::StoreLocal(n) => { let v = stack.pop().ok_or("stack underflow")?; locals.insert(n.clone(), v); },
            Instr::UnOp(k) => {
                let a = stack.pop().ok_or("stack underflow")?;
                let r = match k { UnOpKind::Neg => neg(&a)?, UnOpKind::Not => Value::Bool(!a.as_bool()?), UnOpKind::BitNot => bitnot(&a)? };
                stack.push(r);
            }
            Instr::BinOp(k) => {
                use BinOpKind::*;
                let b = stack.pop().ok_or("stack underflow")?;
                let a = stack.pop().ok_or("stack underflow")?;
                let r = match k {
                    Add => add(&a,&b)?, Sub => sub(&a,&b)?, Mul => mul(&a,&b)?, Div => div(&a,&b)?, Mod => modu(&a,&b)?,
                    Eq|Ne|Lt|Le|Gt|Ge => cmp(k, &a, &b)?,
                    And => Value::Bool(a.as_bool()? && b.as_bool()?),
                    Or => Value::Bool(a.as_bool()? || b.as_bool()?),
                    BitAnd => bitand(&a,&b)?, BitOr => bitor(&a,&b)?, BitXor => bitxor(&a,&b)?,
                    Shl => shl(&a,&b)?, Shr => shr(&a,&b)?,
                };
                stack.push(r);
            }
            Instr::Jump(t) => { pc = *t; continue; }
            Instr::JumpIfFalse(t) => { let c = stack.pop().ok_or("stack underflow")?; if !c.as_bool()? { pc = *t; continue; } }
            Instr::CallHost(n, argc) => {
                let argc = *argc; if stack.len() < argc { return Err("stack underflow".into()); }
                let args_index = stack.len() - argc; let args: Vec<Value> = stack.drain(args_index..).collect();
                if n == "emit" {
                    let ev = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                    let payload = args.get(1).cloned().unwrap_or(Value::Unit);
                    let mut last = Value::Unit;
                    let handlers: Vec<String> = event_handlers_get(&ev);
                    for h in handlers {
                        let callee = program.functions.get(&h).ok_or_else(|| format!("function '{}' not found", h))?;
                        // Expose event locals for interpolation via __vars as well
                        obj_set("__vars", "event_name", Value::String(ev.clone()));
                        obj_set("__vars", "event_data", payload.clone());
                        // Handlers are synthesized with parameters (event_name, event_data)
                        last = run_function(program, callee, &[Value::String(ev.clone()), payload.clone()])?;
                    }
                    stack.push(last);
                } else if n == "apply" {
                    // apply(fname, args...): call a program function by name
                    let fname = match args.get(0) {
                        Some(Value::String(s)) => s.clone(),
                        _ => return Err("apply: expected function name string".into()),
                    };
                    let callee = program.functions.get(&fname)
                        .ok_or_else(|| format!("apply: function '{}' not found", fname))?;
                    let r = run_function(program, callee, &args[1..])?;
                    stack.push(r);
                } else if n == "parallel_map" {
                    // parallel_map(items, "func_name") -> list, computed
                    // across real OS threads (std::thread::scope -- Program/
                    // Function/Value here are plain data with no interior
                    // mutability, so workers can borrow `program` directly,
                    // no cloning needed). Mirrors ir/interpreter.rs's own
                    // parallel_map exactly.
                    let items = match args.get(0) {
                        Some(Value::List(xs)) => xs.clone(),
                        other => return Err(format!("parallel_map: expected a list as the first arg, got {:?}", other)),
                    };
                    let fname = match args.get(1) {
                        Some(Value::String(s)) => s.clone(),
                        other => return Err(format!("parallel_map: expected a function name string as the second arg, got {:?}", other)),
                    };
                    if !program.functions.contains_key(&fname) {
                        return Err(format!("parallel_map: function '{}' not found", fname));
                    }
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("parallel_map is not supported when compiled to an ordinary (non-threaded) wasm32 target".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let results: Result<Vec<Value>, String> = std::thread::scope(|scope| {
                            let handles: Vec<_> = items.iter().map(|item| {
                                let fname = &fname;
                                scope.spawn(move || {
                                    let callee = program.functions.get(fname).unwrap();
                                    run_function(program, callee, std::slice::from_ref(item))
                                })
                            }).collect();
                            handles.into_iter().map(|h| h.join().unwrap_or_else(|_| Err("parallel_map: a worker thread panicked".to_string()))).collect()
                        });
                        stack.push(Value::List(results?));
                    }
                } else if n == "fiber_new" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("fibers are not supported when compiled to wasm32".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let fname = match args.get(0) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("fiber_new: expected a function name string, got {:?}", other)),
                        };
                        stack.push(fibers::fiber_new(program, fname)?);
                    }
                } else if n == "fiber_resume" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("fibers are not supported when compiled to wasm32".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let id = args.get(0).cloned().unwrap_or(Value::Unit);
                        let arg = args.get(1).cloned().unwrap_or(Value::Unit);
                        stack.push(fibers::fiber_resume(&id, arg)?);
                    }
                } else if n == "fiber_yield" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("fibers are not supported when compiled to wasm32".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let v = args.get(0).cloned().unwrap_or(Value::Unit);
                        stack.push(fibers::fiber_yield(v)?);
                    }
                } else if n == "fiber_alive" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("fibers are not supported when compiled to wasm32".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let id = args.get(0).cloned().unwrap_or(Value::Unit);
                        stack.push(fibers::fiber_alive(&id)?);
                    }
                } else if n == "budgeted_run" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("budgeted(...) blocks are not supported when compiled to wasm32 (they run on fibers, which need real OS threads)".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        let ms = match args.get(0) { Some(v) => v.as_number().map_err(|_| "budgeted_run: expected a number of ms".to_string())? as i64, None => return Err("budgeted_run: expected ms".into()) };
                        let fname = match args.get(1) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("budgeted_run: expected a function name string, got {:?}", other)),
                        };
                        let captured = args.get(2).cloned().unwrap_or(Value::List(vec![]));
                        let existing = args.get(3).cloned().unwrap_or(Value::Unit);
                        stack.push(fibers::budgeted_run(program, ms, &fname, captured, &existing)?);
                    }
                } else if n == "budget_check" {
                    #[cfg(all(target_arch = "wasm32", not(target_feature = "atomics")))]
                    { return Err("budgeted(...) blocks are not supported when compiled to wasm32 (they run on fibers, which need real OS threads)".into()); }
                    #[cfg(any(not(target_arch = "wasm32"), target_feature = "atomics"))]
                    {
                        fibers::budget_check()?;
                        stack.push(Value::Unit);
                    }
                } else {
                    let r = Host::call(n, &args)?; stack.push(r);
                }
            }
            Instr::Call(n, argc) => {
                let argc = *argc; if stack.len() < argc { return Err("stack underflow".into()); }
                let args_index = stack.len() - argc; let args: Vec<Value> = stack.drain(args_index..).collect();
                let callee = program.functions.get(n).ok_or_else(|| format!("function '{}' not found", n))?;
                let r = run_function(program, callee, &args)?; stack.push(r);
            }
            Instr::MakeClosure(func_name, captured_names) => {
                let n = captured_names.len();
                if stack.len() < n { return Err("stack underflow".into()); }
                let start = stack.len() - n;
                let vals: Vec<Value> = stack.drain(start..).collect();
                let captured: Vec<(String, Value)> = captured_names.iter().cloned().zip(vals).collect();
                stack.push(Value::Closure { func_name: func_name.clone(), captured });
            }
            Instr::CallValue(argc) => {
                let argc = *argc; if stack.len() < argc { return Err("stack underflow".into()); }
                let args_index = stack.len() - argc;
                let call_args: Vec<Value> = stack.drain(args_index..).collect();
                let callee_val = stack.pop().ok_or("stack underflow")?;
                match callee_val {
                    Value::Closure { func_name, captured } => {
                        let mut full_args: Vec<Value> = captured.into_iter().map(|(_, v)| v).collect();
                        full_args.extend(call_args);
                        let callee = program.functions.get(&func_name).ok_or_else(|| format!("function '{}' not found", func_name))?;
                        let r = run_function(program, callee, &full_args)?;
                        stack.push(r);
                    }
                    other => return Err(format!("cannot call non-closure value: {:?}", other)),
                }
            }
            Instr::BuildList(n) => { let n=*n; if stack.len()<n {return Err("stack underflow".into());} let start=stack.len()-n; let items: Vec<Value>=stack.drain(start..).collect(); stack.push(Value::List(items)); }
            Instr::Return => { return Ok(stack.pop().unwrap_or(Value::Unit)); }
        }
        pc += 1;
    }
    Ok(stack.pop().unwrap_or(Value::Unit))
}

// add/sub/mul/div/modu/cmp/to_s/neg now come from whichever value-module is
// selected (see the note above `enum BinOpKind`).

// Native builds run on a spawned thread with a much larger stack than the
// OS-default main thread stack: deeply recursive-descent programs (notably
// the self-hosted compiler recompiling its own ~300K-char source) can
// exceed the default stack, especially at lower optimization levels where
// inlining/tail-call-friendly codegen doesn't shrink frame sizes. WASM
// (wasip1) targets keep the original direct-call main -- std::thread
// support there is not guaranteed across WASI runtimes.
#[cfg(not(target_arch = "wasm32"))]
fn main(){
    let child = std::thread::Builder::new()
        .stack_size(256 * 1024 * 1024)
        .spawn(|| {
            let program = build_program();
            match run(&program) {
                Ok(v) => { println!("{}", display_value(&v)); 0 }
                Err(e) => { eprintln!("IR runtime error: {}", e); 1 }
            }
        })
        .expect("failed to spawn worker thread");
    let code = child.join().unwrap_or(1);
    std::process::exit(code);
}

#[cfg(target_arch = "wasm32")]
fn main(){
    let program = build_program();
    match run(&program) { Ok(v) => println!("{}", display_value(&v)), Err(e) => { eprintln!("IR runtime error: {}", e); std::process::exit(1); } }
}

"##;

    // -----------------------------------------------------------------
    // Stage 38 -- Value module (mutually exclusive pair).
    //
    // `enum Value` (and its arithmetic: as_number/as_bool/display_value/
    // add/sub/mul/div/modu/cmp/to_s/neg) used to be fixed, always-present
    // text inside `PRELUDE_CORE`. Stage 38 needed to add BigInt/Rational/
    // Complex variants, but `Value` is a single shared type referenced by
    // every other chunk's text (Core's VM loop calls add/sub/etc
    // unconditionally per `Instr::BinOp`, and every chunk pattern-matches
    // `Value::Number` in dozens of places) -- so its variant set cannot
    // differ chunk-by-chunk within one compiled program, and the struct
    // backing a `BigInt` variant (`BigIntT`) must exist for the enum to
    // type-check at all if the variant is present in the text.
    //
    // Resolution (a pragmatic, explicitly-flagged judgment call -- see
    // `review-memory-for-the-swirling-octopus.md` Stage 38 step 2): rather
    // than always paying for the tower, `prelude_for` selects EXACTLY ONE
    // of these two modules per compiled program, in the slot
    // `ChunkId::NumericTower` occupies in `CANONICAL_ORDER`:
    //   - `PRELUDE_VALUE_FAST`: today's `Number(f64)` plus new but cheap
    //     `Int(i64)`/`Float(f64)` variants (literals emit these by default
    //     now -- see `emit_value` -- so every compiled program needs them
    //     regardless of whether it does arithmetic). No BigInt/Rational/
    //     Complex, no hand-rolled bignum text. Chosen when `required_chunks`
    //     finds no numeric operator anywhere in the program's IR.
    //   - `PRELUDE_NUMERIC_TOWER`: adds BigInt/Rational/Complex (hand-rolled
    //     `BigIntT`/`RationalT`/`ComplexT`/`NumT`, transcribed from the
    //     already-unit-tested `ir/bignum_template.rs` /
    //     `ir/rational_complex_template.rs`, std-only, no external crates --
    //     the emitted program builds via bare `rustc` with no Cargo.toml).
    //     Chosen whenever `required_chunks` finds any numeric `BinOp`
    //     (Add/Sub/Mul/Div/Mod) or `UnOp(Neg)` in the IR (a deliberately
    //     coarse, documented over-approximation per the design doc, not an
    //     attempt to prove overflow is reachable).
    // Every other chunk's own text is completely unmodified either way --
    // both modules define the same function names/signatures
    // (add/sub/mul/div/modu/cmp/to_s/display_value/neg, `impl Value` with
    // as_number/as_bool), so whichever one is textually present is exactly
    // what the rest of the concatenated program links against.
    // -----------------------------------------------------------------

    const PRELUDE_VALUE_FAST: &'static str = r##"#[derive(Clone, Debug, PartialEq)]
enum Value {
    Unit,
    Bool(bool),
    Number(f64),
    Int(i64),
    Float(f64),
    String(String),
    List(Vec<Value>),
    Object(HashMap<String, Value>),
    Closure { func_name: String, captured: Vec<(String, Value)> },
}

impl Value {
    fn as_number(&self) -> Result<f64, String> {
        match self {
            Value::Number(n) => Ok(*n),
            Value::Int(n) => Ok(*n as f64),
            Value::Float(n) => Ok(*n),
            Value::Unit => Ok(0.0),
            _ => Err("expected number".into()),
        }
    }
    fn as_bool(&self) -> Result<bool, String> {
        match self {
            Value::Bool(b) => Ok(*b),
            Value::Unit => Ok(false),
            Value::Number(n) => Ok(*n != 0.0),
            Value::Int(n) => Ok(*n != 0),
            Value::Float(n) => Ok(*n != 0.0),
            Value::String(s) => Ok(!s.is_empty()),
            Value::List(xs) => Ok(!xs.is_empty()),
            Value::Object(map) => Ok(!map.is_empty()),
            Value::Closure { .. } => Ok(true),
        }
    }
}

fn display_value(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => if n.fract()==0.0 { format!("{}", *n as i64) } else { n.to_string() },
        Value::Int(n) => n.to_string(),
        Value::Float(n) => if n.fract()==0.0 && n.is_finite() { format!("{}", *n as i64) } else { n.to_string() },
        Value::String(s) => s.clone(),
        Value::List(xs) => {
            let parts: Vec<String> = xs.iter().map(|x| display_value(x)).collect();
            format!("[{}]", parts.join(", "))
        }
        Value::Object(map) => {
            let mut kvs: Vec<String> = map.iter().map(|(k,v)| format!("{}: {}", k, display_value(v))).collect();
            kvs.sort();
            format!("{{{}}}", kvs.join(", "))
        }
        Value::Closure { .. } => "<closure>".into(),
    }
}

fn add(a:&Value,b:&Value)->Result<Value,String>{
    match (a,b) {
        (Value::String(sa), _) => Ok(Value::String(format!("{}{}", sa, to_s(b)))),
        (_, Value::String(sb)) => Ok(Value::String(format!("{}{}", to_s(a), sb))),
        _ => Ok(Value::Number(a.as_number()? + b.as_number()?)),
    }
}
fn sub(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Number(a.as_number()? - b.as_number()?)) }
fn mul(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Number(a.as_number()? * b.as_number()?)) }
fn div(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Number(a.as_number()? / b.as_number()?)) }
fn modu(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Number(a.as_number()? % b.as_number()?)) }
fn neg(a:&Value)->Result<Value,String>{ Ok(Value::Number(-a.as_number()?)) }
fn as_bits(v:&Value)->Result<i64,String>{
    match v { Value::Int(n) => Ok(*n), Value::Number(n) => Ok(*n as i64), _ => Err("expected an integer".into()) }
}
fn bitand(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? & as_bits(b)?)) }
fn bitor(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? | as_bits(b)?)) }
fn bitxor(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? ^ as_bits(b)?)) }
fn bitnot(a:&Value)->Result<Value,String>{ Ok(Value::Int(!as_bits(a)?)) }
fn shl(a:&Value,b:&Value)->Result<Value,String>{
    let x=as_bits(a)?; let n=as_bits(b)?;
    if !(0..64).contains(&n) { return Err(format!("shl: shift amount {} out of range 0..63", n)); }
    Ok(Value::Int(x<<n))
}
fn shr(a:&Value,b:&Value)->Result<Value,String>{
    let x=as_bits(a)?; let n=as_bits(b)?;
    if !(0..64).contains(&n) { return Err(format!("shr: shift amount {} out of range 0..63", n)); }
    Ok(Value::Int(x>>n))
}
fn cmp(k:&BinOpKind,a:&Value,b:&Value)->Result<Value,String>{
    use BinOpKind::*;
    let res = match k {
        // Structural equality for Eq/Ne across all Value variants
        Eq => a == b,
        Ne => a != b,
        // Relational: lexicographic for string pairs, numeric otherwise
        Lt | Le | Gt | Ge => {
            if let (Value::String(x), Value::String(y)) = (a, b) {
                match k {
                    Lt => x < y,
                    Le => x <= y,
                    Gt => x > y,
                    Ge => x >= y,
                    _ => unreachable!(),
                }
            } else {
                let (an, bn) = (a.as_number()?, b.as_number()?);
                match k {
                    Lt => an < bn,
                    Le => an <= bn,
                    Gt => an > bn,
                    Ge => an >= bn,
                    _ => unreachable!(),
                }
            }
        }
        _ => false,
    };
    Ok(Value::Bool(res))
}
fn to_s(v:&Value)->String{ match v { Value::Unit=>String::new(), Value::Bool(b)=>b.to_string(), Value::Number(n)=> if n.fract()==0.0 {format!("{}",*n as i64)} else {n.to_string()}, Value::Int(n)=>n.to_string(), Value::Float(n)=> if n.fract()==0.0 && n.is_finite() {format!("{}",*n as i64)} else {n.to_string()}, Value::String(s)=>s.clone(), Value::List(xs)=>{ let parts:Vec<String>=xs.iter().map(|x|to_s(x)).collect(); format!("[{}]", parts.join(", ")) }, Value::Object(map)=>{ let mut kvs:Vec<String>=map.iter().map(|(k,v)| format!("{}: {}",k,to_s(v))).collect(); kvs.sort(); format!("{{{}}}", kvs.join(", ")) }, Value::Closure{..} => "<closure>".to_string() } }
fn type_of_impl(args: &[Value]) -> Value {
    let v = match args.get(0) { Some(v) => v, None => return Value::String("unit".to_string()) };
    let s = match v {
        Value::Unit => "unit",
        Value::Bool(_) => "bool",
        Value::Number(_) => "float",
        Value::Int(_) => "int",
        Value::Float(_) => "float",
        Value::String(_) => "string",
        Value::List(_) => "list",
        Value::Object(_) => "object",
        Value::Closure{..} => "closure",
    };
    Value::String(s.to_string())
}
"##;

    // Stage 38 -- numeric tower value module. Selected instead of
    // `PRELUDE_VALUE_FAST` whenever `required_chunks` sees a numeric BinOp
    // or UnOp(Neg) anywhere in the program's IR. BigIntT/RationalT/NumT/
    // ComplexT below are hand-transcribed, unmodified-logic copies of
    // `ir/bignum_template.rs` (Milestone 1) and
    // `ir/rational_complex_template.rs` (Milestone 2), which are already
    // unit-tested (23 + 22 tests) in this repo's own `cargo test` -- their
    // arithmetic is not re-derived here, only adapted to construct/consume
    // this file's own `Value` enum instead of a bare return type.
    //
    // DELIBERATE ASYMMETRY (documented at both definition sites per the
    // design doc): the *interpreter* (`ir/numeric.rs`) uses the real
    // `num_bigint::BigInt` crate. This module hand-rolls its own BigIntT
    // because the emitted program compiles via bare `rustc` on a single
    // `.rs` file with no `Cargo.toml` and cannot depend on any crate.
    const PRELUDE_NUMERIC_TOWER: &'static str = r##"#[derive(Clone, Debug, PartialEq)]
enum Value {
    Unit,
    Bool(bool),
    Number(f64),
    Int(i64),
    Float(f64),
    BigInt(BigIntT),
    Rational(RationalT),
    Complex(ComplexT),
    String(String),
    List(Vec<Value>),
    Object(HashMap<String, Value>),
    Closure { func_name: String, captured: Vec<(String, Value)> },
}

// ===== BigIntT (hand-transcribed from ir/bignum_template.rs, unmodified logic) =====

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Sign { Zero, Positive, Negative }

const NT_BASE: u64 = 1_000_000_000;
const NT_BASE_DIGITS: usize = 9;

#[derive(Debug, Clone)]
struct BigIntT { sign: Sign, limbs: Vec<u32> }

impl BigIntT {
    fn zero() -> Self { BigIntT { sign: Sign::Zero, limbs: Vec::new() } }
    fn is_zero(&self) -> bool { self.sign == Sign::Zero }
    fn is_negative(&self) -> bool { self.sign == Sign::Negative }

    fn normalize(mut self) -> Self {
        while self.limbs.last() == Some(&0) { self.limbs.pop(); }
        if self.limbs.is_empty() { self.sign = Sign::Zero; }
        self
    }

    fn from_i64(n: i64) -> Self {
        if n == 0 { return BigIntT::zero(); }
        let sign = if n < 0 { Sign::Negative } else { Sign::Positive };
        let mut mag: u64 = if n == i64::MIN { (i64::MAX as u64) + 1 } else { n.unsigned_abs() };
        let mut limbs = Vec::new();
        if mag == 0 { limbs.push(0); }
        while mag > 0 { limbs.push((mag % NT_BASE) as u32); mag /= NT_BASE; }
        BigIntT { sign, limbs }.normalize()
    }

    fn from_decimal_str(s: &str) -> Option<Self> {
        let s = s.trim();
        if s.is_empty() { return None; }
        let (neg, digits) = match s.as_bytes()[0] {
            b'-' => (true, &s[1..]),
            b'+' => (false, &s[1..]),
            _ => (false, s),
        };
        if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()) { return None; }
        let trimmed = digits.trim_start_matches('0');
        if trimmed.is_empty() { return Some(BigIntT::zero()); }
        let mut limbs = Vec::new();
        let bytes = trimmed.as_bytes();
        let mut end = bytes.len();
        while end > 0 {
            let start = if end >= NT_BASE_DIGITS { end - NT_BASE_DIGITS } else { 0 };
            let chunk = std::str::from_utf8(&bytes[start..end]).unwrap();
            let limb: u32 = chunk.parse().unwrap();
            limbs.push(limb);
            end = start;
        }
        let sign = if neg { Sign::Negative } else { Sign::Positive };
        Some(BigIntT { sign, limbs }.normalize())
    }

    fn to_string(&self) -> String {
        if self.is_zero() { return "0".to_string(); }
        let mut s = String::new();
        if self.sign == Sign::Negative { s.push('-'); }
        let mut iter = self.limbs.iter().rev();
        let msl = iter.next().unwrap();
        s.push_str(&msl.to_string());
        for limb in iter { s.push_str(&format!("{:0width$}", limb, width = NT_BASE_DIGITS)); }
        s
    }

    fn negate(&self) -> Self {
        let sign = match self.sign { Sign::Zero => Sign::Zero, Sign::Positive => Sign::Negative, Sign::Negative => Sign::Positive };
        BigIntT { sign, limbs: self.limbs.clone() }
    }

    fn cmp_mag(a: &[u32], b: &[u32]) -> std::cmp::Ordering {
        if a.len() != b.len() { return a.len().cmp(&b.len()); }
        for i in (0..a.len()).rev() { if a[i] != b[i] { return a[i].cmp(&b[i]); } }
        std::cmp::Ordering::Equal
    }

    fn add_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut result = Vec::with_capacity(a.len().max(b.len()) + 1);
        let mut carry: u64 = 0;
        for i in 0..a.len().max(b.len()) {
            let av = *a.get(i).unwrap_or(&0) as u64;
            let bv = *b.get(i).unwrap_or(&0) as u64;
            let sum = av + bv + carry;
            result.push((sum % NT_BASE) as u32);
            carry = sum / NT_BASE;
        }
        if carry > 0 { result.push(carry as u32); }
        result
    }

    fn sub_mag(a: &[u32], b: &[u32]) -> Vec<u32> {
        let mut result = Vec::with_capacity(a.len());
        let mut borrow: i64 = 0;
        for i in 0..a.len() {
            let av = a[i] as i64;
            let bv = *b.get(i).unwrap_or(&0) as i64;
            let mut diff = av - bv - borrow;
            if diff < 0 { diff += NT_BASE as i64; borrow = 1; } else { borrow = 0; }
            result.push(diff as u32);
        }
        result
    }

    fn add(&self, other: &BigIntT) -> BigIntT {
        if self.is_zero() { return other.clone(); }
        if other.is_zero() { return self.clone(); }
        if self.sign == other.sign {
            BigIntT { sign: self.sign, limbs: Self::add_mag(&self.limbs, &other.limbs) }.normalize()
        } else {
            match Self::cmp_mag(&self.limbs, &other.limbs) {
                std::cmp::Ordering::Equal => BigIntT::zero(),
                std::cmp::Ordering::Greater => BigIntT { sign: self.sign, limbs: Self::sub_mag(&self.limbs, &other.limbs) }.normalize(),
                std::cmp::Ordering::Less => BigIntT { sign: other.sign, limbs: Self::sub_mag(&other.limbs, &self.limbs) }.normalize(),
            }
        }
    }

    fn sub(&self, other: &BigIntT) -> BigIntT { self.add(&other.negate()) }

    fn mul(&self, other: &BigIntT) -> BigIntT {
        if self.is_zero() || other.is_zero() { return BigIntT::zero(); }
        let mut result = vec![0u64; self.limbs.len() + other.limbs.len()];
        for (i, &av) in self.limbs.iter().enumerate() {
            if av == 0 { continue; }
            let mut carry: u64 = 0;
            for (j, &bv) in other.limbs.iter().enumerate() {
                let idx = i + j;
                let prod = (av as u64) * (bv as u64) + result[idx] + carry;
                result[idx] = prod % NT_BASE;
                carry = prod / NT_BASE;
            }
            let mut k = i + other.limbs.len();
            while carry > 0 { let sum = result[k] + carry; result[k] = sum % NT_BASE; carry = sum / NT_BASE; k += 1; }
        }
        let sign = if self.sign == other.sign { Sign::Positive } else { Sign::Negative };
        let limbs: Vec<u32> = result.into_iter().map(|x| x as u32).collect();
        BigIntT { sign, limbs }.normalize()
    }

    fn div_rem(&self, other: &BigIntT) -> (BigIntT, BigIntT) {
        if other.is_zero() { panic!("BigIntT division by zero"); }
        if self.is_zero() { return (BigIntT::zero(), BigIntT::zero()); }
        if Self::cmp_mag(&self.limbs, &other.limbs) == std::cmp::Ordering::Less {
            return (BigIntT::zero(), self.clone());
        }
        let other_mag = BigIntT { sign: Sign::Positive, limbs: other.limbs.clone() };
        let mut remainder = BigIntT::zero();
        let mut quotient_limbs = vec![0u32; self.limbs.len()];
        for i in (0..self.limbs.len()).rev() {
            remainder = remainder.mul_by_base().add(&BigIntT::from_i64(self.limbs[i] as i64));
            let mut lo: u64 = 0;
            let mut hi: u64 = NT_BASE - 1;
            while lo < hi {
                let mid = (lo + hi + 1) / 2;
                let candidate = other_mag.mul(&BigIntT::from_i64(mid as i64));
                if Self::cmp_mag(&candidate.limbs, &remainder.limbs) != std::cmp::Ordering::Greater { lo = mid; } else { hi = mid - 1; }
            }
            quotient_limbs[i] = lo as u32;
            remainder = remainder.sub(&other_mag.mul(&BigIntT::from_i64(lo as i64)));
        }
        let quotient_sign_positive = self.sign == other.sign;
        let quotient = BigIntT {
            sign: if quotient_limbs.iter().all(|&x| x == 0) { Sign::Zero } else if quotient_sign_positive { Sign::Positive } else { Sign::Negative },
            limbs: quotient_limbs,
        }.normalize();
        let remainder = if remainder.is_zero() { BigIntT::zero() } else { BigIntT { sign: self.sign, limbs: remainder.limbs }.normalize() };
        (quotient, remainder)
    }

    fn mul_by_base(&self) -> BigIntT {
        if self.is_zero() { return BigIntT::zero(); }
        let mut limbs = Vec::with_capacity(self.limbs.len() + 1);
        limbs.push(0);
        limbs.extend_from_slice(&self.limbs);
        BigIntT { sign: self.sign, limbs }.normalize()
    }

    fn cmp(&self, other: &BigIntT) -> std::cmp::Ordering {
        use Sign::*;
        match (self.sign, other.sign) {
            (Zero, Zero) => std::cmp::Ordering::Equal,
            (Zero, Positive) => std::cmp::Ordering::Less,
            (Zero, Negative) => std::cmp::Ordering::Greater,
            (Positive, Zero) => std::cmp::Ordering::Greater,
            (Negative, Zero) => std::cmp::Ordering::Less,
            (Positive, Negative) => std::cmp::Ordering::Greater,
            (Negative, Positive) => std::cmp::Ordering::Less,
            (Positive, Positive) => Self::cmp_mag(&self.limbs, &other.limbs),
            (Negative, Negative) => Self::cmp_mag(&other.limbs, &self.limbs),
        }
    }

    fn eq(&self, other: &BigIntT) -> bool { self.cmp(other) == std::cmp::Ordering::Equal }
}

impl std::fmt::Display for BigIntT { fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { write!(f, "{}", self.to_string()) } }
impl PartialEq for BigIntT { fn eq(&self, other: &Self) -> bool { BigIntT::eq(self, other) } }
impl Eq for BigIntT {}
impl PartialOrd for BigIntT { fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> { Some(self.cmp(other)) } }
impl Ord for BigIntT { fn cmp(&self, other: &Self) -> std::cmp::Ordering { BigIntT::cmp(self, other) } }

fn nt_gcd(a: &BigIntT, b: &BigIntT) -> BigIntT {
    let mut a = BigIntT { sign: if a.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: a.limbs.clone() };
    let mut b = BigIntT { sign: if b.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: b.limbs.clone() };
    while !b.is_zero() {
        let (_, r) = a.div_rem(&b);
        let r_abs = BigIntT { sign: if r.is_zero() { Sign::Zero } else { Sign::Positive }, limbs: r.limbs };
        a = b;
        b = r_abs;
    }
    a
}

// ===== RationalT/NumT/ComplexT (hand-transcribed from ir/rational_complex_template.rs, unmodified logic) =====

#[derive(Debug, Clone, PartialEq)]
struct RationalT { num: BigIntT, den: BigIntT }

impl RationalT {
    fn new(num: BigIntT, den: BigIntT) -> Self {
        if den.is_zero() { panic!("RationalT: zero denominator"); }
        let (num, den) = if den.is_negative() { (num.negate(), den.negate()) } else { (num, den) };
        if num.is_zero() { return RationalT { num: BigIntT::zero(), den: BigIntT::from_i64(1) }; }
        let g = nt_gcd(&num, &den);
        if g.is_zero() || g.eq(&BigIntT::from_i64(1)) {
            RationalT { num, den }
        } else {
            let (qn, _) = num.div_rem(&g);
            let (qd, _) = den.div_rem(&g);
            RationalT { num: qn, den: qd }
        }
    }
    fn from_i64_pair(n: i64, d: i64) -> Self { RationalT::new(BigIntT::from_i64(n), BigIntT::from_i64(d)) }
    fn is_zero(&self) -> bool { self.num.is_zero() }
    fn add(&self, other: &RationalT) -> RationalT {
        let num = self.num.mul(&other.den).add(&other.num.mul(&self.den));
        let den = self.den.mul(&other.den);
        RationalT::new(num, den)
    }
    fn sub(&self, other: &RationalT) -> RationalT {
        let num = self.num.mul(&other.den).sub(&other.num.mul(&self.den));
        let den = self.den.mul(&other.den);
        RationalT::new(num, den)
    }
    fn mul(&self, other: &RationalT) -> RationalT { RationalT::new(self.num.mul(&other.num), self.den.mul(&other.den)) }
    fn div(&self, other: &RationalT) -> RationalT {
        if other.is_zero() { panic!("RationalT: division by zero"); }
        RationalT::new(self.num.mul(&other.den), self.den.mul(&other.num))
    }
    fn cmp(&self, other: &RationalT) -> std::cmp::Ordering {
        let lhs = self.num.mul(&other.den);
        let rhs = other.num.mul(&self.den);
        lhs.cmp(&rhs)
    }
    fn eq(&self, other: &RationalT) -> bool { self.cmp(other) == std::cmp::Ordering::Equal }
    fn to_bigint_if_integer(&self) -> Option<BigIntT> {
        if self.den.eq(&BigIntT::from_i64(1)) { Some(self.num.clone()) } else { None }
    }
    fn to_f64(&self) -> f64 { nt_bigint_to_f64_lossy(&self.num) / nt_bigint_to_f64_lossy(&self.den) }
}

fn nt_bigint_to_f64_lossy(b: &BigIntT) -> f64 { b.to_string().parse::<f64>().unwrap_or(f64::NAN) }

#[derive(Debug, Clone, PartialEq)]
enum NumT { Int(i64), Float(f64), Big(BigIntT), Rat(RationalT) }

impl NumT {
    fn rank(&self) -> u8 { match self { NumT::Int(_) => 0, NumT::Big(_) => 1, NumT::Rat(_) => 2, NumT::Float(_) => 3 } }
    fn to_bigint(&self) -> BigIntT { match self { NumT::Int(n) => BigIntT::from_i64(*n), NumT::Big(b) => b.clone(), _ => panic!("NumT::to_bigint: not integer-valued") } }
    fn to_rational(&self) -> RationalT {
        match self {
            NumT::Int(n) => RationalT::from_i64_pair(*n, 1),
            NumT::Big(b) => RationalT::new(b.clone(), BigIntT::from_i64(1)),
            NumT::Rat(r) => r.clone(),
            NumT::Float(_) => panic!("NumT::to_rational: not exact"),
        }
    }
    fn to_f64(&self) -> f64 {
        match self { NumT::Int(n) => *n as f64, NumT::Float(f) => *f, NumT::Big(b) => nt_bigint_to_f64_lossy(b), NumT::Rat(r) => r.to_f64() }
    }
    fn promote_pair(a: &NumT, b: &NumT) -> (NumT, NumT) {
        let ra = a.rank(); let rb = b.rank();
        if ra == 3 || rb == 3 { return (NumT::Float(a.to_f64()), NumT::Float(b.to_f64())); }
        if ra == 2 || rb == 2 { return (NumT::Rat(a.to_rational()), NumT::Rat(b.to_rational())); }
        if ra == 1 || rb == 1 { return (NumT::Big(a.to_bigint()), NumT::Big(b.to_bigint())); }
        (a.clone(), b.clone())
    }
    fn normalize(self) -> NumT {
        match self {
            NumT::Big(b) => match nt_i64_from_bigint(&b) { Some(n) => NumT::Int(n), None => NumT::Big(b) },
            NumT::Rat(r) => match r.to_bigint_if_integer() { Some(b) => NumT::Big(b).normalize(), None => NumT::Rat(r) },
            other => other,
        }
    }
    fn add(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_add(y) { Some(v) => NumT::Int(v), None => NumT::Big(BigIntT::from_i64(x).add(&BigIntT::from_i64(y))) },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.add(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.add(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x + y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }
    fn sub(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_sub(y) { Some(v) => NumT::Int(v), None => NumT::Big(BigIntT::from_i64(x).sub(&BigIntT::from_i64(y))) },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.sub(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.sub(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x - y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }
    fn mul(&self, other: &NumT) -> NumT {
        let (a, b) = NumT::promote_pair(self, other);
        let result = match (a, b) {
            (NumT::Int(x), NumT::Int(y)) => match x.checked_mul(y) { Some(v) => NumT::Int(v), None => NumT::Big(BigIntT::from_i64(x).mul(&BigIntT::from_i64(y))) },
            (NumT::Big(x), NumT::Big(y)) => NumT::Big(x.mul(&y)),
            (NumT::Rat(x), NumT::Rat(y)) => NumT::Rat(x.mul(&y)),
            (NumT::Float(x), NumT::Float(y)) => NumT::Float(x * y),
            _ => unreachable!("promote_pair always yields same-kind pairs"),
        };
        result.normalize()
    }
    fn is_zero(&self) -> bool { match self { NumT::Int(n) => *n == 0, NumT::Float(f) => *f == 0.0, NumT::Big(b) => b.is_zero(), NumT::Rat(r) => r.is_zero() } }
    fn negate(&self) -> NumT {
        match self {
            NumT::Int(x) => match x.checked_neg() { Some(r) => NumT::Int(r), None => NumT::Big(BigIntT::from_i64(*x).negate()) },
            NumT::Float(x) => NumT::Float(-x),
            NumT::Big(b) => NumT::Big(b.negate()),
            NumT::Rat(r) => NumT::Rat(RationalT::new(r.num.negate(), r.den.clone())),
        }
    }
}

fn nt_i64_from_bigint(b: &BigIntT) -> Option<i64> { b.to_string().parse::<i64>().ok() }

#[derive(Debug, Clone, PartialEq)]
struct ComplexT { re: Box<NumT>, im: Box<NumT> }

impl ComplexT {
    fn new(re: NumT, im: NumT) -> Self { ComplexT { re: Box::new(re), im: Box::new(im) } }
    fn add(&self, other: &ComplexT) -> ComplexT { ComplexT::new(self.re.add(&other.re), self.im.add(&other.im)) }
    fn sub(&self, other: &ComplexT) -> ComplexT { ComplexT::new(self.re.sub(&other.re), self.im.sub(&other.im)) }
    fn mul(&self, other: &ComplexT) -> ComplexT {
        let ac = self.re.mul(&other.re);
        let bd = self.im.mul(&other.im);
        let ad = self.re.mul(&other.im);
        let bc = self.im.mul(&other.re);
        ComplexT::new(ac.sub(&bd), ad.add(&bc))
    }
    fn div(&self, other: &ComplexT) -> ComplexT {
        let denom = other.re.mul(&other.re).add(&other.im.mul(&other.im));
        if denom.is_zero() { panic!("ComplexT: division by zero (zero-magnitude divisor)"); }
        let num_re = self.re.mul(&other.re).add(&self.im.mul(&other.im));
        let num_im = self.im.mul(&other.re).sub(&self.re.mul(&other.im));
        if let Some(denom_big) = nt_to_bigint_exact(&denom) {
            if let (Some(nre), Some(nim)) = (nt_to_bigint_exact(&num_re), nt_to_bigint_exact(&num_im)) {
                let re = NumT::Rat(RationalT::new(nre, denom_big.clone())).normalize();
                let im = NumT::Rat(RationalT::new(nim, denom_big)).normalize();
                return ComplexT::new(re, im);
            }
        }
        let d = denom.to_f64();
        ComplexT::new(NumT::Float(num_re.to_f64() / d), NumT::Float(num_im.to_f64() / d))
    }
    fn to_real_if_zero_imaginary(&self) -> Option<NumT> { if self.im.is_zero() { Some((*self.re).clone()) } else { None } }
}

fn nt_to_bigint_exact(v: &NumT) -> Option<BigIntT> {
    match v { NumT::Int(n) => Some(BigIntT::from_i64(*n)), NumT::Big(b) => Some(b.clone()), NumT::Rat(r) => r.to_bigint_if_integer(), NumT::Float(_) => None }
}

// ===== Value <-> tower bridge, and Value-level as_number/as_bool/display/arith =====

fn nt_from_value(v: &Value) -> Result<NumT, String> {
    match v {
        Value::Int(n) => Ok(NumT::Int(*n)),
        Value::Float(n) => Ok(NumT::Float(*n)),
        Value::Number(n) => Ok(NumT::Float(*n)),
        Value::BigInt(b) => Ok(NumT::Big(b.clone())),
        Value::Rational(r) => Ok(NumT::Rat(r.clone())),
        Value::Unit => Ok(NumT::Int(0)),
        _ => Err("expected number".to_string()),
    }
}
fn nt_to_value(n: NumT) -> Value {
    match n {
        NumT::Int(x) => Value::Int(x),
        NumT::Float(x) => Value::Float(x),
        NumT::Big(b) => Value::BigInt(b),
        NumT::Rat(r) => Value::Rational(r),
    }
}
fn nt_to_complex(v: &Value) -> Result<ComplexT, String> {
    match v {
        Value::Complex(c) => Ok(c.clone()),
        other => Ok(ComplexT::new(nt_from_value(other)?, NumT::Int(0))),
    }
}
fn nt_normalize_complex(c: ComplexT) -> Value {
    match c.to_real_if_zero_imaginary() {
        Some(n) => nt_to_value(n.normalize()),
        None => Value::Complex(c),
    }
}

impl Value {
    fn as_number(&self) -> Result<f64, String> {
        match self {
            Value::Number(n) => Ok(*n),
            Value::Int(n) => Ok(*n as f64),
            Value::Float(n) => Ok(*n),
            Value::BigInt(b) => Ok(nt_bigint_to_f64_lossy(b)),
            Value::Rational(r) => Ok(r.to_f64()),
            Value::Complex(c) => Ok(c.re.to_f64()),
            Value::Unit => Ok(0.0),
            _ => Err("expected number".into()),
        }
    }
    fn as_bool(&self) -> Result<bool, String> {
        match self {
            Value::Bool(b) => Ok(*b),
            Value::Unit => Ok(false),
            Value::Number(n) => Ok(*n != 0.0),
            Value::Int(n) => Ok(*n != 0),
            Value::Float(n) => Ok(*n != 0.0),
            Value::BigInt(b) => Ok(!b.is_zero()),
            Value::Rational(r) => Ok(!r.is_zero()),
            Value::Complex(_) => Ok(true),
            Value::String(s) => Ok(!s.is_empty()),
            Value::List(xs) => Ok(!xs.is_empty()),
            Value::Object(map) => Ok(!map.is_empty()),
            Value::Closure { .. } => Ok(true),
        }
    }
}

fn nt_value_to_string(v: &Value) -> String {
    match v {
        Value::Unit => String::new(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => if n.fract()==0.0 { format!("{}", *n as i64) } else { n.to_string() },
        Value::Int(n) => n.to_string(),
        Value::Float(n) => if n.fract()==0.0 && n.is_finite() { format!("{}", *n as i64) } else { n.to_string() },
        Value::BigInt(b) => b.to_string(),
        Value::Rational(r) => format!("{}/{}", r.num, r.den),
        Value::Complex(c) => format!("{}+{}i", nt_num_to_string(&c.re), nt_num_to_string(&c.im)),
        Value::String(s) => s.clone(),
        Value::List(xs) => { let parts: Vec<String> = xs.iter().map(nt_value_to_string).collect(); format!("[{}]", parts.join(", ")) }
        Value::Object(map) => {
            let mut kvs: Vec<String> = map.iter().map(|(k,v)| format!("{}: {}", k, nt_value_to_string(v))).collect();
            kvs.sort();
            format!("{{{}}}", kvs.join(", "))
        }
        Value::Closure { .. } => "<closure>".into(),
    }
}
fn nt_num_to_string(n: &NumT) -> String {
    match n {
        NumT::Int(x) => x.to_string(),
        NumT::Float(x) => if x.fract()==0.0 && x.is_finite() { format!("{}", *x as i64) } else { x.to_string() },
        NumT::Big(b) => b.to_string(),
        NumT::Rat(r) => format!("{}/{}", r.num, r.den),
    }
}

fn display_value(v: &Value) -> String { nt_value_to_string(v) }
fn to_s(v: &Value) -> String { nt_value_to_string(v) }

fn add(a:&Value,b:&Value)->Result<Value,String>{
    match (a,b) {
        (Value::String(sa), _) => Ok(Value::String(format!("{}{}", sa, to_s(b)))),
        (_, Value::String(sb)) => Ok(Value::String(format!("{}{}", to_s(a), sb))),
        (Value::Complex(_), _) | (_, Value::Complex(_)) => Ok(nt_normalize_complex(nt_to_complex(a)?.add(&nt_to_complex(b)?))),
        _ => Ok(nt_to_value(nt_from_value(a)?.add(&nt_from_value(b)?))),
    }
}
fn sub(a:&Value,b:&Value)->Result<Value,String>{
    match (a,b) {
        (Value::Complex(_), _) | (_, Value::Complex(_)) => Ok(nt_normalize_complex(nt_to_complex(a)?.sub(&nt_to_complex(b)?))),
        _ => Ok(nt_to_value(nt_from_value(a)?.sub(&nt_from_value(b)?))),
    }
}
fn mul(a:&Value,b:&Value)->Result<Value,String>{
    match (a,b) {
        (Value::Complex(_), _) | (_, Value::Complex(_)) => Ok(nt_normalize_complex(nt_to_complex(a)?.mul(&nt_to_complex(b)?))),
        _ => Ok(nt_to_value(nt_from_value(a)?.mul(&nt_from_value(b)?))),
    }
}
fn div(a:&Value,b:&Value)->Result<Value,String>{
    if matches!(a, Value::Complex(_)) || matches!(b, Value::Complex(_)) {
        return Ok(nt_normalize_complex(nt_to_complex(a)?.div(&nt_to_complex(b)?)));
    }
    let na = nt_from_value(a)?; let nb = nt_from_value(b)?;
    let (pa, pb) = NumT::promote_pair(&na, &nb);
    match (pa, pb) {
        (NumT::Float(x), NumT::Float(y)) => Ok(Value::Float(x / y)),
        (NumT::Int(x), NumT::Int(y)) => {
            if y == 0 { return Err("division by zero".to_string()); }
            if x % y == 0 { Ok(Value::Int(x / y)) } else { Ok(nt_to_value(NumT::Rat(RationalT::from_i64_pair(x, y)).normalize())) }
        }
        (NumT::Big(x), NumT::Big(y)) => {
            if y.is_zero() { return Err("division by zero".to_string()); }
            let (q, r) = x.div_rem(&y);
            if r.is_zero() { Ok(nt_to_value(NumT::Big(q).normalize())) } else { Ok(nt_to_value(NumT::Rat(RationalT::new(x, y)).normalize())) }
        }
        (NumT::Rat(x), NumT::Rat(y)) => {
            if y.is_zero() { return Err("division by zero".to_string()); }
            Ok(nt_to_value(NumT::Rat(x.div(&y)).normalize()))
        }
        _ => Err("type error in div".to_string()),
    }
}
fn modu(a:&Value,b:&Value)->Result<Value,String>{
    if matches!(a, Value::Complex(_)) || matches!(b, Value::Complex(_)) { return Err("modulo not supported for complex".to_string()); }
    let na = nt_from_value(a)?; let nb = nt_from_value(b)?;
    let (pa, pb) = NumT::promote_pair(&na, &nb);
    match (pa, pb) {
        (NumT::Float(x), NumT::Float(y)) => Ok(Value::Float(x % y)),
        (NumT::Int(x), NumT::Int(y)) => { if y == 0 { return Err("modulo by zero".to_string()); } Ok(Value::Int(x % y)) }
        (NumT::Big(x), NumT::Big(y)) => {
            if y.is_zero() { return Err("modulo by zero".to_string()); }
            let (_, r) = x.div_rem(&y);
            Ok(nt_to_value(NumT::Big(r).normalize()))
        }
        (NumT::Rat(x), NumT::Rat(y)) => {
            if y.is_zero() { return Err("modulo by zero".to_string()); }
            let common = x.num.mul(&y.den);
            let rhs = y.num.mul(&x.den);
            let (_, rem) = common.div_rem(&rhs);
            Ok(nt_to_value(NumT::Rat(RationalT::new(rem, x.den.mul(&y.den))).normalize()))
        }
        _ => Err("type error in mod".to_string()),
    }
}
fn neg(a:&Value)->Result<Value,String>{
    match a {
        Value::Int(n) => match n.checked_neg() { Some(r) => Ok(Value::Int(r)), None => Ok(nt_to_value(NumT::Big(BigIntT::from_i64(*n).negate()).normalize())) },
        Value::Float(n) => Ok(Value::Float(-n)),
        Value::Number(n) => Ok(Value::Number(-n)),
        Value::BigInt(b) => Ok(nt_to_value(NumT::Big(b.negate()).normalize())),
        Value::Rational(r) => Ok(nt_to_value(NumT::Rat(RationalT::new(r.num.negate(), r.den.clone())).normalize())),
        Value::Complex(c) => Ok(nt_normalize_complex(ComplexT::new(c.re.negate(), c.im.negate()))),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("expected number".to_string()),
    }
}
fn as_bits(v:&Value)->Result<i64,String>{
    match v { Value::Int(n) => Ok(*n), Value::Number(n) => Ok(*n as i64), _ => Err("expected an integer".into()) }
}
fn bitand(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? & as_bits(b)?)) }
fn bitor(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? | as_bits(b)?)) }
fn bitxor(a:&Value,b:&Value)->Result<Value,String>{ Ok(Value::Int(as_bits(a)? ^ as_bits(b)?)) }
fn bitnot(a:&Value)->Result<Value,String>{ Ok(Value::Int(!as_bits(a)?)) }
fn shl(a:&Value,b:&Value)->Result<Value,String>{
    let x=as_bits(a)?; let n=as_bits(b)?;
    if !(0..64).contains(&n) { return Err(format!("shl: shift amount {} out of range 0..63", n)); }
    Ok(Value::Int(x<<n))
}
fn shr(a:&Value,b:&Value)->Result<Value,String>{
    let x=as_bits(a)?; let n=as_bits(b)?;
    if !(0..64).contains(&n) { return Err(format!("shr: shift amount {} out of range 0..63", n)); }
    Ok(Value::Int(x>>n))
}
fn cmp(k:&BinOpKind,a:&Value,b:&Value)->Result<Value,String>{
    use BinOpKind::*;
    if let (Value::String(x), Value::String(y)) = (a, b) {
        let res = match k { Eq=>x==y, Ne=>x!=y, Lt=>x<y, Le=>x<=y, Gt=>x>y, Ge=>x>=y, _=>false };
        return Ok(Value::Bool(res));
    }
    let na = nt_from_value(a).ok();
    let nb = nt_from_value(b).ok();
    if let (Some(na), Some(nb)) = (na, nb) {
        let (pa, pb) = NumT::promote_pair(&na, &nb);
        let ord = match (&pa, &pb) {
            (NumT::Int(x), NumT::Int(y)) => x.cmp(y),
            (NumT::Float(x), NumT::Float(y)) => x.partial_cmp(y).unwrap_or(std::cmp::Ordering::Equal),
            (NumT::Big(x), NumT::Big(y)) => x.cmp(y),
            (NumT::Rat(x), NumT::Rat(y)) => x.cmp(y),
            _ => std::cmp::Ordering::Equal,
        };
        let res = match k { Eq=>ord==std::cmp::Ordering::Equal, Ne=>ord!=std::cmp::Ordering::Equal, Lt=>ord==std::cmp::Ordering::Less, Le=>ord!=std::cmp::Ordering::Greater, Gt=>ord==std::cmp::Ordering::Greater, Ge=>ord!=std::cmp::Ordering::Less, _=>false };
        return Ok(Value::Bool(res));
    }
    if matches!(a, Value::Complex(_)) || matches!(b, Value::Complex(_)) {
        let ca = nt_to_complex(a)?; let cb = nt_to_complex(b)?;
        let eq = ca == cb;
        let res = match k { Eq=>eq, Ne=>!eq, _=>false };
        return Ok(Value::Bool(res));
    }
    let res = match k { Eq=>a==b, Ne=>a!=b, _=>false };
    Ok(Value::Bool(res))
}
fn type_of_impl(args: &[Value]) -> Value {
    let v = match args.get(0) { Some(v) => v, None => return Value::String("unit".to_string()) };
    let s = match v {
        Value::Unit => "unit",
        Value::Bool(_) => "bool",
        Value::Number(_) => "float",
        Value::Int(_) => "int",
        Value::Float(_) => "float",
        Value::BigInt(_) => "bigint",
        Value::Rational(_) => "rational",
        Value::Complex(_) => "complex",
        Value::String(_) => "string",
        Value::List(_) => "list",
        Value::Object(_) => "object",
        Value::Closure{..} => "closure",
    };
    Value::String(s.to_string())
}
"##;

    // Stage 39 -- math library primitives, mirroring `ir/hosts.rs`'s
    // `host_sqrt`/`host_pow`/etc but operating on the emitted program's own
    // `Value`/`NumT`/`BigIntT`/`RationalT`/`ComplexT` types (reusing the
    // `PRELUDE_NUMERIC_TOWER` building blocks rather than re-deriving BigInt
    // sqrt/pow from scratch). Always paired with `numeric_tower` via
    // `CROSS_CHUNK_EDGES` (see that table's doc comment) so these types exist
    // whenever this chunk's text is present.
    //
    // Judgment call (documented, not a bug): `Host::call`'s existing
    // `host_coerce_arg` (see the note above `impl Host`) flattens `Value::Int`
    // and `Value::Float` down to `Value::Number(f64)` at the host-call
    // boundary for every non-arithmetic host function, math's primitives
    // included -- only `BigInt`/`Rational`/`Complex` survive that boundary
    // unchanged. So a small literal like `sqrt(4)` arrives here as
    // `Value::Number(4.0)`, not `Value::Int(4)`; exactness for perfect
    // squares/integer powers is recovered by treating a whole-valued
    // `Value::Number` the same as an `Int` would be, which is exact for any
    // magnitude that survives an f64 round-trip and degrades gracefully (falls
    // back to the float path) beyond that -- already-promoted `BigInt`/
    // `Rational` values (e.g. the result of prior arithmetic) keep full
    // exactness regardless, since those variants are untouched by coercion.
    const PRELUDE_MATH: &'static str = r##"fn math_num_decimal_digits(n: &BigIntT) -> usize {
    let s = n.to_string();
    s.trim_start_matches('-').len()
}

fn math_pow10(exp: usize) -> BigIntT {
    let mut r = BigIntT::from_i64(1);
    let ten = BigIntT::from_i64(10);
    for _ in 0..exp { r = r.mul(&ten); }
    r
}

// Floor of the true integer square root via Newton's method, for a
// non-negative BigIntT. Mirrors ir/hosts.rs's bigint_isqrt.
fn math_isqrt(n: &BigIntT) -> BigIntT {
    if n.is_zero() { return BigIntT::zero(); }
    let digits = math_num_decimal_digits(n);
    let mut x = math_pow10(digits / 2 + 1);
    loop {
        let (q, _) = n.div_rem(&x);
        let y = x.add(&q);
        let (y, _) = y.div_rem(&BigIntT::from_i64(2));
        if BigIntT::cmp(&y, &x) != std::cmp::Ordering::Less { break; }
        x = y;
    }
    x
}

fn math_is_negative(v: &Value) -> bool {
    match v {
        Value::Int(n) => *n < 0,
        Value::Float(f) => *f < 0.0,
        Value::Number(f) => *f < 0.0,
        Value::BigInt(b) => b.is_negative(),
        Value::Rational(r) => r.num.is_negative(),
        _ => false,
    }
}

fn math_sqrt_nonneg(v: &Value) -> Result<Value, String> {
    match v {
        Value::Int(n) => {
            let bi = BigIntT::from_i64(*n);
            let r = math_isqrt(&bi);
            if r.mul(&r).eq(&bi) { Ok(nt_to_value(NumT::Big(r).normalize())) } else { Ok(Value::Float((*n as f64).sqrt())) }
        }
        Value::Number(f) if f.fract() == 0.0 && f.abs() < 9.0e15 => {
            let n = *f as i64;
            let bi = BigIntT::from_i64(n);
            let r = math_isqrt(&bi);
            if r.mul(&r).eq(&bi) { Ok(nt_to_value(NumT::Big(r).normalize())) } else { Ok(Value::Float(f.sqrt())) }
        }
        Value::Number(f) => Ok(Value::Number(f.sqrt())),
        Value::BigInt(b) => {
            let r = math_isqrt(b);
            if r.mul(&r).eq(b) { Ok(nt_to_value(NumT::Big(r).normalize())) } else { Ok(Value::Float(v.as_number()?.sqrt())) }
        }
        Value::Rational(rat) => {
            let rn = math_isqrt(&rat.num);
            let rd = math_isqrt(&rat.den);
            if rn.mul(&rn).eq(&rat.num) && rd.mul(&rd).eq(&rat.den) {
                Ok(nt_to_value(NumT::Rat(RationalT::new(rn, rd)).normalize()))
            } else {
                Ok(Value::Float(v.as_number()?.sqrt()))
            }
        }
        Value::Float(f) => Ok(Value::Float(f.sqrt())),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("sqrt: expected numeric value".to_string()),
    }
}

fn math_sqrt(v: &Value) -> Result<Value, String> {
    if matches!(v, Value::Complex(_)) { return Err("sqrt: complex input not supported".to_string()); }
    if math_is_negative(v) {
        let pos = neg(v)?;
        let root = math_sqrt_nonneg(&pos)?;
        Ok(nt_normalize_complex(ComplexT::new(NumT::Int(0), nt_from_value(&root)?)))
    } else {
        math_sqrt_nonneg(v)
    }
}

fn math_exact_base(v: &Value) -> Option<Value> {
    match v {
        Value::Int(_) | Value::BigInt(_) | Value::Rational(_) => Some(v.clone()),
        Value::Number(f) if f.fract() == 0.0 && f.abs() < 9.0e15 => Some(Value::Int(*f as i64)),
        _ => None,
    }
}

fn math_exp_as_i64(v: &Value) -> Option<i64> {
    match v {
        Value::Int(n) => Some(*n),
        Value::BigInt(b) => b.to_string().parse::<i64>().ok(),
        Value::Number(f) if f.fract() == 0.0 && f.abs() < 9.0e15 => Some(*f as i64),
        _ => None,
    }
}

fn math_int_pow_exact(base: &Value, exp: i64) -> Result<Value, String> {
    if exp == 0 { return Ok(Value::Int(1)); }
    if exp < 0 {
        let pos = math_int_pow_exact(base, -exp)?;
        return div(&Value::Int(1), &pos);
    }
    let mut result = Value::Int(1);
    let mut b = base.clone();
    let mut e = exp as u64;
    while e > 0 {
        if e & 1 == 1 { result = mul(&result, &b)?; }
        e >>= 1;
        if e > 0 { b = mul(&b, &b)?; }
    }
    Ok(result)
}

fn math_pow(args: &[Value]) -> Result<Value, String> {
    if args.len() != 2 { return Err("pow: expected 2 args".to_string()); }
    if let (Some(b), Some(e)) = (math_exact_base(&args[0]), math_exp_as_i64(&args[1])) {
        return math_int_pow_exact(&b, e);
    }
    let bf = args[0].as_number()?;
    let ef = args[1].as_number()?;
    Ok(Value::Float(bf.powf(ef)))
}

fn math_round_f(f: f64, mode: &str) -> f64 {
    match mode { "floor" => f.floor(), "ceil" => f.ceil(), "round" => f.round(), "trunc" => f.trunc(), _ => f }
}

fn math_round_like(v: &Value, mode: &str) -> Result<Value, String> {
    match v {
        Value::Int(_) | Value::BigInt(_) => Ok(v.clone()),
        Value::Number(f) if f.fract() == 0.0 => Ok(v.clone()),
        Value::Rational(r) => {
            let (q, rem) = r.num.div_rem(&r.den);
            let n_is_neg = r.num.is_negative();
            let n_is_pos = !r.num.is_zero() && !n_is_neg;
            let result = match mode {
                "trunc" => q,
                "floor" => if !rem.is_zero() && n_is_neg { q.sub(&BigIntT::from_i64(1)) } else { q },
                "ceil" => if !rem.is_zero() && n_is_pos { q.add(&BigIntT::from_i64(1)) } else { q },
                "round" => {
                    let two_rem = rem.mul(&BigIntT::from_i64(2));
                    let two_rem_abs = if two_rem.is_negative() { two_rem.negate() } else { two_rem };
                    let past_half = BigIntT::cmp(&two_rem_abs, &r.den) != std::cmp::Ordering::Less;
                    if past_half { if n_is_neg { q.sub(&BigIntT::from_i64(1)) } else { q.add(&BigIntT::from_i64(1)) } } else { q }
                }
                _ => q,
            };
            Ok(nt_to_value(NumT::Big(result).normalize()))
        }
        Value::Float(f) => Ok(Value::Float(math_round_f(*f, mode))),
        Value::Number(f) => Ok(Value::Number(math_round_f(*f, mode))),
        Value::Unit => Ok(Value::Int(0)),
        _ => Err(format!("{}: expected numeric value", mode)),
    }
}

fn math_abs(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("abs: expected 1 arg".to_string())?;
    match v {
        Value::Int(_) | Value::BigInt(_) | Value::Rational(_) => {
            if math_is_negative(v) { neg(v) } else { Ok(v.clone()) }
        }
        Value::Number(f) => Ok(Value::Number(f.abs())),
        Value::Float(f) => Ok(Value::Float(f.abs())),
        Value::Complex(c) => {
            let re2 = nt_to_value(c.re.mul(&c.re));
            let im2 = nt_to_value(c.im.mul(&c.im));
            let sum = add(&re2, &im2)?;
            math_sqrt(&sum)
        }
        Value::Unit => Ok(Value::Int(0)),
        _ => Err("abs: expected numeric value".to_string()),
    }
}

fn math_numeric_kind(args: &[Value]) -> Result<Value, String> {
    let v = args.get(0).ok_or("numeric_kind: expected 1 arg".to_string())?;
    let s = match v {
        Value::Int(_) => "int",
        Value::Number(f) => if f.fract() == 0.0 { "int" } else { "float" },
        Value::Float(_) => "float",
        Value::BigInt(_) => "bigint",
        Value::Rational(_) => "rational",
        Value::Complex(_) => "complex",
        _ => "other",
    };
    Ok(Value::String(s.to_string()))
}

fn host_call_math_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
        "sqrt" => math_sqrt(args.get(0).ok_or("sqrt: expected 1 arg")?),
        "pow" => math_pow(args),
        "sin" => Ok(Value::Float(arg_num(args, 0, "sin")?.sin())),
        "cos" => Ok(Value::Float(arg_num(args, 0, "cos")?.cos())),
        "tan" => Ok(Value::Float(arg_num(args, 0, "tan")?.tan())),
        "asin" => Ok(Value::Float(arg_num(args, 0, "asin")?.asin())),
        "acos" => Ok(Value::Float(arg_num(args, 0, "acos")?.acos())),
        "atan" => Ok(Value::Float(arg_num(args, 0, "atan")?.atan())),
        "atan2" => Ok(Value::Float(arg_num(args, 0, "atan2")?.atan2(arg_num(args, 1, "atan2")?))),
        "log" => Ok(Value::Float(arg_num(args, 0, "log")?.ln())),
        "exp" => Ok(Value::Float(arg_num(args, 0, "exp")?.exp())),
        "floor" => math_round_like(args.get(0).ok_or("floor: expected 1 arg")?, "floor"),
        "ceil" => math_round_like(args.get(0).ok_or("ceil: expected 1 arg")?, "ceil"),
        "round" => math_round_like(args.get(0).ok_or("round: expected 1 arg")?, "round"),
        "trunc" => math_round_like(args.get(0).ok_or("trunc: expected 1 arg")?, "trunc"),
        "abs" => math_abs(args),
        "numeric_kind" => math_numeric_kind(args),
        _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_math(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "sqrt" | "pow" | "sin" | "cos" | "tan" | "asin" | "acos" | "atan" | "atan2" | "log" | "exp"
        | "floor" | "ceil" | "round" | "trunc" | "abs" | "numeric_kind" => Some(host_call_math_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_STRINGS_EXT: &'static str = r##"fn host_call_strings_ext_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"char_code" => {
                // char_code(string, index) -> Number code point, or -1 if out of range
                if args.len() != 2 { return Err("char_code: expected 2 args".into()); }
                let s = match &args[0] { Value::String(s) => s.clone(), v => to_s(v) };
                let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(t) => t.parse::<usize>().unwrap_or(usize::MAX), _ => usize::MAX };
                if s.is_ascii() {
                    return Ok(Value::Number(match s.as_bytes().get(idx) { Some(b) => *b as f64, None => -1.0 }));
                }
                match s.chars().nth(idx) {
                    Some(c) => Ok(Value::Number(c as u32 as f64)),
                    None => Ok(Value::Number(-1.0)),
                }
            }
            "substr" => {
                // substr(string, start, len) -> String slice by chars (clamped)
                if args.len() != 3 { return Err("substr: expected 3 args".into()); }
                let s = match &args[0] { Value::String(s) => s.clone(), v => to_s(v) };
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
            "chr" => {
                // chr(code) -> 1-char string (empty for invalid code points)
                let n = match args.get(0) { Some(Value::Number(n)) => *n, Some(Value::String(s)) => s.trim().parse::<f64>().unwrap_or(-1.0), _ => -1.0 };
                if n < 0.0 { return Ok(Value::String(String::new())); }
                Ok(Value::String(char::from_u32(n as u32).map(|c| c.to_string()).unwrap_or_default()))
            }
            "to_num" => {
                // to_num(value) -> Number (parse string, else 0)
                let v = args.get(0).cloned().unwrap_or(Value::Unit);
                let n = match v {
                    Value::Number(n) => n,
                    Value::String(s) => s.trim().parse::<f64>().unwrap_or(0.0),
                    Value::Bool(b) => if b { 1.0 } else { 0.0 },
                    _ => 0.0,
                };
                Ok(Value::Number(n))
            }
            "hash_string" => {
                // hash_string(s) -> lowercase hex FNV-1a 64-bit digest
                let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                let mut hash: u64 = 0xcbf29ce484222325;
                for b in s.as_bytes() {
                    hash ^= *b as u64;
                    hash = hash.wrapping_mul(0x100000001b3);
                }
                Ok(Value::String(format!("{:016x}", hash)))
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_strings_ext(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "char_code" | "substr" | "chr" | "to_num" | "hash_string" => Some(host_call_strings_ext_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_COLLECTIONS_HANDLES: &'static str = r##"thread_local! {
    static VECS: RefCell<Vec<Vec<Value>>> = RefCell::new(Vec::new());
    static SBUFS: RefCell<Vec<String>> = RefCell::new(Vec::new());
    static ISTRINGS: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

fn host_call_collections_handles_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"vec_new" => {
                let id = VECS.with(|v| { let mut b = v.borrow_mut(); b.push(Vec::new()); b.len() - 1 });
                Ok(Value::Number(id as f64))
            }
            "vec_push" => {
                let id = arg_usize(&args, 0, "vec_push")?;
                let item = args.get(1).cloned().unwrap_or(Value::Unit);
                VECS.with(|v| {
                    let mut b = v.borrow_mut();
                    b.get_mut(id).ok_or_else(|| format!("vec_push: unknown vec {}", id)).map(|xs| xs.push(item))
                })?;
                Ok(Value::Unit)
            }
            "vec_set" => {
                let id = arg_usize(&args, 0, "vec_set")?;
                let idx = arg_usize(&args, 1, "vec_set")?;
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
            "vec_get" => {
                let id = arg_usize(&args, 0, "vec_get")?;
                let idx = arg_usize(&args, 1, "vec_get")?;
                VECS.with(|v| {
                    let b = v.borrow();
                    b.get(id).ok_or_else(|| format!("vec_get: unknown vec {}", id))
                        .map(|xs| xs.get(idx).cloned().unwrap_or(Value::Unit))
                })
            }
            "vec_len" => {
                let id = arg_usize(&args, 0, "vec_len")?;
                VECS.with(|v| {
                    let b = v.borrow();
                    b.get(id).ok_or_else(|| format!("vec_len: unknown vec {}", id)).map(|xs| Value::Number(xs.len() as f64))
                })
            }
            "vec_to_list" => {
                let id = arg_usize(&args, 0, "vec_to_list")?;
                VECS.with(|v| {
                    let b = v.borrow();
                    b.get(id).ok_or_else(|| format!("vec_to_list: unknown vec {}", id)).map(|xs| Value::List(xs.clone()))
                })
            }
            "str_intern" => {
                let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                let id = ISTRINGS.with(|v| { let mut b = v.borrow_mut(); b.push(s); b.len() - 1 });
                Ok(Value::Number(id as f64))
            }
            "sc_len" => {
                let id = arg_usize(&args, 0, "sc_len")?;
                ISTRINGS.with(|v| {
                    let b = v.borrow();
                    b.get(id).ok_or_else(|| format!("sc_len: unknown string {}", id))
                        .map(|s| Value::Number(if s.is_ascii() { s.len() as f64 } else { s.chars().count() as f64 }))
                })
            }
            "sc_code" => {
                let id = arg_usize(&args, 0, "sc_code")?;
                let idx = arg_usize(&args, 1, "sc_code")?;
                ISTRINGS.with(|v| {
                    let b = v.borrow();
                    let s = b.get(id).ok_or_else(|| format!("sc_code: unknown string {}", id))?;
                    if s.is_ascii() {
                        return Ok(Value::Number(match s.as_bytes().get(idx) { Some(c) => *c as f64, None => -1.0 }));
                    }
                    Ok(Value::Number(match s.chars().nth(idx) { Some(c) => c as u32 as f64, None => -1.0 }))
                })
            }
            "sc_char" => {
                let id = arg_usize(&args, 0, "sc_char")?;
                let idx = arg_usize(&args, 1, "sc_char")?;
                ISTRINGS.with(|v| {
                    let b = v.borrow();
                    let s = b.get(id).ok_or_else(|| format!("sc_char: unknown string {}", id))?;
                    if s.is_ascii() {
                        return Ok(match s.as_bytes().get(idx) { Some(c) => Value::String((*c as char).to_string()), None => Value::String(String::new()) });
                    }
                    Ok(match s.chars().nth(idx) { Some(c) => Value::String(c.to_string()), None => Value::String(String::new()) })
                })
            }
            "sb_new" => {
                let id = SBUFS.with(|v| { let mut b = v.borrow_mut(); b.push(String::new()); b.len() - 1 });
                Ok(Value::Number(id as f64))
            }
            "sb_push" => {
                let id = arg_usize(&args, 0, "sb_push")?;
                let text = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                SBUFS.with(|v| {
                    let mut b = v.borrow_mut();
                    b.get_mut(id).ok_or_else(|| format!("sb_push: unknown buffer {}", id)).map(|s| s.push_str(&text))
                })?;
                Ok(Value::Unit)
            }
            "sb_str" => {
                let id = arg_usize(&args, 0, "sb_str")?;
                SBUFS.with(|v| {
                    let b = v.borrow();
                    b.get(id).ok_or_else(|| format!("sb_str: unknown buffer {}", id)).map(|s| Value::String(s.clone()))
                })
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_collections_handles(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "vec_new" | "vec_push" | "vec_set" | "vec_get" | "vec_len" | "vec_to_list" | "str_intern" | "sc_len" | "sc_code" | "sc_char" | "sb_new" | "sb_push" | "sb_str" => Some(host_call_collections_handles_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_FILES: &'static str = r##"fn host_call_files_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"read_file" => {
                // read_file(path) -> String contents
                let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                std::fs::read_to_string(&p).map(Value::String).map_err(|e| format!("read_file: {}: {}", p, e))
            }
            "write_file" => {
                // write_file(path, contents) -> Bool
                let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                let contents = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                if let Some(parent) = std::path::Path::new(&p).parent() { let _ = std::fs::create_dir_all(parent); }
                std::fs::write(&p, contents).map(|_| Value::Bool(true)).map_err(|e| format!("write_file: {}: {}", p, e))
            }
            "touch_file" => {
                // touch_file(path) -> String message (OK <abs> or ERR: <msg>)
                let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
                if p.is_empty() { return Ok(Value::String("ERR: empty path".into())); }
                let path = std::path::Path::new(&p);
                if let Some(par) = path.parent() { let _ = std::fs::create_dir_all(par); }
                let res = std::fs::OpenOptions::new().create(true).write(true).truncate(true).open(&path);
                match res {
                    Ok(_) => {
                        let abs = std::fs::canonicalize(&path).unwrap_or_else(|_| path.to_path_buf());
                        Ok(Value::String(format!("OK {}", abs.display())))
                    }
                    Err(e) => Ok(Value::String(format!("ERR: {}", e)))
                }
            }
            "file_exists" => {
                // file_exists(path) -> "1" or "0"
                let p = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
                let exists = std::path::Path::new(&p).exists();
                Ok(Value::String(if exists { "1".into() } else { "0".into() }))
            }
            "list_dir" => {
                // list_dir(path) -> List of entry names, directories suffixed "/"
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
            "rename_file" => {
                // rename_file(from, to) -> Bool
                let from = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
                let to = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
                if let Some(parent) = std::path::Path::new(&to).parent() { let _ = std::fs::create_dir_all(parent); }
                std::fs::rename(&from, &to).map(|_| Value::Bool(true)).map_err(|e| format!("rename_file: {} -> {}: {}", from, to, e))
            }
            "exec_capture" => {
                // exec_capture(path, [arg1, arg2, ...]) -> stdout of running the
                // program. Trailing string args are passed through as argv to
                // the child. If the process exits with failure, stderr is
                // appended too, so transcripts of failing invocations still
                // show the error.
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
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_files(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "read_file" | "write_file" | "touch_file" | "file_exists" | "list_dir" | "rename_file" | "exec_capture" => Some(host_call_files_inner(name, args)),
        _ => None,
    }
}

"##;

    // `len` (below) returns `Value::Int`, not `Value::Number`/f64: a length
    // is always an exact integer, and callers (e.g. lib/math.patlang's
    // mean()) divide by it expecting exact-Rational division on a
    // non-even split, not silent float contagion. `Value::Int` exists in
    // both of the two mutually-exclusive Value definitions (see the NOTE
    // above `enum Value`), so this is safe regardless of which one a given
    // compiled program selects.
    const PRELUDE_IO_MISC: &'static str = r##"fn host_bin_num(args: &[Value], f: fn(f64,f64)->f64) -> Result<Value, String> {
    let a = args.get(0).ok_or("expected 2 args")?;
    let b = args.get(1).ok_or("expected 2 args")?;
    let an = a.as_number()?; let bn = b.as_number()?;
    Ok(Value::Number(f(an,bn)))
}

fn sed_command(cmd: &str, input: &str) -> String {
    if !cmd.starts_with('s') { return input.to_string(); }
    let mut parts = cmd.splitn(4, '/');
    let _s = parts.next();
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

// Simple interpolation: replace occurrences of #{name} using OBJECTS store vars or event locals if provided in scope.
fn interpolate(input: &str) -> String {
    let mut out = String::new();
    let b = input.as_bytes();
    let mut i = 0usize;
    while i < b.len() {
        if i + 2 < b.len() && b[i] as char == '#' && b[i+1] as char == '{' {
            i += 2; let start = i;
            while i < b.len() && b[i] as char != '}' { i += 1; }
            let key = &input[start..i];
            let val = resolve_interp_var(key);
            out.push_str(&val);
            if i < b.len() && b[i] as char == '}' { i += 1; }
        } else { out.push(b[i] as char); i += 1; }
    }
    out
}

fn resolve_interp_var(key: &str) -> String {
    // Try OBJECTS first (object.name property), then fall back to key itself.
    if let Some((obj, prop)) = key.split_once('.') {
        if let Some(v) = obj_get(obj, prop) { return display_value(&v); }
    } else {
        // No dot: may refer to a plain variable set on a synthetic "__vars" object by handlers.
        if let Some(v) = obj_get("__vars", key) { return display_value(&v); }
    }
    String::new()
}

fn host_call_io_misc_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"now_ms" => {
                // now_ms() -> Number: milliseconds since the Unix epoch
                let ms = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_millis() as f64)
                    .unwrap_or(0.0);
                Ok(Value::Number(ms))
            }
            "byte_length" => {
                // byte_length(s) -> Number of UTF-8 bytes (unlike .length,
                // which counts chars) - for exact HTTP Content-Length framing.
                let s = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                Ok(Value::Number(s.len() as f64))
            }
            "read_line" => {
                // read_line() -> String: one line from stdin, no trailing
                // newline, or "" at EOF.
                use std::io::BufRead;
                let mut line = String::new();
                let n = std::io::stdin().lock().read_line(&mut line).map_err(|e| format!("read_line: {}", e))?;
                if n == 0 { Ok(Value::String(String::new())) } else {
                    while line.ends_with('\n') || line.ends_with('\r') { line.pop(); }
                    Ok(Value::String(line))
                }
            }
            "argv" => {
                // argv() -> List of user arguments (program name stripped)
                let mut rest: Vec<String> = std::env::args().collect();
                if !rest.is_empty() { rest.remove(0); }
                Ok(Value::List(rest.into_iter().map(Value::String).collect()))
            }
            "print" => {
                if let Some(x) = args.get(0) {
                    // Support simple string interpolation for IR runtime: "#{var}"
                    let s = display_value(x);
                    let out = interpolate(&s);
                    println!("{}", out);
                    // Flush so piped consumers (tests, process supervisors) see
                    // output promptly -- stdout is block-buffered when not a tty
                    use std::io::Write;
                    let _ = std::io::stdout().flush();
                }
                Ok(Value::Unit)
            },
            "sed" => {
                // sed("s/pat/repl/[flags]", input)
                let cmd = match args.get(0) { Some(Value::String(s)) => s.as_str(), _ => "" };
                let dv;
                let input: &str = match args.get(1) {
                    Some(Value::String(s)) => s.as_str(),
                    Some(v) => { dv = display_value(v); dv.as_str() },
                    None => "",
                };
                let out = sed_command(cmd, input);
                Ok(Value::String(out))
            },
            "add" => host_bin_num(args, |a,b| a+b),
            "multiply" => host_bin_num(args, |a,b| a*b),
            "subtract" => host_bin_num(args, |a,b| a-b),
            "max" => host_bin_num(args, |a,b| a.max(b)),
            "min" => host_bin_num(args, |a,b| a.min(b)),
            "calculate" => Ok(Value::Number(0.0)),
            "calculate_result" => Ok(Value::Number(0.0)),
            "get_value" => Ok(Value::Number(0.0)),
            "process" => Ok(Value::Bool(true)),
            "validate" => Ok(Value::Bool(true)),
            "len" => {
                let v = args.get(0).cloned().unwrap_or(Value::Unit);
                let n = match v {
                    Value::String(s) => s.chars().count() as i64,
                    Value::List(xs) => xs.len() as i64,
                    Value::Object(m) => m.len() as i64,
                    Value::Unit => 0,
                    _ => 0,
                };
                Ok(Value::Int(n))
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_io_misc(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "now_ms" | "byte_length" | "read_line" | "argv" | "print" | "sed" | "add" | "multiply" | "subtract" | "max" | "min" | "calculate" | "calculate_result" | "get_value" | "process" | "validate" | "len" => Some(host_call_io_misc_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_OO: &'static str = r##"fn host_call_oo_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"new" => {
                if args.len() != 2 { return Ok(Value::Unit); }
                let class = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let name = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
                if !name.is_empty() { ensure_obj(&name, &class); }
                Ok(Value::String(name))
            }
            "set_var" => {
                if args.len() != 2 { return Ok(Value::Unit); }
                let key = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let val = args.get(1).cloned().unwrap_or(Value::Unit);
                if !key.is_empty() {
                    obj_set("__vars", &key, val);
                }
                Ok(Value::Unit)
            }
            "get" => {
                if args.len() != 2 { return Err("expected 2 args".into()); }
                let key = match &args[1] { Value::String(s) => s.clone(), _ => return Err("expected string key".into()) };
                match &args[0] {
                    Value::String(name) => Ok(obj_get(name, &key).unwrap_or(Value::Unit)),
                    Value::Object(map) => Ok(map.get(&key).cloned().unwrap_or(Value::Unit)),
                    _ => Ok(Value::Unit),
                }
            }
            "send" => {
                if args.len() < 2 { return Ok(Value::Unit); }
                let recv = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let method = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
                let rest = &args[2..];
                match method.as_str() {
                    "set" => {
                        if rest.len() != 2 { return Ok(Value::Unit); }
                        let prop = match &rest[0] { Value::String(s) => s.clone(), _ => String::new() };
                        let val = rest[1].clone();
                        if !recv.is_empty() && !prop.is_empty() { obj_set(&recv, &prop, val); }
                        Ok(Value::Unit)
                    }
                    "infer_is_adult" => {
                        // reads age, sets is_adult when >= 18
                        if let Some(Value::Number(age)) = obj_get(&recv, "age") {
                            if age >= 18.0 { obj_set(&recv, "is_adult", Value::Bool(true)); return Ok(Value::Bool(true)); }
                        } else if let Some(Value::String(s)) = obj_get(&recv, "age") {
                            if s.parse::<f64>().unwrap_or(0.0) >= 18.0 { obj_set(&recv, "is_adult", Value::Bool(true)); return Ok(Value::Bool(true)); }
                        }
                        Ok(Value::Bool(false))
                    }
                    "infer_relations" => {
                        // if exists fact("parent", X, recv) then set has_parent true
                        let mut has = false;
                        FACTS.with(|f| {
                            if let Some(v) = f.borrow().get("parent") {
                                has = v.iter().any(|(_, child)| child == &recv);
                            }
                        });
                        if has { obj_set(&recv, "has_parent", Value::Bool(true)); return Ok(Value::Bool(true)); }
                        Ok(Value::Bool(false))
                    }
                    _ => Ok(Value::Unit),
                }
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_oo(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "new" | "set_var" | "get" | "send" => Some(host_call_oo_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_LOGIC: &'static str = r##"thread_local! {
    static FACTS: RefCell<HashMap<String, Vec<(String, String)>>> = RefCell::new(HashMap::new());
    static GOALS: RefCell<Vec<(String, Vec<String>)>> = RefCell::new(Vec::new());
    static TYPE_RULES: RefCell<HashMap<(String, usize), String>> = RefCell::new(HashMap::new());
    static RULES: RefCell<Vec<LogicRule>> = RefCell::new(Vec::new());
    static ACTIONS: RefCell<Vec<GoapAction>> = RefCell::new(Vec::new());
}

use std::collections::HashSet;

#[derive(Clone)]
struct LogicRule { head_pred: String, head_args: Vec<String>, body: Vec<(String, Vec<String>)> }

#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
struct GroundFact { pred: String, args: Vec<String> }

#[derive(Clone)]
struct GoapAction { name: String, preconds: Vec<GroundFact>, add_effects: Vec<GroundFact>, del_effects: Vec<GroundFact>, cost: i64 }

type LogicSubst = HashMap<String, String>;

fn is_logic_var(s: &str) -> bool {
    s.chars().next().map(|c| c.is_ascii_uppercase()).unwrap_or(false)
}

fn logic_walk(term: &str, subst: &LogicSubst) -> String {
    let mut cur = term.to_string();
    let mut hops = 0;
    while is_logic_var(&cur) {
        match subst.get(&cur) {
            Some(next) if next != &cur => { cur = next.clone(); hops += 1; if hops > 1000 { break; } }
            _ => break,
        }
    }
    cur
}

fn unify_args(query_args: &[String], target_args: &[String], subst: &LogicSubst) -> Option<LogicSubst> {
    if query_args.len() != target_args.len() { return None; }
    let mut s = subst.clone();
    for (qa, ta) in query_args.iter().zip(target_args.iter()) {
        let qw = logic_walk(qa, &s);
        let tw = logic_walk(ta, &s);
        if is_logic_var(&qw) {
            if qw != tw { s.insert(qw, tw); }
        } else if is_logic_var(&tw) {
            if tw != qw { s.insert(tw, qw); }
        } else if qw != tw {
            return None;
        }
    }
    Some(s)
}

fn logic_apply_subst(args: &[String], subst: &LogicSubst) -> Vec<String> {
    args.iter().map(|a| logic_walk(a, subst)).collect()
}

const MAX_LOGIC_DEPTH: u32 = 200;
static RULE_RENAME_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

fn fresh_rename(rule: &LogicRule) -> LogicRule {
    let suffix = RULE_RENAME_COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let mut map: HashMap<String, String> = HashMap::new();
    let mut rename = |s: &str, map: &mut HashMap<String, String>| -> String {
        if is_logic_var(s) {
            map.entry(s.to_string()).or_insert_with(|| format!("{}__{}", s, suffix)).clone()
        } else {
            s.to_string()
        }
    };
    let head_args = rule.head_args.iter().map(|a| rename(a, &mut map)).collect();
    let body = rule.body.iter().map(|(p, a)| (p.clone(), a.iter().map(|x| rename(x, &mut map)).collect())).collect();
    LogicRule { head_pred: rule.head_pred.clone(), head_args, body }
}

fn solve_goal(pred: &str, args: &[String], subst: &LogicSubst, depth: u32) -> Vec<LogicSubst> {
    if depth > MAX_LOGIC_DEPTH { return Vec::new(); }
    let candidates: Vec<LogicRule> = RULES.with(|r| r.borrow().iter().filter(|ru| ru.head_pred == pred).cloned().collect());
    let mut results = Vec::new();
    for rule in candidates {
        let rule = fresh_rename(&rule);
        if let Some(s2) = unify_args(args, &rule.head_args, subst) {
            results.extend(resolve_conjuncts(&rule.body, &s2, depth + 1));
        }
    }
    results
}

fn resolve_conjuncts(body: &[(String, Vec<String>)], subst: &LogicSubst, depth: u32) -> Vec<LogicSubst> {
    if body.is_empty() { return vec![subst.clone()]; }
    let (pred, args) = &body[0];
    let rest = &body[1..];
    let applied_args = logic_apply_subst(args, subst);
    let mut out = Vec::new();
    for s2 in solve_goal(pred, &applied_args, subst, depth) {
        out.extend(resolve_conjuncts(rest, &s2, depth));
    }
    out
}

fn value_to_str_list(v: &Value) -> Vec<String> {
    match v {
        Value::List(xs) => xs.iter().map(to_s).collect(),
        other => vec![to_s(other)],
    }
}

fn parse_ground_facts(v: &Value) -> Vec<GroundFact> {
    let items = match v { Value::List(xs) => xs.clone(), _ => Vec::new() };
    let mut out = Vec::new();
    for item in items {
        if let Value::List(pair) = &item {
            if pair.len() == 2 {
                out.push(GroundFact { pred: to_s(&pair[0]), args: value_to_str_list(&pair[1]) });
            }
        }
    }
    out
}

fn current_ground_facts_as_state() -> HashSet<GroundFact> {
    RULES.with(|r| r.borrow().iter()
        .filter(|ru| ru.body.is_empty() && !ru.head_args.iter().any(|a| is_logic_var(a)))
        .map(|ru| GroundFact { pred: ru.head_pred.clone(), args: ru.head_args.clone() })
        .collect())
}

fn apply_subst_to_fact(fact: &GroundFact, subst: &LogicSubst) -> GroundFact {
    GroundFact { pred: fact.pred.clone(), args: logic_apply_subst(&fact.args, subst) }
}

fn ground_action_instances(preconds: &[GroundFact], state: &HashSet<GroundFact>) -> Vec<LogicSubst> {
    fn go(remaining: &[GroundFact], state: &HashSet<GroundFact>, subst: LogicSubst, out: &mut Vec<LogicSubst>) {
        if remaining.is_empty() { out.push(subst); return; }
        let (first, rest) = (&remaining[0], &remaining[1..]);
        let applied = logic_apply_subst(&first.args, &subst);
        for fact in state.iter().filter(|f| f.pred == first.pred) {
            if let Some(s2) = unify_args(&applied, &fact.args, &subst) {
                go(rest, state, s2, out);
            }
        }
    }
    let mut out = Vec::new();
    go(preconds, state, HashMap::new(), &mut out);
    out
}

fn action_instance_label(name: &str, preconds: &[GroundFact], subst: &LogicSubst) -> String {
    let mut seen: Vec<String> = Vec::new();
    for p in preconds {
        for a in &p.args {
            if is_logic_var(a) && !seen.contains(a) { seen.push(a.clone()); }
        }
    }
    if seen.is_empty() { return name.to_string(); }
    let parts: Vec<String> = seen.iter().map(|v| format!("{}={}", v, logic_walk(v, subst))).collect();
    format!("{}({})", name, parts.join(","))
}

fn host_call_logic_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"infer_type_for" => {
                // args: pred, index, class
                if args.len() != 3 { return Ok(Value::Unit); }
                let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let idx = match &args[1] { Value::Number(n) => *n as usize, Value::String(s) => s.parse::<usize>().unwrap_or(0), _ => 0 };
                let class = match &args[2] { Value::String(s) => s.clone(), _ => String::new() };
                TYPE_RULES.with(|tr| { tr.borrow_mut().insert((pred, idx), class); });
                Ok(Value::Unit)
            }
            "fact" => {
                if args.len() != 3 { return Ok(Value::Unit); }
                let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let a = to_s(args.get(1).unwrap_or(&Value::Unit));
                let b = to_s(args.get(2).unwrap_or(&Value::Unit));
                FACTS.with(|f| {
                    let mut m = f.borrow_mut();
                    m.entry(pred).or_insert_with(Vec::new).push((a, b));
                });
                Ok(Value::Unit)
            }
            "goal" => {
                if args.is_empty() { return Ok(Value::Unit); }
                let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let mut items: Vec<String> = Vec::new();
                for a in &args[1..] { items.push(to_s(a)); }
                GOALS.with(|g| { g.borrow_mut().push((pred, items)); });
                Ok(Value::Unit)
            }
            "query" => {
                if args.len() != 3 { return Ok(Value::Number(0.0)); }
                let pred = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let a = to_s(args.get(1).unwrap_or(&Value::Unit));
                let mut count = 0usize;
                let mut bs: Vec<String> = Vec::new();
                FACTS.with(|f| {
                    if let Some(v) = f.borrow().get(&pred) {
                        for (x, b) in v.iter() {
                            if x == &a { count += 1; bs.push(b.clone()); }
                        }
                    }
                });
                // Apply simple type inference rules recorded
                TYPE_RULES.with(|tr| {
                    let rules = tr.borrow();
                    if let Some(class0) = rules.get(&(pred.clone(), 0usize)) { ensure_obj(&a, class0); }
                    if let Some(class1) = rules.get(&(pred.clone(), 1usize)) {
                        for b in bs.iter() { ensure_obj(b, class1); }
                    }
                });
                Ok(Value::Number(count as f64))
            }
"rule_add" => {
                if args.len() != 3 { return Err("rule_add: expected 3 args (head_pred, head_args_list, body_list)".into()); }
                let head_pred = match &args[0] { Value::String(s) => s.clone(), v => to_s(v) };
                let head_args = value_to_str_list(&args[1]);
                let body_items = match &args[2] { Value::List(xs) => xs.clone(), _ => Vec::new() };
                let mut body = Vec::new();
                for item in body_items {
                    if let Value::List(pair) = &item {
                        if pair.len() == 2 {
                            body.push((to_s(&pair[0]), value_to_str_list(&pair[1])));
                        }
                    }
                }
                RULES.with(|r| r.borrow_mut().push(LogicRule { head_pred, head_args, body }));
                Ok(Value::Unit)
            }
            "solve" => {
                if args.len() != 2 { return Err("solve: expected 2 args (pred, args_list)".into()); }
                let pred = match &args[0] { Value::String(s) => s.clone(), v => to_s(v) };
                let query_args = value_to_str_list(&args[1]);
                let empty: LogicSubst = HashMap::new();
                let solutions = solve_goal(&pred, &query_args, &empty, 0);
                let out: Vec<Value> = solutions.iter().map(|s| {
                    Value::List(query_args.iter().map(|a| Value::String(logic_walk(a, s))).collect())
                }).collect();
                Ok(Value::List(out))
            }
            "action_add" => {
                if args.len() != 5 { return Err("action_add: expected 5 args (name, preconds, add_effects, del_effects, cost)".into()); }
                let action_name = match &args[0] { Value::String(s) => s.clone(), v => to_s(v) };
                let preconds = parse_ground_facts(&args[1]);
                let add_effects = parse_ground_facts(&args[2]);
                let del_effects = parse_ground_facts(&args[3]);
                let cost = match &args[4] {
                    Value::Number(n) => n.round() as i64,
                    Value::String(s) => s.parse::<f64>().unwrap_or(1.0).round() as i64,
                    _ => 1,
                };
                ACTIONS.with(|a| a.borrow_mut().push(GoapAction { name: action_name, preconds, add_effects, del_effects, cost }));
                Ok(Value::Unit)
            }
            "plan" => {
                if args.len() != 1 { return Err("plan: expected 1 arg (goal_facts_list)".into()); }
                let goal_facts = parse_ground_facts(&args[0]);
                let actions: Vec<GoapAction> = ACTIONS.with(|a| a.borrow().clone());
                use std::collections::BinaryHeap;
                use std::cmp::Reverse;
                let start_state: HashSet<GroundFact> = current_ground_facts_as_state();
                let mut nodes: Vec<(HashSet<GroundFact>, Vec<String>, i64)> = vec![(start_state, Vec::new(), 0)];
                let mut frontier: BinaryHeap<Reverse<(i64, usize)>> = BinaryHeap::new();
                frontier.push(Reverse((0, 0)));
                let mut visited: HashSet<Vec<GroundFact>> = HashSet::new();
                const NODE_CAP: usize = 5000;
                let mut expansions = 0usize;
                let mut found: Option<Vec<String>> = None;
                while let Some(Reverse((cost, idx))) = frontier.pop() {
                    if expansions >= NODE_CAP { break; }
                    let (state, path, node_cost) = nodes[idx].clone();
                    if node_cost != cost { continue; }
                    expansions += 1;
                    if goal_facts.iter().all(|g| state.contains(g)) { found = Some(path); break; }
                    let mut state_key: Vec<GroundFact> = state.iter().cloned().collect();
                    state_key.sort();
                    if !visited.insert(state_key) { continue; }
                    for action in &actions {
                        for subst in ground_action_instances(&action.preconds, &state) {
                            let mut new_state = state.clone();
                            for d in &action.del_effects { new_state.remove(&apply_subst_to_fact(d, &subst)); }
                            for a2 in &action.add_effects { new_state.insert(apply_subst_to_fact(a2, &subst)); }
                            let mut new_path = path.clone();
                            new_path.push(action_instance_label(&action.name, &action.preconds, &subst));
                            let new_cost = node_cost + action.cost;
                            nodes.push((new_state, new_path, new_cost));
                            frontier.push(Reverse((new_cost, nodes.len() - 1)));
                        }
                    }
                }
                Ok(Value::List(found.unwrap_or_default().into_iter().map(Value::String).collect()))
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_logic(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "infer_type_for" | "fact" | "goal" | "query" | "rule_add" | "solve" | "action_add" | "plan" => Some(host_call_logic_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_CONTRACTS: &'static str = r##"fn host_call_contracts_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"contract_check" => {
                // contract_check(func_name, kind, text, ok) - design-by-contract
                // enforcement, identical semantics to the interpreter's host arm.
                if args.len() != 4 { return Err("contract_check: expected 4 args".into()); }
                let func = match &args[0] { Value::String(s) => s.clone(), _ => String::new() };
                let kind = match &args[1] { Value::String(s) => s.clone(), _ => String::new() };
                let text = match &args[2] { Value::String(s) => s.clone(), _ => String::new() };
                let ok = args[3].as_bool()?;
                if ok {
                    // Record the successful check as a ground fact (empty-body
                    // rule) so DbC contracts become ordinary derivable data --
                    // usable as an A1 rule-body conjunct or an A2 GOAP
                    // precondition, not just a pass/fail side effect.
                    RULES.with(|r| r.borrow_mut().push(LogicRule {
                        head_pred: "contract_holds".to_string(),
                        head_args: vec![func.clone(), format!("{}:{}", kind, text)],
                        body: Vec::new(),
                    }));
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
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_contracts(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "contract_check" => Some(host_call_contracts_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_NETWORKING: &'static str = r##"thread_local! {
    static LISTENERS: RefCell<HashMap<u16, std::net::TcpListener>> = RefCell::new(HashMap::new());
    static CONNS: RefCell<HashMap<usize, std::net::TcpStream>> = RefCell::new(HashMap::new());
    static NEXT_CONN: RefCell<usize> = RefCell::new(1);
}

fn host_call_networking_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"tcp_listen" => {
                // tcp_listen(port) -> Number actual bound port (0 = OS-assigned)
                let port = arg_num(&args, 0, "tcp_listen")? as u16;
                let listener = std::net::TcpListener::bind(("127.0.0.1", port))
                    .map_err(|e| format!("tcp_listen: bind {}: {}", port, e))?;
                let actual = listener.local_addr().map_err(|e| format!("tcp_listen: {}", e))?.port();
                LISTENERS.with(|l| l.borrow_mut().insert(actual, listener));
                Ok(Value::Number(actual as f64))
            }
            "tcp_try_listen" => {
                // tcp_try_listen(port) -> Number port_id, or -1 specifically
                // if the port is already bound elsewhere -- see hosts.rs's
                // host_tcp_try_listen for the full rationale (PatLang has no
                // try/catch, so this is the only graceful way a program can
                // ask "is something already listening here").
                let port = arg_num(&args, 0, "tcp_try_listen")? as u16;
                match std::net::TcpListener::bind(("127.0.0.1", port)) {
                    Ok(listener) => {
                        let actual = listener.local_addr().map_err(|e| format!("tcp_try_listen: {}", e))?.port();
                        LISTENERS.with(|l| l.borrow_mut().insert(actual, listener));
                        Ok(Value::Number(actual as f64))
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::AddrInUse => Ok(Value::Number(-1.0)),
                    Err(e) => Err(format!("tcp_try_listen: bind {}: {}", port, e)),
                }
            }
            "tcp_connect" => {
                // tcp_connect(host, port) -> Number connection id (blocks until connected)
                let host = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("tcp_connect: expected host string".into()) };
                let port = arg_num(&args, 1, "tcp_connect")? as u16;
                let stream = std::net::TcpStream::connect((host.as_str(), port))
                    .map_err(|e| format!("tcp_connect: {}:{}: {}", host, port, e))?;
                let id = NEXT_CONN.with(|n| { let mut b = n.borrow_mut(); let v = *b; *b += 1; v });
                CONNS.with(|c| c.borrow_mut().insert(id, stream));
                Ok(Value::Number(id as f64))
            }
            "tcp_accept" => {
                // tcp_accept(port) -> Number connection id (blocks)
                let port = arg_num(&args, 0, "tcp_accept")? as u16;
                let listener = LISTENERS.with(|l| l.borrow().get(&port).map(|x| x.try_clone()))
                    .ok_or_else(|| format!("tcp_accept: no listener on port {}", port))?
                    .map_err(|e| format!("tcp_accept: {}", e))?;
                let (stream, _) = listener.accept().map_err(|e| format!("tcp_accept: {}", e))?;
                let id = NEXT_CONN.with(|n| { let mut b = n.borrow_mut(); let v = *b; *b += 1; v });
                CONNS.with(|c| c.borrow_mut().insert(id, stream));
                Ok(Value::Number(id as f64))
            }
            "sleep_ms" => {
                let ms = arg_num(&args, 0, "sleep_ms")?.max(0.0) as u64;
                std::thread::sleep(std::time::Duration::from_millis(ms));
                Ok(Value::Unit)
            }
            "tcp_accept_timeout" => {
                // tcp_accept_timeout(port, ms) -> conn id, or -1 on timeout
                let port = arg_num(&args, 0, "tcp_accept_timeout")? as u16;
                let ms = arg_num(&args, 1, "tcp_accept_timeout")?.max(0.0) as u64;
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
            "tcp_read" => {
                // tcp_read(conn) -> String (single read, up to 64 KiB)
                use std::io::Read;
                let id = arg_num(&args, 0, "tcp_read")? as usize;
                let mut stream = CONNS.with(|c| c.borrow().get(&id).map(|s| s.try_clone()))
                    .ok_or_else(|| format!("tcp_read: unknown connection {}", id))?
                    .map_err(|e| format!("tcp_read: {}", e))?;
                let mut buf = vec![0u8; 65536];
                let n = stream.read(&mut buf).map_err(|e| format!("tcp_read: {}", e))?;
                Ok(Value::String(String::from_utf8_lossy(&buf[..n]).to_string()))
            }
            "tcp_write" => {
                // tcp_write(conn, data) -> Bool
                use std::io::Write;
                let id = arg_num(&args, 0, "tcp_write")? as usize;
                let data = match args.get(1) { Some(Value::String(s)) => s.clone(), Some(v) => to_s(v), None => String::new() };
                let mut stream = CONNS.with(|c| c.borrow().get(&id).map(|s| s.try_clone()))
                    .ok_or_else(|| format!("tcp_write: unknown connection {}", id))?
                    .map_err(|e| format!("tcp_write: {}", e))?;
                stream.write_all(data.as_bytes()).map_err(|e| format!("tcp_write: {}", e))?;
                let _ = stream.flush();
                Ok(Value::Bool(true))
            }
            "tcp_close" => {
                use std::io::Read;
                let id = arg_num(&args, 0, "tcp_close")? as usize;
                if let Some(stream) = CONNS.with(|c| c.borrow_mut().remove(&id)) {
                    // Drain unread inbound bytes and half-close so the peer
                    // gets a graceful FIN rather than an RST
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
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_networking(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "tcp_listen" | "tcp_try_listen" | "tcp_connect" | "tcp_accept" | "sleep_ms" | "tcp_accept_timeout" | "tcp_read" | "tcp_write" | "tcp_close" => Some(host_call_networking_inner(name, args)),
        _ => None,
    }
}

"##;

    const PRELUDE_CODEGEN_BOOTSTRAP: &'static str = r##"fn log_to_file(filename: &str, msg: &str) {
    use std::io::Write;
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(filename) {
        let _ = writeln!(f, "{}", msg);
    }
}

fn create_temp_file(name: &str) -> Result<String, String> {
    let mut dir = std::env::temp_dir();
    dir.push("patlang_native");
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let path = dir.join(name);
    std::fs::File::create(&path).map_err(|e| e.to_string())?;
    Ok(path.display().to_string())
}

fn write_to_file(path: &str, content: &str) -> Result<(), String> {
    std::fs::write(path, content).map_err(|e| e.to_string())
}

fn move_or_copy(src: &str, dest: &str) -> Result<(), String> {
    if let Some(parent) = std::path::Path::new(dest).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    match std::fs::rename(src, dest) {
        Ok(_) => Ok(()),
        Err(_) => std::fs::copy(src, dest).map(|_| ()).map_err(|e| e.to_string()),
    }
}

fn file_exists(path: &str) -> bool {
    std::path::Path::new(path).exists()
}

fn host_call_codegen_bootstrap_inner(name: &str, args: &[Value]) -> Result<Value, String> {
    match name {
"parse_tiny_source" => {
                // Return a lightweight Program object carrying the source path for delegation.
                // { type: "Program", source_path: <string> }
                let path = match args.get(0) { Some(Value::String(s)) => s.clone(), Some(v) => display_value(v), None => String::new() };
                let mut m = std::collections::HashMap::new();
                m.insert("type".to_string(), Value::String("Program".to_string()));
                m.insert("source_path".to_string(), Value::String(path));
                Ok(Value::Object(m))
            }
            "lower_and_compile" => {
                // Delegate compilation to the Stage 0 interpreter (pat) if available.
                // Accepts: lower_and_compile(programObj[, outPath])
                // programObj is expected to be { type: "Program", source_path: <string> } from parse_tiny_source.
                println!("[host lower_and_compile] ENTER args_len={}", args.len());
                if args.is_empty() { println!("[host lower_and_compile] no args"); return Ok(Value::String(String::new())); }
                let src_path = match &args[0] {
                    Value::Object(map) => match map.get("source_path") { Some(Value::String(s)) => s.clone(), _ => String::new() },
                    Value::String(s) => s.clone(),
                    other => display_value(other),
                };
                let out_opt = args.get(1).map(|v| match v { Value::String(s) => s.clone(), other => display_value(other) });
                println!("[host lower_and_compile] src_path={} out_opt={}", src_path, out_opt.clone().unwrap_or_default());

                // Resolve Stage 0 runner strictly from project-local paths (no PATH fallback)
                let cwd = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
                let rel_candidates = [
                    "rust-runtime/target/debug/pat",
                    "rust-runtime/target/debug/pat.exe",
                    "./rust-runtime/target/debug/pat",
                    "./rust-runtime/target/debug/pat.exe",
                    "..\\rust-runtime\\target\\debug\\pat.exe",
                    "rust-runtime\\target\\debug\\pat.exe",
                ];
                let abs_candidates: Vec<String> = rel_candidates.iter()
                    .map(|p| cwd.join(p).display().to_string())
                    .collect();
                let pat_path = abs_candidates.iter().find(|p| std::path::Path::new(p).exists()).cloned();
                let pat_path = match pat_path {
                    Some(p) => p,
                    None => {
                        return Err(format!(
                            "lower_and_compile: could not find project pat runner. Checked:\n{}",
                            abs_candidates.join("\n")
                        ));
                    }
                };
                println!("[host lower_and_compile] using pat at {}", pat_path);
                // Use raw strings, but on Windows convert MSYS-style (/e/...) to Windows (E:\...) for child rustc.
                let script_raw: &str = "./patc_native.patlang";
                let input_raw: String = src_path.clone();
                let out_raw: Option<String> = out_opt.clone();

                #[allow(unused_variables)]
                fn msys_to_win_path(p: &str) -> String {
                    #[cfg(windows)]
                    {
                        let b = p.as_bytes();
                        if b.len() >= 3 && b[0] == b'/' && b[2] == b'/' {
                            let drive = (b[1] as char).to_ascii_uppercase();
                            let rest = &p[3..];
                            let rest_bs = rest.replace('/', "\\");
                            return format!("{}:\\{}", drive, rest_bs);
                        }
                        // Otherwise, just replace forward slashes with backslashes to be safe
                        return p.replace('/', "\\");
                    }
                    #[cfg(not(windows))]
                    {
                        p.to_string()
                    }
                }

                // Make input absolute for reliability
                let input_abs = {
                    let p = std::path::Path::new(&input_raw);
                    if p.is_absolute() { p.to_path_buf() } else { std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")).join(p) }
                };
                let input_arg = msys_to_win_path(&input_abs.display().to_string());
                // Normalize desired out path (if user provided a non-empty file path) to absolute
                let desired_out_abs: Option<String> = out_raw.as_ref().and_then(|s| {
                    let t = s.trim();
                    if t.is_empty() { return None; }
                    let p = std::path::Path::new(t);
                    let cwd_here = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
                    let abs = if p.is_absolute() { p.to_path_buf() } else { cwd_here.join(p) };
                    // If the path points to an existing directory or looks like a directory (trailing sep), ignore it
                    let looks_dir = t.ends_with('/') || t.ends_with('\\');
                    if abs.is_dir() || looks_dir { None } else { Some(abs.display().to_string()) }
                });

                // Build command: pat --emit-rust <input> (capture Rust source, we compile with rustc)
                let mut cmd = std::process::Command::new(&pat_path);
                if let Ok(cwd) = std::env::current_dir() { let _ = cmd.current_dir(&cwd); }
                cmd.arg("--emit-rust");
                if !input_arg.is_empty() { cmd.arg(&input_arg); }
                cmd.env_remove("RUST_LOG");
                cmd.env_remove("PATLANG_DEBUG");
                // Always print a concise debug line to aid bootstrap troubleshooting and write to a local log file
                let cwd_dbg = std::env::current_dir().ok().map(|p| p.display().to_string()).unwrap_or_default();
                println!(
                    "[host lower_and_compile] cwd={} using_pat={} cmd: pat --emit-rust {:?} {}",
                    cwd_dbg,
                    pat_path,
                    input_arg,
                    match &desired_out_abs { Some(p) => format!("(will compile to {:?})", p), None => String::from("") }
                );
                if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open("boot_host.log") {
                    use std::io::Write;
                    let _ = writeln!(
                        f,
                        "cwd={} pat={} cmd: pat --emit-rust {} {}",
                        cwd_dbg,
                        pat_path,
                        input_arg,
                        match &desired_out_abs { Some(p) => format!("(will compile to {})", p), None => String::from("(no dest)") }
                    );
                }
                println!("[host lower_and_compile] spawning child...");
                let out = cmd.output().map_err(|e| format!("lower_and_compile: failed to spawn pat: {}", e))?;
                println!("[host lower_and_compile] DONE status={} stdout_len={} stderr_len={}", out.status, out.stdout.len(), out.stderr.len());
                if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open("boot_host.log") {
                    use std::io::Write;
                    let _ = writeln!(f, "status={} stdout_len={} stderr_len={}", out.status, out.stdout.len(), out.stderr.len());
                }
                if !out.status.success() {
                    let stderr = String::from_utf8_lossy(&out.stderr).to_string();
                    return Err(format!("lower_and_compile: pat exited with {}\n{}", out.status, stderr));
                }
                // Locate the emitted Rust source file by parsing path from stdout or scanning for newest emitted_*.rs
                let out_stdout = String::from_utf8_lossy(&out.stdout).to_string();
                let out_stderr = String::from_utf8_lossy(&out.stderr).to_string();
                let combined = format!("{}\n{}", out_stdout, out_stderr);
                let mut rs_path: Option<String> = None;
                for line in combined.lines() {
                    let l = line.trim();
                    if let Some(rest) = l.strip_prefix("Wrote ") {
                        let p = rest.trim();
                        if p.ends_with(".rs") { rs_path = Some(p.to_string()); }
                    }
                }
                if rs_path.is_none() {
                    if let Ok(cwd) = std::env::current_dir() {
                        if let Ok(mut entries) = std::fs::read_dir(&cwd) {
                            let mut newest: Option<(std::time::SystemTime, String)> = None;
                            while let Some(Ok(e)) = entries.next() {
                                if let Some(name) = e.file_name().to_str() {
                                    if name.ends_with(".rs") && name.starts_with("emitted_") {
                                        if let Ok(md) = e.metadata() {
                                            if let Ok(t) = md.modified() {
                                                let path_str = e.path().display().to_string();
                                                newest = match newest {
                                                    Some((prev_t, _)) => if t > prev_t { Some((t, path_str)) } else { newest },
                                                    None => Some((t, path_str)),
                                                };
                                            }
                                        }
                                    }
                                }
                            }
                            if let Some((_, p)) = newest { rs_path = Some(p); }
                        }
                    }
                }
                let rs_path = rs_path.ok_or_else(|| format!("lower_and_compile: couldn't find emitted .rs file in pat output. output was:\n{}", combined))?;
                println!("[host lower_and_compile] will compile Rust source at {}", rs_path);
                let rust_src = std::fs::read_to_string(&rs_path).map_err(|e| format!("lower_and_compile: failed to read {}: {}", rs_path, e))?;
                if rust_src.trim().is_empty() { return Err("lower_and_compile: emitted .rs file was empty".into()); }
                // Choose destination path
                let dest_path: String = if let Some(d) = desired_out_abs { d } else {
                    let in_p = std::path::Path::new(&input_arg);
                    let stem = in_p.file_stem().and_then(|s| s.to_str()).unwrap_or("a");
                    let parent = in_p.parent().unwrap_or_else(|| std::path::Path::new("."));
                    let mut outp = parent.join(stem);
                    if cfg!(windows) { outp.set_extension("exe"); }
                    outp.display().to_string()
                };
                // Guard against Windows reserved device names
                #[cfg(windows)]
                {
                    use std::path::Path;
                    let base = Path::new(&dest_path).file_stem().and_then(|s| s.to_str()).unwrap_or("").to_ascii_uppercase();
                    let reserved = ["CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9"];
                    if reserved.contains(&base.as_str()) {
                        return Err(format!("lower_and_compile: '{}' is a reserved Windows filename; choose a different output name", base));
                    }
                }
                // Precreate the output file to test write permissions
                {
                    let dp = std::path::Path::new(&dest_path);
                    if let Some(par) = dp.parent() { let _ = std::fs::create_dir_all(par); }
                    match std::fs::OpenOptions::new().create(true).write(true).truncate(true).open(&dp) {
                        Ok(_) => {
                            println!("[host lower_and_compile] precreated output file at {}", dp.display());
                        }
                        Err(e) => {
                            println!("[host lower_and_compile] precreate failed at {}: {}", dp.display(), e);
                            return Err(format!("lower_and_compile: cannot create output file at {}: {}", dp.display(), e));
                        }
                    }
                    println!("[host lower_and_compile] precreate exists={}", dp.exists());
                }
                // Write rust src to temp and run rustc -o dest
                // Use file_ops helpers for temp file and output handling
                let src_path = create_temp_file("generated_main.rs").map_err(|e| {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] temp file error: {}", e));
                    format!("lower_and_compile: failed to create temp file: {}", e)
                })?;
                write_to_file(&src_path, &rust_src).map_err(|e| {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] write error: {}", e));
                    format!("lower_and_compile: failed to write rust src: {}", e)
                })?;
                let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
                let tmp_out = create_temp_file("patlang_native_out").map_err(|e| {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] temp out error: {}", e));
                    format!("lower_and_compile: failed to create temp out: {}", e)
                })?;
                let status = std::process::Command::new(&rustc)
                    .arg("-O")
                    .arg(&src_path)
                    .arg("-o")
                    .arg(&tmp_out)
                    .status()
                    .map_err(|e| {
                        log_to_file("boot_host.log", &format!("[lower_and_compile] rustc error: {}", e));
                        format!("lower_and_compile: failed to run rustc: {}", e)
                    })?;
                if !status.success() {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] rustc failed: status={}", status));
                    return Err(format!("lower_and_compile: rustc failed with status {}", status));
                }
                // Move/copy to final output
                move_or_copy(&tmp_out, &dest_path).map_err(|e| {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] move/copy error: {}", e));
                    format!("lower_and_compile: failed to move/copy output: {}", e)
                })?;
                if file_exists(&dest_path) {
                    Ok(Value::String(dest_path))
                } else {
                    log_to_file("boot_host.log", &format!("[lower_and_compile] output not found: {}", dest_path));
                    Err(format!("lower_and_compile: expected output '{}' not found after rustc", dest_path))
                }
            }
            ,
            "emit_rust_for" => {
                // Accepts: emit_rust_for(programObj)
                if args.is_empty() { return Err("emit_rust_for: expected program object".into()); }
                let src_path = match &args[0] {
                    Value::Object(map) => match map.get("source_path") { Some(Value::String(s)) => s.clone(), _ => String::new() },
                    Value::String(s) => s.clone(),
                    other => display_value(other),
                };
                // Find pat
                let cwd = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
                let rel_candidates = [
                    "rust-runtime/target/debug/pat",
                    "rust-runtime/target/debug/pat.exe",
                    "./rust-runtime/target/debug/pat",
                    "./rust-runtime/target/debug/pat.exe",
                    "..\\rust-runtime\\target\\debug\\pat.exe",
                    "rust-runtime\\target\\debug\\pat.exe",
                ];
                let abs_candidates: Vec<String> = rel_candidates.iter().map(|p| cwd.join(p).display().to_string()).collect();
                let pat_path = abs_candidates.iter().find(|p| std::path::Path::new(p).exists()).cloned()
                    .ok_or_else(|| format!("emit_rust_for: could not find pat runner. Checked:\n{}", abs_candidates.join("\n")))?;
                // Normalize input
                fn msys_to_win_path(p: &str) -> String {
                    #[cfg(windows)]
                    {
                        let b = p.as_bytes();
                        if b.len() >= 3 && b[0] == b'/' && b[2] == b'/' {
                            let drive = (b[1] as char).to_ascii_uppercase();
                            let rest = &p[3..];
                            let rest_bs = rest.replace('/', "\\");
                            return format!("{}:\\{}", drive, rest_bs);
                        }
                        return p.replace('/', "\\");
                    }
                    #[cfg(not(windows))]
                    { p.to_string() }
                }
                let input_abs = {
                    let p = std::path::Path::new(&src_path);
                    if p.is_absolute() { p.to_path_buf() } else { std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")).join(p) }
                };
                let input_arg = msys_to_win_path(&input_abs.display().to_string());
                // Run emit-rust
                let mut cmd = std::process::Command::new(&pat_path);
                if let Ok(cwd) = std::env::current_dir() { let _ = cmd.current_dir(&cwd); }
                cmd.arg("--emit-rust");
                if !input_arg.is_empty() { cmd.arg(&input_arg); }
                let out = cmd.output().map_err(|e| format!("emit_rust_for: failed to spawn pat: {}", e))?;
                if !out.status.success() {
                    return Err(format!("emit_rust_for: pat exited with {}\n{}", out.status, String::from_utf8_lossy(&out.stderr)));
                }
                let combined = format!("{}\n{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
                let mut rs_path: Option<String> = None;
                for line in combined.lines() {
                    let l = line.trim();
                    if let Some(rest) = l.strip_prefix("Wrote ") {
                        let p = rest.trim();
                        if p.ends_with(".rs") { rs_path = Some(p.to_string()); }
                    }
                }
                if rs_path.is_none() {
                    if let Ok(mut entries) = std::fs::read_dir(&cwd) {
                        let mut newest: Option<(std::time::SystemTime, String)> = None;
                        while let Some(Ok(e)) = entries.next() {
                            if let Some(name) = e.file_name().to_str() {
                                if name.ends_with(".rs") && name.starts_with("emitted_") {
                                    if let Ok(md) = e.metadata() {
                                        if let Ok(t) = md.modified() {
                                            let path_str = e.path().display().to_string();
                                            newest = match newest {
                                                Some((prev_t, _)) => if t > prev_t { Some((t, path_str)) } else { newest },
                                                None => Some((t, path_str)),
                                            };
                                        }
                                    }
                                }
                            }
                        }
                        if let Some((_, p)) = newest { rs_path = Some(p); }
                    }
                }
                match rs_path { Some(p) => Ok(Value::String(p)), None => Err("emit_rust_for: could not find emitted .rs".into()) }
            }
            ,
            "copy_file" => {
                // copy_file(from, to) -> "OK <abs>" or "ERR: msg"
                if args.len() != 2 { return Err("copy_file: expected 2 args".into()); }
                let from = to_s(&args[0]);
                let to = to_s(&args[1]);
                let from_p = std::path::Path::new(&from);
                let to_p = std::path::Path::new(&to);
                if let Some(par) = to_p.parent() { let _ = std::fs::create_dir_all(par); }
                match std::fs::copy(from_p, to_p) {
                    Ok(_) => {
                        let abs = std::fs::canonicalize(to_p).unwrap_or_else(|_| to_p.to_path_buf());
                        Ok(Value::String(format!("OK {}", abs.display())))
                    }
                    Err(e) => Ok(Value::String(format!("ERR: {}", e)))
                }
            }
            ,
            "patc_compile_from_argv" => {
                // Parse argv: [exe, [--patc|--emit-rust], input, [--out, path]]
                println!("[patc_compile] ENTER");
                let mut argsv: Vec<String> = std::env::args().collect();
                if !argsv.is_empty() { argsv.remove(0); }
                let mut mode = "patc".to_string();
                let mut input = String::new();
                let mut out_path: Option<String> = None;
                let mut i = 0usize;
                while i < argsv.len() {
                    let a = &argsv[i];
                    if a == "--emit-rust" { mode = "emit-rust".to_string(); i += 1; continue; }
                    if a == "--patc" { mode = "patc".to_string(); i += 1; continue; }
                    if a == "--out" { if i+1 < argsv.len() { out_path = Some(argsv[i+1].clone()); i += 2; continue; } else { break; } }
                    if input.is_empty() { input = a.clone(); i += 1; continue; }
                    i += 1;
                }
                println!("[patc_compile] mode={} input='{}' out={}", mode, input, out_path.clone().unwrap_or_default());
                if input.is_empty() { println!("[patc_compile] no input provided"); return Ok(Value::String("ERR: usage --patc <input.patlang> [--out path]".into())); }
                // Reuse logic from lower_and_compile
                let cwd = std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."));
                let mut abs_candidates: Vec<String> = Vec::new();
                let mut push_candidate = |base: &std::path::Path, rel: &str| {
                    abs_candidates.push(base.join(rel).display().to_string());
                };
                // Candidates relative to CWD
                push_candidate(&cwd, "target/debug/pat");
                push_candidate(&cwd, "target/debug/pat.exe");
                push_candidate(&cwd, "rust-runtime/target/debug/pat");
                push_candidate(&cwd, "rust-runtime/target/debug/pat.exe");
                push_candidate(&cwd, "./rust-runtime/target/debug/pat");
                push_candidate(&cwd, "./rust-runtime/target/debug/pat.exe");
                // Candidates relative to parent of CWD
                if let Some(parent) = cwd.parent() {
                    push_candidate(parent, "rust-runtime/target/debug/pat");
                    push_candidate(parent, "rust-runtime/target/debug/pat.exe");
                }
                let pat_path = abs_candidates.iter().find(|p| std::path::Path::new(p).exists()).cloned()
                    .unwrap_or_else(|| "pat".to_string());
                println!("[patc_compile] pat candidates:\n{}\n[patc_compile] using pat at {}", abs_candidates.join("\n"), pat_path);

                fn msys_to_win_path(p: &str) -> String {
                    #[cfg(windows)]
                    {
                        let b = p.as_bytes();
                        if b.len() >= 3 && b[0] == b'/' && b[2] == b'/' {
                            let drive = (b[1] as char).to_ascii_uppercase();
                            let rest = &p[3..];
                            let rest_bs = rest.replace('/', "\\");
                            return format!("{}:\\{}", drive, rest_bs);
                        }
                        return p.replace('/', "\\");
                    }
                    #[cfg(not(windows))]
                    { p.to_string() }
                }
                let input_abs = {
                    let p = std::path::Path::new(&input);
                    if p.is_absolute() { p.to_path_buf() } else { std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")).join(p) }
                };
                let input_arg = msys_to_win_path(&input_abs.display().to_string());
                println!("[patc_compile] input_abs={} input_arg={}", input_abs.display(), input_arg);
                // Emit rust path
                let mut cmd = std::process::Command::new(&pat_path);
                if let Ok(cwd) = std::env::current_dir() { let _ = cmd.current_dir(&cwd); }
                cmd.arg("--emit-rust");
                if !input_arg.is_empty() { cmd.arg(&input_arg); }
                let outp = cmd.output().map_err(|e| format!("patc_compile_from_argv: failed to run pat: {}", e))?;
                if !outp.status.success() { println!("[patc_compile] stage0 pat failed: {}", outp.status); return Ok(Value::String(format!("ERR: {}", String::from_utf8_lossy(&outp.stderr)))); }
                let out_stdout_s = String::from_utf8_lossy(&outp.stdout).to_string();
                let out_stderr_s = String::from_utf8_lossy(&outp.stderr).to_string();
                let combined = format!("{}\n{}", out_stdout_s, out_stderr_s);
                let mut rs_path: Option<String> = None;
                for line in combined.lines() {
                    let l = line.trim();
                    if let Some(rest) = l.strip_prefix("Wrote ") { let p = rest.trim(); if p.ends_with(".rs") { rs_path = Some(p.to_string()); } }
                }
                let mut rust_src_inline: Option<String> = None;
                if rs_path.is_none() && !out_stdout_s.trim().is_empty() {
                    rust_src_inline = Some(out_stdout_s.clone());
                }
                println!("[patc_compile] rs_path={:?} inline_len={}", rs_path, rust_src_inline.as_ref().map(|s| s.len()).unwrap_or(0));
                if mode == "emit-rust" {
                    if let Some(p) = rs_path { return Ok(Value::String(p)); }
                    if let Some(src) = rust_src_inline {
                        let mut t = std::env::temp_dir(); t.push("patlang_emit_inline"); let _ = std::fs::create_dir_all(&t);
                        let f = t.join("inline.rs");
                        if let Err(e) = std::fs::write(&f, &src) { return Ok(Value::String(format!("ERR: write inline: {}", e))); }
                        return Ok(Value::String(f.display().to_string()));
                    }
                    return Ok(Value::String("ERR: no emitted rust found".into()));
                }
                // Compile to exe
                let dest_path: String = if let Some(d) = out_path { d } else {
                    let stem = std::path::Path::new(&input_arg).file_stem().and_then(|s| s.to_str()).unwrap_or("a");
                    let parent = std::path::Path::new(&input_arg).parent().unwrap_or_else(|| std::path::Path::new("."));
                    let mut outp = parent.join(stem);
                    if cfg!(windows) { outp.set_extension("exe"); }
                    outp.display().to_string()
                };
                // Reserved device name protection on Windows
                #[cfg(windows)]
                {
                    use std::path::Path;
                    let base = Path::new(&dest_path).file_stem().and_then(|s| s.to_str()).unwrap_or("").to_ascii_uppercase();
                    let reserved = [
                        "CON","PRN","AUX","NUL",
                        "COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
                        "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9"
                    ];
                    if reserved.contains(&base.as_str()) {
                        return Ok(Value::String(format!("ERR: '{}' is a reserved Windows filename; choose a different output name", base)));
                    }
                }
                let rust_src = if let Some(src) = rust_src_inline { src } else {
                    let p = rs_path.unwrap_or_else(|| cwd.join("emitted_bootstrap.rs").display().to_string());
                    std::fs::read_to_string(&p).map_err(|e| format!("patc_compile_from_argv: read {}: {}", p, e))?
                };
                let src_path = create_temp_file("generated_main.rs").map_err(|e| {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] temp file error: {}", e));
                    format!("patc_compile_from_argv: failed to create temp file: {}", e)
                })?;
                write_to_file(&src_path, &rust_src).map_err(|e| {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] write error: {}", e));
                    format!("patc_compile_from_argv: failed to write rust src: {}", e)
                })?;
                let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
                let tmp_out = create_temp_file("patlang_native_out").map_err(|e| {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] temp out error: {}", e));
                    format!("patc_compile_from_argv: failed to create temp out: {}", e)
                })?;
                let status = std::process::Command::new(&rustc)
                    .arg("-O").arg(&src_path).arg("-o").arg(&tmp_out)
                    .status().map_err(|e| {
                        log_to_file("boot_host.log", &format!("[patc_compile_from_argv] rustc error: {}", e));
                        format!("patc_compile_from_argv: rustc: {}", e)
                    })?;
                if !status.success() {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] rustc failed: status={}", status));
                    return Ok(Value::String(format!("ERR: rustc failed ({})", status)));
                }
                move_or_copy(&tmp_out, &dest_path).map_err(|e| {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] move/copy error: {}", e));
                    format!("patc_compile_from_argv: failed to move/copy output: {}", e)
                })?;
                if file_exists(&dest_path) {
                    Ok(Value::String(dest_path))
                } else {
                    log_to_file("boot_host.log", &format!("[patc_compile_from_argv] output not found: {}", dest_path));
                    Ok(Value::String(format!("ERR: expected output '{}' not found after rustc", dest_path)))
                }
            }
            "get_argv" => {
                // Mimic `pat ./patc_native.patlang <input> [--out path]` argv shape expected by patc_native:
                // Prepend a synthetic script name so indexing matches (argv[0] is the script path).
                // Also drop the original script path (args[1]) from the rest so argv[1] is the first real argument.
                let mut rest: Vec<String> = std::env::args().collect();
                if !rest.is_empty() { rest.remove(0); } // drop exe
                let script_path = if !rest.is_empty() { Some(rest.remove(0)) } else { None }; // drop script
                let mut full = Vec::with_capacity(rest.len()+1);
                let fake0 = script_path
                    .as_ref()
                    .and_then(|s| std::path::Path::new(s).file_name().map(|f| f.to_string_lossy().to_string()))
                    .unwrap_or_else(|| "patc_native.patlang".to_string());
                full.push(format!("./{}", fake0));
                full.extend(rest);
                Ok(Value::List(full.into_iter().map(Value::String).collect()))
            }
            "rustc_build" => {
                // rustc_build(rust_source, out_path[, target_triple[, opt_level]]) -> artifact path.
                // The self-hosted compiler's back end: write source, run rustc.
                // Optional target triple (e.g. "wasm32-wasip1") cross-compiles.
                // Optional opt_level ("0".."3", "s", "z") overrides the default
                // -O (opt-level=2) used for ordinary native builds. Needed
                // because LLVM's optimizer has been observed to blow up to
                // 30GB+ RAM at opt-level 2 (and hang indefinitely at level 1,
                // still consuming CPU with no progress) on the self-hosted
                // compiler's own ~1.6MB generated interpreter source -- a
                // pathological case tied to that file's size/shape, not a
                // general problem (ordinary, much smaller generated programs
                // compile fine at the default level). opt-level=0 was
                // confirmed to compile that same file correctly in ~10s with
                // no memory blowup, so callers building unusually large
                // generated programs (self_hosting/build_patc1.patlang) pass
                // "0" explicitly rather than changing the default for everyone.
                let src = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => return Err("rustc_build: expected Rust source string".into()) };
                let out = match args.get(1) { Some(Value::String(s)) if !s.trim().is_empty() => s.clone(), _ => return Err("rustc_build: expected output path".into()) };
                let target = match args.get(2) { Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()), _ => None };
                let opt_level = match args.get(3) { Some(Value::String(s)) if !s.trim().is_empty() => Some(s.clone()), _ => None };
                let mut tmp = std::env::temp_dir();
                tmp.push("patlang_selfhost_build");
                std::fs::create_dir_all(&tmp).map_err(|e| format!("rustc_build: temp dir: {}", e))?;
                let src_path = tmp.join(format!("gen_{}.rs", std::process::id()));
                std::fs::write(&src_path, &src).map_err(|e| format!("rustc_build: write {}: {}", src_path.display(), e))?;
                if let Some(parent) = std::path::Path::new(&out).parent() { let _ = std::fs::create_dir_all(parent); }
                let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
                // wasm32-wasip1-threads needs a nightly toolchain (its threaded
                // stdlib is only prebuilt on nightly) plus atomics/shared-memory
                // codegen flags -- neither applies to any other target, including
                // the ordinary non-threaded wasm32-wasip1 build.
                let is_threaded_wasm = target.as_deref() == Some("wasm32-wasip1-threads");
                let mut cmd = std::process::Command::new(&rustc);
                if is_threaded_wasm {
                    cmd.arg("+nightly");
                }
                // Size-optimize + strip WASM builds (measured ~7x smaller, faster
                // to compile, byte-identical stdout); native keeps full -O
                // unless the caller explicitly overrides via opt_level.
                let is_wasm = target.as_deref().map(|t| t.contains("wasm")).unwrap_or(false);
                if let Some(lvl) = &opt_level {
                    cmd.arg("-C").arg(format!("opt-level={}", lvl));
                } else if is_wasm {
                    cmd.arg("-C").arg("opt-level=z");
                } else {
                    cmd.arg("-O");
                }
                cmd.arg("-C").arg("strip=symbols");
                if is_threaded_wasm {
                    cmd.arg("-C").arg("target-feature=+atomics,+bulk-memory,+mutable-globals");
                    cmd.arg("-C").arg("link-args=--shared-memory --max-memory=1073741824");
                }
                cmd.arg(&src_path).arg("-o").arg(&out);
                if let Some(t) = &target { cmd.arg("--target").arg(t); }
                let status = cmd.status().map_err(|e| format!("rustc_build: failed to run rustc: {}", e))?;
                if !status.success() { return Err(format!("rustc_build: rustc failed with status {}", status)); }
                let p = std::path::Path::new(&out);
                let abs = std::fs::canonicalize(p).unwrap_or_else(|_| p.to_path_buf());
                Ok(Value::String(abs.display().to_string()))
            }
            "run_ir" => {
                // run_ir(ir_shape): decode a freshly lowered IR shape and run
                // it on this runtime's VM (the browser-playground back end)
                fn sl(v: &Value) -> Result<&Vec<Value>, String> {
                    match v { Value::List(xs) => Ok(xs), _ => Err("run_ir: expected list node".into()) }
                }
                fn st(xs: &[Value], i: usize) -> Result<String, String> {
                    match xs.get(i) { Some(Value::String(s)) => Ok(s.clone()), _ => Err("run_ir: expected string".into()) }
                }
                fn snum(xs: &[Value], i: usize) -> Result<f64, String> {
                    match xs.get(i) {
                        Some(Value::Number(n)) => Ok(*n),
                        Some(Value::Int(n)) => Ok(*n as f64),
                        Some(Value::Float(n)) => Ok(*n),
                        Some(Value::String(s)) => s.trim().parse::<f64>().map_err(|_| "run_ir: expected number".to_string()),
                        _ => Err("run_ir: expected number".into()),
                    }
                }
                fn dinstr(v: &Value) -> Result<Instr, String> {
                    let xs = sl(v)?;
                    let tag = st(xs, 0)?;
                    Ok(match tag.as_str() {
                        "Const" => {
                            let kind = st(xs, 1)?; let text = st(xs, 2)?;
                            let val = match kind.as_str() {
                                // Same Int-by-default/Float-if-decimal-point rule as
                                // hosts.rs's decode_ir_instr "Const" arm (Stage 38).
                                "num" => {
                                    let t = text.trim();
                                    if t.contains('.') {
                                        Value::Float(t.parse::<f64>().map_err(|_| "run_ir: bad number".to_string())?)
                                    } else {
                                        Value::Int(t.parse::<i64>().map_err(|_| "run_ir: bad number".to_string())?)
                                    }
                                }
                                "str" => Value::String(text),
                                _ => Value::Bool(text == "true"),
                            };
                            Instr::Const(val)
                        }
                        "Load" => Instr::LoadLocal(st(xs, 1)?),
                        "Store" => Instr::StoreLocal(st(xs, 1)?),
                        "Bin" => {
                            let op = st(xs, 1)?;
                            let k = match op.as_str() {
                                "+" => BinOpKind::Add, "-" => BinOpKind::Sub, "*" => BinOpKind::Mul,
                                "/" => BinOpKind::Div, "%" => BinOpKind::Mod,
                                "==" => BinOpKind::Eq, "!=" => BinOpKind::Ne,
                                "<" => BinOpKind::Lt, "<=" => BinOpKind::Le,
                                ">" => BinOpKind::Gt, ">=" => BinOpKind::Ge,
                                "and" => BinOpKind::And,
                                "band" => BinOpKind::BitAnd, "bxor" => BinOpKind::BitXor, "bor" => BinOpKind::BitOr,
                                "shl" => BinOpKind::Shl, "shr" => BinOpKind::Shr,
                                _ => BinOpKind::Or,
                            };
                            Instr::BinOp(k)
                        }
                        "Un" => {
                            let op = st(xs, 1)?;
                            if op == "not" { Instr::UnOp(UnOpKind::Not) }
                            else if op == "bnot" { Instr::UnOp(UnOpKind::BitNot) }
                            else { Instr::UnOp(UnOpKind::Neg) }
                        }
                        "Jump" => Instr::Jump(snum(xs, 1)? as usize),
                        "JumpIfFalse" => Instr::JumpIfFalse(snum(xs, 1)? as usize),
                        "CallHost" => Instr::CallHost(st(xs, 1)?, snum(xs, 2)? as usize),
                        "Call" => Instr::Call(st(xs, 1)?, snum(xs, 2)? as usize),
                        "MakeClosure" => {
                            let func_name = st(xs, 1)?;
                            let names_list = sl(xs.get(2).ok_or("run_ir: MakeClosure missing captured names")?)?;
                            let mut captured_names = Vec::with_capacity(names_list.len());
                            for nv in names_list {
                                captured_names.push(match nv { Value::String(s) => s.clone(), _ => return Err("run_ir: captured name must be a string".into()) });
                            }
                            Instr::MakeClosure(func_name, captured_names)
                        }
                        "CallValue" => Instr::CallValue(snum(xs, 1)? as usize),
                        "BuildList" => Instr::BuildList(snum(xs, 1)? as usize),
                        _ => Instr::Return,
                    })
                }
                let shape = args.get(0).ok_or("run_ir: expected IR shape")?;
                let xs = sl(shape)?;
                if st(xs, 0)? != "ProgramIR" { return Err("run_ir: root must be ProgramIR".into()); }
                let entry = st(xs, 1)?;
                let mut program = Program { functions: HashMap::new(), entry: entry.clone() };
                for fv in sl(xs.get(2).ok_or("run_ir: missing functions")?)? {
                    let fx = sl(fv)?;
                    let name = st(fx, 1)?;
                    let params: Vec<String> = sl(fx.get(2).ok_or("run_ir: missing params")?)?
                        .iter().map(|p| match p { Value::String(s) => Ok(s.clone()), _ => Err("run_ir: bad param".to_string()) })
                        .collect::<Result<_, _>>()?;
                    let mut body = Vec::new();
                    for iv in sl(fx.get(3).ok_or("run_ir: missing body")?)? { body.push(dinstr(iv)?); }
                    program.functions.insert(name.clone(), Function { name, params, body });
                }
                for ev in sl(xs.get(3).ok_or("run_ir: missing events")?)? {
                    let ex = sl(ev)?;
                    let event = st(ex, 1)?; let handler = st(ex, 2)?;
                    event_handlers_register(event, handler);
                }
                let f = program.functions.get(&program.entry).ok_or("run_ir: entry not found")?;
                run_function(&program, f, &[])
            }
                    _ => Err(format!("host fn '{}' not found", name)),
    }
}

fn host_call_codegen_bootstrap(name: &str, args: &[Value]) -> Option<Result<Value, String>> {
    match name {
        "parse_tiny_source" | "lower_and_compile" | "emit_rust_for" | "copy_file" | "patc_compile_from_argv" | "get_argv" | "rustc_build" | "run_ir" => Some(host_call_codegen_bootstrap_inner(name, args)),
        _ => None,
    }
}

"##;

    pub fn prelude() -> String {
        Self::prelude_for(&Self::all_chunks())
    }

    pub fn all_chunks() -> std::collections::BTreeSet<ChunkId> {
        ChunkId::CANONICAL_ORDER.iter().copied().collect()
    }

    /// One pass over every function's IR collecting distinct `Instr::CallHost`
    /// names, mapped to chunks via `HOST_CHUNK_TABLE`, plus `core` always,
    /// plus the transitive closure over `CROSS_CHUNK_EDGES` (empty today --
    /// see the comment on that table for why).
    pub fn required_chunks(program: &Program) -> std::collections::BTreeSet<ChunkId> {
        let mut set = std::collections::BTreeSet::new();
        set.insert(ChunkId::Core);
        for f in program.functions.values() {
            for instr in &f.body {
                if let Instr::CallHost(name, _) = instr {
                    if let Some((_, c)) = HOST_CHUNK_TABLE.iter().find(|(n, _)| *n == name.as_str()) {
                        set.insert(*c);
                    }
                    // `run_ir` interprets an IR tree built at RUNTIME from
                    // not-yet-known user source (the browser playground) --
                    // static analysis of the *host* program's own IR can
                    // never see what the eventually-submitted user code will
                    // call, so force-include the numeric tower and math
                    // primitives unconditionally whenever `run_ir` appears
                    // anywhere, regardless of what this program's own static
                    // CallHost/BinOp scan would otherwise conclude.
                    if name.as_str() == "run_ir" {
                        // A live playground must support arbitrary PatLang --
                        // not just numeric/math -- so force-include every
                        // optional chunk (oo/logic/contracts/networking/etc
                        // have the exact same "can't statically see the
                        // user's future code" gap as numeric_tower/math did).
                        for c in ChunkId::CANONICAL_ORDER {
                            set.insert(*c);
                        }
                    }
                }
                // Stage 38: `numeric_tower` is a special case, not driven by
                // `HOST_CHUNK_TABLE` -- any numeric BinOp (arithmetic, not
                // comparison/logic) or unary negation could in principle
                // overflow into bignum or hit inexact int division, and
                // there's no cheap static proof either way from bare IR, so
                // inclusion is deliberately coarse/conservative (a documented
                // limitation, not a bug) rather than trying to prove a
                // specific op site can't overflow.
                match instr {
                    Instr::BinOp(BinOpKind::Add) | Instr::BinOp(BinOpKind::Sub) | Instr::BinOp(BinOpKind::Mul)
                    | Instr::BinOp(BinOpKind::Div) | Instr::BinOp(BinOpKind::Mod)
                    | Instr::UnOp(UnOpKind::Neg) => {
                        set.insert(ChunkId::NumericTower);
                    }
                    Instr::Const(Value::BigInt(_)) | Instr::Const(Value::Rational(_, _)) | Instr::Const(Value::Complex(_, _)) => {
                        set.insert(ChunkId::NumericTower);
                    }
                    _ => {}
                }
            }
        }
        loop {
            let mut changed = false;
            for (from, to) in CROSS_CHUNK_EDGES {
                if set.contains(from) && !set.contains(to) {
                    set.insert(*to);
                    changed = true;
                }
            }
            if !changed { break; }
        }
        set
    }

    /// Concatenate the selected chunks (in `ChunkId::CANONICAL_ORDER`) plus a
    /// dynamically-assembled `call_dispatch` free function routing unhandled
    /// `core` host names to whichever optional chunks were included. This is
    /// the only part of the emitted text that isn't a static `&'static str`
    /// chunk constant, since which chunks are present varies per program.
    pub fn prelude_for(chunks: &std::collections::BTreeSet<ChunkId>) -> String {
        let mut out = String::new();
        for c in ChunkId::CANONICAL_ORDER {
            if *c == ChunkId::NumericTower {
                // Mutually exclusive value-module selection (see the doc
                // comment above `PRELUDE_VALUE_FAST`): exactly one of the two
                // is always emitted here, never both, never neither.
                if chunks.contains(c) {
                    out.push_str(RustCodegen::PRELUDE_NUMERIC_TOWER);
                } else {
                    out.push_str(RustCodegen::PRELUDE_VALUE_FAST);
                }
                continue;
            }
            if chunks.contains(c) {
                out.push_str(c.text());
            }
        }
        out.push_str(&Self::build_dispatch(chunks));
        out
    }

    /// Raw text for a single named chunk (used by the per-chunk parity test),
    /// or the dispatch glue alone via the sentinel name `"__dispatch_all__"`.
    pub fn chunk_text_by_name(name: &str) -> Option<String> {
        if name == "__dispatch_all__" {
            return Some(Self::build_dispatch(&Self::all_chunks()));
        }
        if name == "__value_fast__" {
            return Some(RustCodegen::PRELUDE_VALUE_FAST.to_string());
        }
        ChunkId::from_name(name).map(|c| c.text().to_string())
    }

    fn build_dispatch(chunks: &std::collections::BTreeSet<ChunkId>) -> String {
        let mut s = String::new();
        s.push_str("fn call_dispatch(name: &str, args: &[Value]) -> Result<Value, String> {\n");
        for c in ChunkId::CANONICAL_ORDER {
            if *c == ChunkId::Core || *c == ChunkId::NumericTower { continue; }
            if chunks.contains(c) {
                s.push_str(&format!("    if let Some(r) = host_call_{}(name, args) {{ return r; }}\n", c.name()));
            }
        }
        s.push_str("    Err(format!(\"host fn '{}' not found\", name))\n}\n\n");
        s
    }


    // Emit a standalone Rust program that embeds the IR as a multi-function Program
    pub fn emit_rust(&self, program: &Program) -> String {
        let mut out = String::new();
        out.push_str(&Self::prelude_for(&Self::required_chunks(program)));

        // program builder: emit all functions with params and bodies
        out.push_str("fn build_program() -> Program {\n    let mut functions: HashMap<String, Function> = HashMap::new();\n");
        out.push_str("    // Seed event handlers registry from embedded Program\n");
        for (ev, hs) in program.event_handlers.iter() {
            for h in hs {
                out.push_str(&format!("    event_handlers_register(\"{}\".to_string(), \"{}\".to_string());\n", rust_str(ev), rust_str(h)));
            }
        }
        // Emit each function body and insert into map
        for (name, func) in program.functions.iter() {
            out.push_str(&format!("    // function {}\n", name));
            out.push_str("    let mut body: Vec<Instr> = Vec::new();\n");
            for instr in &func.body {
                out.push_str("    body.push(");
                self.emit_instr(instr, &mut out);
                out.push_str(");\n");
            }
            // emit params vec
            out.push_str("    let params: Vec<String> = vec![");
            for (i, p) in func.params.iter().enumerate() {
                if i>0 { out.push_str(", "); }
                out.push_str(&format!("\"{}\".to_string()", rust_str(p)));
            }
            out.push_str("];\n");
            out.push_str(&format!(
                "    functions.insert(\"{}\".to_string(), Function {{ name: \"{}\".to_string(), params, body }});\n",
                rust_str(name), rust_str(name)
            ));
        }
    out.push_str(&format!("    Program {{ functions, entry: \"{}\".to_string() }}\n}}\n", rust_str(&program.entry)));

        out
    }

    fn emit_instr(&self, instr: &Instr, out: &mut String) {
        match instr {
            Instr::Const(v) => {
                out.push_str("Instr::Const(");
                self.emit_value(v, out);
                out.push(')');
            }
            Instr::LoadLocal(n) => {
                out.push_str(&format!("Instr::LoadLocal(\"{}\".to_string())", rust_str(n)));
            }
            Instr::StoreLocal(n) => {
                out.push_str(&format!("Instr::StoreLocal(\"{}\".to_string())", rust_str(n)));
            }
            Instr::BinOp(k) => {
                out.push_str("Instr::BinOp(");
                self.emit_binop(k, out);
                out.push(')');
            }
            Instr::UnOp(k) => {
                out.push_str("Instr::UnOp(");
                match k { UnOpKind::Neg => out.push_str("UnOpKind::Neg"), UnOpKind::Not => out.push_str("UnOpKind::Not"), UnOpKind::BitNot => out.push_str("UnOpKind::BitNot") }
                out.push(')');
            }
            Instr::Jump(t) => out.push_str(&format!("Instr::Jump({})", t)),
            Instr::JumpIfFalse(t) => out.push_str(&format!("Instr::JumpIfFalse({})", t)),
            Instr::CallHost(n, argc) => {
                out.push_str(&format!("Instr::CallHost(\"{}\".to_string(), {})", rust_str(n), argc));
            }
            Instr::Call(n, argc) => {
                out.push_str(&format!("Instr::Call(\"{}\".to_string(), {})", rust_str(n), argc));
            }
            Instr::MakeClosure(name, captured) => {
                let names = captured.iter().map(|c| format!("\"{}\".to_string()", rust_str(c))).collect::<Vec<_>>().join(", ");
                out.push_str(&format!("Instr::MakeClosure(\"{}\".to_string(), vec![{}])", rust_str(name), names));
            }
            Instr::CallValue(argc) => out.push_str(&format!("Instr::CallValue({})", argc)),
            Instr::BuildList(n) => out.push_str(&format!("Instr::BuildList({})", n)),
            Instr::Return => out.push_str("Instr::Return"),
        }
    }

    fn emit_binop(&self, k: &BinOpKind, out: &mut String) {
        use BinOpKind::*;
        let s = match k { Add=>"Add", Sub=>"Sub", Mul=>"Mul", Div=>"Div", Mod=>"Mod", Eq=>"Eq", Ne=>"Ne", Lt=>"Lt", Le=>"Le", Gt=>"Gt", Ge=>"Ge", And=>"And", Or=>"Or", BitAnd=>"BitAnd", BitOr=>"BitOr", BitXor=>"BitXor", Shl=>"Shl", Shr=>"Shr" };
        out.push_str(&format!("BinOpKind::{}", s));
    }

    /// Emits a `NumT::...` constructor for `ComplexT`'s re/im components
    /// (which cannot themselves be `Complex` -- the interpreter's own
    /// `Value::Complex(Box<Value>, Box<Value>)` never nests, per
    /// `ir/numeric.rs`'s promotion rules).
    fn emit_numt(&self, v: &Value, out: &mut String) {
        match v {
            Value::Int(n) => out.push_str(&format!("NumT::Int({})", n)),
            Value::Float(n) => out.push_str(&format!("NumT::Float({})", n)),
            Value::BigInt(b) => out.push_str(&format!("NumT::Big(BigIntT::from_decimal_str(\"{}\").unwrap())", b)),
            Value::Rational(n, d) => out.push_str(&format!(
                "NumT::Rat(RationalT::new(BigIntT::from_decimal_str(\"{}\").unwrap(), BigIntT::from_decimal_str(\"{}\").unwrap()))",
                n, d
            )),
            other => out.push_str(&format!("NumT::Int({})", other.as_number().map(|f| f as i64).unwrap_or(0))),
        }
    }

    fn emit_value(&self, v: &Value, out: &mut String) {
        match v {
            Value::Unit => out.push_str("Value::Unit"),
            Value::Bool(b) => out.push_str(&format!("Value::Bool({})", b)),
            // Stage 38: whole-number literal source syntax (no decimal point)
            // stays on the fast `Value::Int` path; `.`-containing literals
            // become `Value::Float` -- mirrors the interpreter's own
            // Int-by-default/Float-if-decimal-point rule (Stage 36,
            // `ir/lowering.rs`'s `Expr::Number`/`Expr::Float` split). Whichever
            // value-module `prelude_for` selects (`PRELUDE_VALUE_FAST` or
            // `PRELUDE_NUMERIC_TOWER`) defines both variants identically, so
            // this text is valid either way.
            Value::Int(n) => out.push_str(&format!("Value::Int({})", n)),
            Value::Float(n) => {
                if n.fract() == 0.0 && n.is_finite() {
                    out.push_str(&format!("Value::Float({}.0)", *n as i64));
                } else {
                    out.push_str(&format!("Value::Float({})", n));
                }
            }
            // BigInt/Rational/Complex compile-time constants are rare (they'd
            // only arise from a meta-compilation path folding a tower value
            // into a `Const` at IR-build time, not from ordinary source
            // literals), but are supported: emitted via the numeric_tower
            // chunk's own constructors. Only valid when that chunk is
            // selected -- `required_chunks` below also scans `Instr::Const`
            // for these kinds so the chunk is never silently dropped.
            Value::BigInt(b) => out.push_str(&format!("Value::BigInt(BigIntT::from_decimal_str(\"{}\").unwrap())", b)),
            Value::Rational(n, d) => out.push_str(&format!(
                "Value::Rational(RationalT::new(BigIntT::from_decimal_str(\"{}\").unwrap(), BigIntT::from_decimal_str(\"{}\").unwrap()))",
                n, d
            )),
            Value::Complex(re, im) => {
                out.push_str("Value::Complex(ComplexT::new(");
                self.emit_numt(re, out);
                out.push_str(", ");
                self.emit_numt(im, out);
                out.push_str("))");
            }
            Value::String(s) => out.push_str(&format!("Value::String(\"{}\".to_string())", rust_str(s))),
            Value::List(items) => {
                out.push_str("Value::List(vec![");
                for (i, it) in items.iter().enumerate() { if i>0 { out.push_str(", "); } self.emit_value(it, out); }
                out.push_str("])");
            }
            Value::Object(map) => {
                if map.is_empty() {
                    out.push_str("Value::Object(HashMap::new())");
                } else {
                    out.push_str("{ let mut m: HashMap<String, Value> = HashMap::new(); ");
                    for (k, v) in map.iter() {
                        out.push_str(&format!("m.insert(\"{}\".to_string(), ", rust_str(k)));
                        self.emit_value(v, out);
                        out.push_str("); ");
                    }
                    out.push_str("Value::Object(m) }");
                }
            }
            Value::HostFunction(_) => { out.push_str("Value::Unit"); }
            Value::Closure { .. } => {
                // Closures are always created at runtime via MakeClosure, never
                // as a Const literal; a lowerer that emits one is a bug.
                panic!("emit_value: closures cannot appear as compile-time constants");
            }
        }
    }
}

fn rust_str(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
        .replace('\t', "\\t")
        .replace('\r', "\\r")
}
