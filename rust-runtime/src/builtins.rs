//! Built-in functions registry and handlers.
//!
//! This module centralizes handling for core built-ins so the evaluator stays generic.

use crate::error_handler::RuntimeError;
use crate::logic_engine::{Fact, Query, Term};
use crate::runtime_integration::on_query_results;

// We reuse the evaluator's ExecutionContext type to avoid large refactors right now.
use crate::core_evaluator::ExecutionContext;
use std::path::{Path, PathBuf};

// IR pipeline pieces used by patc built-ins
use crate::parser::Parser as Stage0Parser;
use crate::ir::{Lowerer, RustCodegen};
use crate::ast::{Expr, Stmt};

/// Handle a built-in function call by name.
/// - `name`: function name like "new", "fact", "query", "goal", etc.
/// - `eval_args`: arguments already evaluated to strings.
/// Returns Some(result_string) if handled, or None if not a built-in.
pub fn handle_function(
    ctx: &mut ExecutionContext,
    name: &str,
    eval_args: &[String],
) -> Option<Result<String, RuntimeError>> {
    match name {
        // Map helpers for interchange (tokens/AST as maps)
        "map_new" => {
            let id = format!("__map_{}", ctx.counters.entry("map".into()).and_modify(|c| *c += 1).or_insert(1usize));
            let _ = ctx.object_store.ensure(&id, "Map");
            Some(Ok(id))
        }
        "map_set" => {
            if eval_args.len() != 3 { return Some(Ok(String::new())); }
            let id = &eval_args[0];
            let key = &eval_args[1];
            let val = &eval_args[2];
            ctx.object_store.set(id, key, val.clone());
            Some(Ok(id.clone()))
        }
        // Lower a minimal AST-shape (maps/lists) and compile to an exe; returns canonical path
        // Schema supported (subset):
        // Program { type:"Program", stmts: <list_id> }
        // Print stmt: { type:"Print", expr: <expr_id> }
        // String expr: { type:"String", value: <string> }
        "lower_and_compile" => {
            if eval_args.is_empty() { return Some(Ok(String::new())); }
            let prog_id = &eval_args[0];
            let out_opt = eval_args.get(1).cloned();
            Some(lower_and_compile_impl(ctx, prog_id, out_opt))
        }
        // Minimal native patc: compile a .patlang file to a native executable using the Stage 0 backend.
        // Usage: patc_compile(input_path[, out_path]) -> canonical exe path (string) or empty on error
        "patc_compile" => {
            let in_path = eval_args.get(0).cloned().unwrap_or_default();
            let out_opt = eval_args.get(1).cloned();
            Some(patc_compile_impl(&in_path, out_opt))
        }
        // Variant that reads args from the current process argv:
        // patc_compile_from_argv() -> canonical exe path
        "patc_compile_from_argv" => {
            let mut args: Vec<String> = std::env::args().collect();
            // Expect: bin [--patc] <input> [--out <path>]
            // Find first non-flag as input, unless it's --patc then skip to next
            let mut input: Option<String> = None;
            let mut out: Option<String> = None;
            let mut i = 1usize;
            while i < args.len() {
                let s = &args[i];
                if s == "--out" {
                    if i+1 < args.len() { out = Some(args[i+1].clone()); i += 2; continue; } else { break; }
                }
                if s == "--patc" || s == "--emit-rust" || s == "--build-run" || s == "--ir-run" || s == "--compare" {
                    i += 1; continue;
                }
                if !s.starts_with('-') && input.is_none() { input = Some(s.clone()); i += 1; continue; }
                i += 1;
            }
            let inp = input.unwrap_or_default();
            Some(patc_compile_impl(&inp, out))
        }
        // Access argv as a list id (excluding program name)
        "get_argv" => {
            let mut argv: Vec<String> = std::env::args().collect();
            if !argv.is_empty() { argv.remove(0); }
            let id = format!("__list_{}", ctx.lists.len()+1);
            ctx.lists.insert(id.clone(), argv);
            Some(Ok(id))
        }
        // List helpers for simple CLI parsing in patlang
        "list_len" => {
            let lid = eval_args.get(0).cloned().unwrap_or_default();
            let n = ctx.lists.get(&lid).map(|v| v.len()).unwrap_or(0);
            Some(Ok(n.to_string()))
        }
        "list_get" => {
            if eval_args.len() != 2 { return Some(Ok(String::new())); }
            let lid = &eval_args[0];
            let idx = eval_args[1].parse::<usize>().unwrap_or(0);
            let s = ctx.lists.get(lid).and_then(|v| v.get(idx).cloned()).unwrap_or_default();
            Some(Ok(s))
        }
        // Read a file as string
        "read_file" => {
            let path = eval_args.get(0).cloned().unwrap_or_default();
            match std::fs::read_to_string(&path) {
                Ok(s) => Some(Ok(s)),
                Err(e) => Some(Err(RuntimeError::new(
                    crate::error_handler::RuntimeErrorKind::CoreEvaluator,
                    format!("read_file: {}", e),
                ))),
            }
        }
        // Parse a tiny subset of patlang and return a Program map id
        // Supports lines:
        //   let name = 123
        //   let name = "string"
        //   let name = other
        //   print("string")
        //   print(name)
        "parse_tiny_source" => {
            let path = eval_args.get(0).cloned().unwrap_or_default();
            Some(parse_tiny_source_impl(ctx, &path))
        }
        "build_dependency_graph" => {
            // args[0] is a list id of targets; create a graph object and attach nodes property
            let list_id = eval_args.get(0).cloned().unwrap_or_default();
            let idx = ctx.counters.entry("graph".into()).and_modify(|c| *c += 1).or_insert(1usize);
            let id = format!("DependencyGraph_{}", *idx);
            let _ = ctx.object_store.ensure(&id, "DependencyGraph");
            if !list_id.is_empty() {
                ctx.object_store.set(&id, "nodes", list_id);
            }
            // simple placeholder for edges; can be populated by later passes
            ctx.object_store.set(&id, "edges", "[]");
            Some(Ok(id))
        }
        // Create an empty list and return its id
    "list_new" => {
            let id = format!("__list_{}", ctx.lists.len()+1);
            ctx.lists.insert(id.clone(), Vec::new());
            Some(Ok(id))
        }
        "set_var" => {
            if eval_args.len() != 2 { return Some(Ok(String::new())); }
            let key = &eval_args[0];
            let val = &eval_args[1];
            ctx.set_var(key, val.clone());
            Some(Ok(val.clone()))
        }
        "infer_type_for" => {
            if eval_args.len() != 3 { return Some(Ok(String::new())); }
            let pred = &eval_args[0];
            let idx = eval_args[1].parse::<usize>().unwrap_or(0);
            let class = &eval_args[2];
            ctx.type_infer.register(pred, idx, class);
            Some(Ok(String::new()))
        }
        "new" => {
            if eval_args.len() != 2 { return Some(Ok(String::new())); }
            let class = &eval_args[0];
            let name = &eval_args[1];
            let _ = ctx.object_store.ensure(name, class);
            Some(Ok(name.clone()))
        }
        "contract" => {
            if eval_args.is_empty() { return Some(Ok(String::new())); }
            let key = eval_args[0].clone();
            let types = eval_args[1..].to_vec();
            ctx.contracts.insert(key, types);
            Some(Ok(String::new()))
        }
        // Legacy convenience
        "person" => {
            if eval_args.len() != 1 { return Some(Ok(String::new())); }
            let name = &eval_args[0];
            let _ = ctx.object_store.ensure(name, "Person");
            Some(Ok(name.clone()))
        }
        "goal" => {
            if eval_args.is_empty() { return Some(Ok(String::new())); }
            let pred = eval_args[0].clone();
            let items = eval_args[1..].to_vec();
            ctx.goals.push((pred, items));
            Some(Ok(String::new()))
        }
        "fact" => {
            if eval_args.len() != 3 { return Some(Ok(String::new())); }
            let pred = eval_args[0].clone();
            let a = Term::Atom(eval_args[1].clone());
            let b = Term::Atom(eval_args[2].clone());
            ctx.logic_engine.add_fact(Fact { pred, args: vec![a, b] });
            Some(Ok(String::new()))
        }
        "query" => {
            if eval_args.len() != 3 { return Some(Ok(String::new())); }
            let pred = eval_args[0].clone();
            let subj_name = eval_args[1].clone();
            let var_name = eval_args[2].clone();
            let q = Query { pred: pred.clone(), args: vec![Term::Atom(subj_name.clone()), Term::Var(var_name.clone())] };
            let results = ctx.logic_engine.query(&q);
            // Simplify substitutions to (var, value) vector
            let mut simplified: Vec<(String, String)> = Vec::new();
            for subst in results.iter() {
                if let Some(term) = subst.0.get(&var_name) {
                    let value = match term {
                        Term::Atom(s) => s.clone(),
                        Term::Var(s) => s.clone(),
                    };
                    simplified.push((var_name.clone(), value));
                }
            }
            // Apply inference rules
            on_query_results(&mut ctx.object_store, &ctx.type_infer, &pred, &subj_name, &simplified);
            ctx.query_results.push(simplified);
            Some(Ok(format!("{}", results.len())))
        }
        _ => None,
    }
}

/// Handle an object-style method call: "obj.method(args...)".
/// Returns Some(result) if handled; None if unknown.
pub fn handle_method(
    ctx: &mut ExecutionContext,
    obj_id: &str,
    method: &str,
    eval_args: &[String],
) -> Option<Result<String, RuntimeError>> {
    // Resolve class for class-aware dispatch; fallback to global methods
    let class = ctx.object_store.get(obj_id, "type").unwrap_or_else(|| "Object".to_string());
    if let Some(f) = registry().lookup(&class, method) {
        return Some(f(ctx, obj_id, eval_args));
    }
    // Try interpreting obj_id as a class name (class methods)
    if let Some(f) = registry().lookup(obj_id, method) {
        return Some(f(ctx, obj_id, eval_args));
    }
    None
}

// --- Method registry ---

use std::collections::HashMap;
use std::sync::OnceLock;

type MethodFn = fn(&mut ExecutionContext, &str, &[String]) -> Result<String, RuntimeError>;

struct MethodRegistry {
    // (class, method) -> handler; "*" for any-class handlers
    by_class: HashMap<(String, String), MethodFn>,
    any_class: HashMap<String, MethodFn>,
}

impl MethodRegistry {
    fn new() -> Self { Self { by_class: HashMap::new(), any_class: HashMap::new() } }
    fn register(&mut self, class: &str, method: &str, f: MethodFn) {
        if class == "*" { self.any_class.insert(method.to_string(), f); }
        else { self.by_class.insert((class.to_string(), method.to_string()), f); }
    }
    fn lookup(&self, class: &str, method: &str) -> Option<MethodFn> {
        self.by_class.get(&(class.to_string(), method.to_string())).copied()
            .or_else(|| self.any_class.get(method).copied())
    }
}

static METHOD_REGISTRY: OnceLock<MethodRegistry> = OnceLock::new();

fn register_defaults() -> MethodRegistry {
    let mut reg = MethodRegistry::new();
    // set(class-agnostic)
    reg.register("*", "set", |ctx, obj_id, args| {
        if args.len() != 2 { return Ok(String::new()); }
        let prop = &args[0];
        let value = &args[1];
        ctx.object_store.set(obj_id, prop, value.clone());
        Ok(String::new())
    });
    // add method for list-like properties: obj.prop.add(value)
    reg.register("*", "add", |ctx, obj_id, args| {
        if args.len() != 1 { return Ok(String::new()); }
        let value = &args[0];
        // If obj_id is a list id, push into list
        if let Some(vec) = ctx.lists.get_mut(obj_id) {
            vec.push(value.clone());
            return Ok(String::new());
        }
        // Else treat as object: append to comma-separated property
        let current = ctx.object_store.get(obj_id, "value").unwrap_or_default();
        let newv = if current.is_empty() { value.clone() } else { format!("{},{}", current, value) };
        ctx.object_store.set(obj_id, "value", newv);
        Ok(String::new())
    });
    // concat for lists: list.concat(other_list)
    reg.register("*", "concat", |ctx, obj_id, args| {
        if args.len() != 1 { return Ok(String::new()); }
        let other = &args[0];
        let right = ctx.lists.get(other).cloned();
        if let Some(vec) = ctx.lists.get_mut(obj_id) {
            if let Some(other_vec) = right { vec.extend(other_vec); }
        }
        Ok(String::new())
    });
    // Functional list methods (map/filter/reduce/unique_by/any?) are handled by the evaluator to allow closure execution with proper lexical scoping.
    // list.parallel_collect(): iterate and materialize into a new list (identity mapping)
    reg.register("*", "parallel_collect", |ctx, obj_id, _args| {
        if let Some(items) = ctx.lists.get(obj_id).cloned() {
            let id = format!("__list_{}", ctx.lists.len()+1);
            ctx.lists.insert(id.clone(), items);
            return Ok(id);
        }
        Ok(obj_id.to_string())
    });
    // get(class-agnostic)
    reg.register("*", "get", |ctx, obj_id, args| {
        if args.len() != 1 { return Ok(String::new()); }
        let prop = &args[0];
        let value = ctx.object_store.get(obj_id, prop).unwrap_or_default();
        Ok(value)
    });
    // each for lists: list.each(closure_id) where closure_id is stored in vars/closures
    reg.register("*", "each", |ctx, obj_id, args| {
        if args.len() != 1 { return Ok(String::new()); }
        let closure_id = &args[0];
        let mut last = String::new();
        if let Some(items) = ctx.lists.get(obj_id).cloned() {
            if let Some((_params, body)) = ctx.closures.get(closure_id).cloned() {
                for item in items { last = item; }
            }
        }
        Ok(last)
    });
    // infer_relations (example: integrates with logic_engine)
    reg.register("*", "infer_relations", |ctx, obj_id, _args| {
        let pred = "parent".to_string();
        let q = crate::logic_engine::Query {
            pred,
            args: vec![
                crate::logic_engine::Term::Var("_".to_string()),
                crate::logic_engine::Term::Atom(obj_id.to_string()),
            ],
        };
        let results = ctx.logic_engine.query(&q);
        if !results.is_empty() {
            ctx.object_store.set(obj_id, "has_parent", "true");
            Ok("true".to_string())
        } else {
            Ok("false".to_string())
        }
    });
    // infer_is_adult (example: property-derived inference)
    reg.register("*", "infer_is_adult", |ctx, obj_id, _args| {
        let age_opt = ctx.object_store.get(obj_id, "age");
        if let Some(age) = age_opt {
            if age.parse::<f64>().unwrap_or(0.0) >= 18.0 {
                ctx.object_store.set(obj_id, "is_adult", "true");
                return Ok("true".to_string());
            }
        }
        Ok("false".to_string())
    });

    // WebServer.start_server(config) — start a minimal HTTP server on self.port
    reg.register("WebServer", "start_server", |_ctx, obj_id, _args| {
        // For simplicity, spin a tokio runtime and hyper server in a thread; non-blocking.
        // Port is stored on object under key "port".
        let port_str = _ctx.object_store.get(obj_id, "port").unwrap_or_else(|| "8080".to_string());
        let port: u16 = port_str.parse().unwrap_or(8080);
    // Mark keepalive so main can keep process alive
    _ctx.object_store.set("__runtime", "keepalive", "true");
    std::thread::spawn(move || {
            let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
            rt.block_on(async move {
                use hyper::{Body, Request, Response, Server};
                use hyper::service::{make_service_fn, service_fn};
                async fn handle(_req: Request<Body>) -> Result<Response<Body>, hyper::Error> {
                    Ok(Response::new(Body::from("Hello from patlang WebServer")))
                }
                let addr = ([127, 0, 0, 1], port).into();
                let make_svc = make_service_fn(|_conn| async { Ok::<_, hyper::Error>(service_fn(handle)) });
                let server = Server::bind(&addr).serve(make_svc);
                if let Err(e) = server.await { eprintln!("server error: {}", e); }
            });
        });
    Ok(String::new())
    });

    // BuildConfiguration.load_from_file(path): parse minimal YAML with target names
    reg.register("BuildConfiguration", "load_from_file", |ctx, _obj_id, args| {
        let path = args.get(0).cloned().unwrap_or_else(|| "build_config.yaml".into());
        let idx = ctx.counters.entry("config".into()).and_modify(|c| *c += 1).or_insert(1usize);
        let id = format!("BuildConfiguration_{}", *idx);
        let _ = ctx.object_store.ensure(&id, "BuildConfiguration");
        // Try to read file if accessible; otherwise set defaults
        match std::fs::read_to_string(&path) {
            Ok(content) => {
                // Expect YAML with a top-level list: targets: [name: ...]
                let mut names: Vec<String> = Vec::new();
                if let Ok(doc) = serde_yaml::from_str::<serde_yaml::Value>(&content) {
                    if let Some(ts) = doc.get("targets") {
                        if let Some(arr) = ts.as_sequence() {
                            for t in arr {
                                if let Some(name) = t.get("name").and_then(|v| v.as_str()) {
                                    names.push(name.to_string());
                                }
                            }
                        }
                    }
                }
                if names.is_empty() { names = vec!["default".into()]; }
                let list_id = format!("__list_{}", ctx.lists.len()+1);
                ctx.lists.insert(list_id.clone(), names);
                ctx.object_store.set(&id, "targets", list_id.clone());
                ctx.object_store.set(&id, "config_path", path);
            }
            Err(_) => {
                let list_id = format!("__list_{}", ctx.lists.len()+1);
                ctx.lists.insert(list_id.clone(), vec!["default".into()]);
                ctx.object_store.set(&id, "targets", list_id.clone());
                ctx.object_store.set(&id, "config_path", path);
            }
        }
        Ok(id)
    });
    // BuildConfiguration.targets(): return the stored list id
    reg.register("BuildConfiguration", "targets", |ctx, obj_id, _args| {
        if let Some(id) = ctx.object_store.get(obj_id, "targets") { return Ok(id); }
        let id = format!("__list_{}", ctx.lists.len()+1);
        ctx.lists.insert(id.clone(), vec![]);
        ctx.object_store.set(obj_id, "targets", id.clone());
        Ok(id)
    });
    // BuildConfiguration.cache_configuration(): return config path as a simple handle
    reg.register("BuildConfiguration", "cache_configuration", |ctx, obj_id, _args| {
        let cc = ctx.object_store.get(obj_id, "config_path").unwrap_or_else(|| "build_config.yaml".into());
        ctx.object_store.set(obj_id, "cache_configuration", cc.clone());
        Ok(cc)
    });
    // BuildOrchestrator.build_targets: create or return a list id stored on object
    reg.register("BuildOrchestrator", "build_targets", |ctx, obj_id, _args| {
        if let Some(id) = ctx.object_store.get(obj_id, "build_targets") { return Ok(id); }
        let id = format!("__list_{}", ctx.lists.len()+1);
        ctx.lists.insert(id.clone(), Vec::new());
        ctx.object_store.set(obj_id, "build_targets", id.clone());
        Ok(id)
    });
    // CacheManager.new(config): return instance id and store config reference
    reg.register("CacheManager", "new", |ctx, _obj_id, args| {
        let cfg = args.get(0).cloned().unwrap_or_default();
        let idx = ctx.counters.entry("cache".into()).and_modify(|c| *c += 1).or_insert(1usize);
        let id = format!("CacheManager_{}", *idx);
        let _ = ctx.object_store.ensure(&id, "CacheManager");
        if !cfg.is_empty() { ctx.object_store.set(&id, "config", cfg); }
        ctx.object_store.set(&id, "enabled", "true");
        Ok(id)
    });
    // BuildOptions.release()/incremental(): return option string
    reg.register("BuildOptions", "release", |_ctx, _obj_id, _args| { Ok("release".to_string()) });
    reg.register("BuildOptions", "incremental", |_ctx, _obj_id, _args| { Ok("incremental".to_string()) });
    // BuildOrchestrator.execute_build(target_names:list_id, mode)
    reg.register("BuildOrchestrator", "execute_build", |ctx, obj_id, args| {
        let targets_list = args.get(0).cloned().unwrap_or_default();
        let mode = args.get(1).cloned().unwrap_or_else(|| "release".into());
        let result_id = format!("BuildResults_{}", ctx.counters.entry("build".into()).and_modify(|c| *c += 1).or_insert(1usize));
        let _ = ctx.object_store.ensure(&result_id, "BuildResults");
        ctx.object_store.set(&result_id, "mode", mode);
        // count successes = number of targets
        let mut count = 0usize;
        if let Some(list) = ctx.lists.get(&targets_list) { count = list.len(); }
        ctx.object_store.set(&result_id, "successful", count.to_string());
        ctx.object_store.set(&result_id, "all_successful?", if count > 0 { "true" } else { "false" });
        // attach targets back
        ctx.object_store.set(&result_id, "targets", targets_list);
        // link result on orchestrator for discoverability
        ctx.object_store.set(obj_id, "last_build", result_id.clone());
        Ok(result_id)
    });
    // allow property assignment via equals in object store using set
    reg
}

// Ensure registry is initialized
fn registry() -> &'static MethodRegistry { METHOD_REGISTRY.get_or_init(register_defaults) }

// --- Helpers ---

fn patc_compile_impl(in_path: &str, out_opt: Option<String>) -> Result<String, RuntimeError> {
    if in_path.is_empty() {
        return Err(RuntimeError::new(
            crate::error_handler::RuntimeErrorKind::CoreEvaluator,
            "patc_compile: missing input path",
        ));
    }
    let src = std::fs::read_to_string(in_path).map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("patc_compile: read '{}': {}", in_path, e),
    ))?;
    // Parse → Lower → Emit Rust
    let mut parser = Stage0Parser::new(&src).map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("patc_compile: parse init error: {:?}", e),
    ))?;
    let ast = parser.parse().map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("patc_compile: parse error: {:?}", e),
    ))?;
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let cg = RustCodegen::new();
    let rust_src = cg.emit_rust(&program);

    // Prepare output path
    let in_p = Path::new(in_path);
    let dest: PathBuf = if let Some(out) = out_opt {
        PathBuf::from(out)
    } else {
        let stem = in_p.file_stem().and_then(|s| s.to_str()).unwrap_or("a");
        let parent = in_p.parent().unwrap_or_else(|| Path::new("."));
        let mut out = parent.join(stem);
        if cfg!(windows) { out.set_extension("exe"); }
        out
    };
    if let Some(par) = dest.parent() { let _ = std::fs::create_dir_all(par); }

    // Write temp rust src and invoke rustc
    let mut tmp = std::env::temp_dir();
    tmp.push("patlang_emit_native");
    let _ = std::fs::create_dir_all(&tmp);
    let src_path = tmp.join("generated_main.rs");
    std::fs::write(&src_path, &rust_src).map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("patc_compile: write {}: {}", src_path.display(), e),
    ))?;
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let status = std::process::Command::new(&rustc)
        .arg("-O")
        .arg(&src_path)
        .arg("-o")
        .arg(&dest)
        .status()
        .map_err(|e| RuntimeError::new(
            crate::error_handler::RuntimeErrorKind::CoreEvaluator,
            format!("patc_compile: failed to run rustc: {}", e),
        ))?;
    if !status.success() {
        return Err(RuntimeError::new(
            crate::error_handler::RuntimeErrorKind::CoreEvaluator,
            format!("patc_compile: rustc failed with status {}", status),
        ));
    }
    let abs = std::fs::canonicalize(&dest).unwrap_or(dest);
    Ok(abs.display().to_string())
}

fn lower_and_compile_impl(ctx: &mut ExecutionContext, program_id: &str, out_opt: Option<String>) -> Result<String, RuntimeError> {
    // Decode Program
    let p_type = ctx.object_store.get(program_id, "type").unwrap_or_default();
    if p_type != "Program" { return Err(RuntimeError::new(crate::error_handler::RuntimeErrorKind::CoreEvaluator, "lower_and_compile: root.type != Program")); }
    let stmts_list = ctx.object_store.get(program_id, "stmts").unwrap_or_default();
    let mut stmts: Vec<Stmt> = Vec::new();
    if let Some(ids) = ctx.lists.get(&stmts_list).cloned() {
        for sid in ids {
            if let Some(t) = ctx.object_store.get(&sid, "type") {
                match t.as_str() {
                    "Print" => {
                        let expr_id = ctx.object_store.get(&sid, "expr").unwrap_or_default();
                        let expr = decode_expr(ctx, &expr_id)?;
                        stmts.push(Stmt::ExprStmt(Expr::Call { function: Box::new(Expr::Identifier("print".into())), args: vec![expr] }));
                    }
                    "Let" => {
                        let name = ctx.object_store.get(&sid, "name").unwrap_or_default();
                        let expr_id = ctx.object_store.get(&sid, "value").unwrap_or_default();
                        let value = decode_expr(ctx, &expr_id)?;
                        stmts.push(Stmt::Let { name, value });
                    }
                    "Return" => {
                        let val_id = ctx.object_store.get(&sid, "value").unwrap_or_default();
                        if val_id.is_empty() {
                            stmts.push(Stmt::Return(None));
                        } else {
                            let v = decode_expr(ctx, &val_id)?;
                            stmts.push(Stmt::Return(Some(v)));
                        }
                    }
                    // Generic expression statement holder if present: { type:"ExprStmt", expr: <expr_id> }
                    "ExprStmt" => {
                        let expr_id = ctx.object_store.get(&sid, "expr").unwrap_or_default();
                        if !expr_id.is_empty() {
                            let e = decode_expr(ctx, &expr_id)?;
                            stmts.push(Stmt::ExprStmt(e));
                        }
                    }
                    // Call statement: { type:"Call", name:"fn", args: <list_id> }
                    "Call" => {
                        let e = decode_expr(ctx, &sid)?;
                        stmts.push(Stmt::ExprStmt(e));
                    }
                    "If" => {
                        let cond_id = ctx.object_store.get(&sid, "cond").unwrap_or_default();
                        let then_list = ctx.object_store.get(&sid, "then").unwrap_or_default();
                        let else_list = ctx.object_store.get(&sid, "else");
                        let cond = decode_expr(ctx, &cond_id)?;
                        let mut then_stmts: Vec<Stmt> = Vec::new();
                        if let Some(ids2) = ctx.lists.get(&then_list) {
                            for tid in ids2 { if let Ok(s) = decode_stmt_like(ctx, tid) { if let Some(st) = s { then_stmts.push(st); } } }
                        }
                        let mut else_stmts: Option<Vec<Stmt>> = None;
                        if let Some(el) = else_list {
                            if let Some(ids3) = ctx.lists.get(&el) {
                                let mut es: Vec<Stmt> = Vec::new();
                                for eid in ids3 { if let Ok(s) = decode_stmt_like(ctx, eid) { if let Some(st) = s { es.push(st); } } }
                                else_stmts = Some(es);
                            }
                        }
                        stmts.push(Stmt::If { cond, then_branch: then_stmts, else_branch: else_stmts });
                    }
                    "While" => {
                        let cond_id = ctx.object_store.get(&sid, "cond").unwrap_or_default();
                        let body_list = ctx.object_store.get(&sid, "body").unwrap_or_default();
                        let cond = decode_expr(ctx, &cond_id)?;
                        let mut body_stmts: Vec<Stmt> = Vec::new();
                        if let Some(ids2) = ctx.lists.get(&body_list) {
                            for tid in ids2 { if let Ok(s) = decode_stmt_like(ctx, tid) { if let Some(st) = s { body_stmts.push(st); } } }
                        }
                        stmts.push(Stmt::While { cond, body: body_stmts });
                    }
                    _ => { /* ignore unsupported */ }
                }
            }
        }
    }
    // Lower → IR → Emit Rust
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&stmts);
    let cg = RustCodegen::new();
    let rust_src = cg.emit_rust(&program);
    // Choose output path
    let out_clean = out_opt.and_then(|s| if s.trim().is_empty() { None } else { Some(s) });
    let dest = out_clean.map(PathBuf::from).unwrap_or_else(|| {
        let mut p = std::env::temp_dir().join("patlang_native_out");
        let _ = std::fs::create_dir_all(&p);
        p.push(if cfg!(windows) { "a.exe" } else { "a.out" });
        p
    });
    compile_rust_src_to(&rust_src, &dest)?;
    let abs = std::fs::canonicalize(&dest).unwrap_or(dest);
    Ok(abs.display().to_string())
}

fn decode_expr(ctx: &ExecutionContext, id: &str) -> Result<Expr, RuntimeError> {
    let t = ctx.object_store.get(id, "type").unwrap_or_default();
    match t.as_str() {
        "Identifier" => {
            let v = ctx.object_store.get(id, "name").unwrap_or_default();
            Ok(Expr::Identifier(v))
        }
        "Number" => {
            let v = ctx.object_store.get(id, "value").unwrap_or_else(|| "0".into());
            let n = v.parse::<f64>().unwrap_or(0.0);
            Ok(Expr::Number(n))
        }
        "String" => {
            let v = ctx.object_store.get(id, "value").unwrap_or_default();
            Ok(Expr::String(v))
        }
        "UnaryOp" => {
            let op = ctx.object_store.get(id, "op").unwrap_or_default();
            let expr_id = ctx.object_store.get(id, "expr").unwrap_or_default();
            let inner = decode_expr(ctx, &expr_id)?;
            Ok(Expr::UnaryOp { op, expr: Box::new(inner) })
        }
        "BinaryOp" => {
            // Expect: op, left, right
            let op_s = ctx.object_store.get(id, "op").unwrap_or_default();
            let left_id = ctx.object_store.get(id, "left").unwrap_or_default();
            let right_id = ctx.object_store.get(id, "right").unwrap_or_default();
            let left = Box::new(decode_expr(ctx, &left_id)?);
            let right = Box::new(decode_expr(ctx, &right_id)?);
            let op = match op_s.as_str() {
                "+" => crate::ast::BinaryOperator::Add,
                "-" => crate::ast::BinaryOperator::Sub,
                "*" => crate::ast::BinaryOperator::Mul,
                "/" => crate::ast::BinaryOperator::Div,
                "%" => crate::ast::BinaryOperator::Mod,
                "==" => crate::ast::BinaryOperator::Equal,
                ">" => crate::ast::BinaryOperator::Greater,
                ">=" => crate::ast::BinaryOperator::GreaterEqual,
                "<" => crate::ast::BinaryOperator::Less,
                "<=" => crate::ast::BinaryOperator::LessEqual,
                other => return Err(RuntimeError::new(
                    crate::error_handler::RuntimeErrorKind::CoreEvaluator,
                    format!("lower_and_compile: unsupported BinaryOp op '{}'", other),
                )),
            };
            Ok(Expr::BinaryOp { left, op, right })
        }
        "Call" => {
            // Expect: name, args(list)
            let name = ctx.object_store.get(id, "name").unwrap_or_default();
            let args_list = ctx.object_store.get(id, "args").unwrap_or_default();
            let mut args: Vec<Expr> = Vec::new();
            if let Some(items) = ctx.lists.get(&args_list) {
                for aid in items {
                    args.push(decode_expr(ctx, aid)?);
                }
            }
            Ok(Expr::Call { function: Box::new(Expr::Identifier(name)), args })
        }
        _ => Err(RuntimeError::new(crate::error_handler::RuntimeErrorKind::CoreEvaluator, format!("lower_and_compile: unsupported expr type '{}'", t)))
    }
}

fn decode_stmt_like(ctx: &ExecutionContext, id: &str) -> Result<Option<Stmt>, RuntimeError> {
    if let Some(t) = ctx.object_store.get(id, "type") {
        return Ok(match t.as_str() {
            "Print" => {
                let expr_id = ctx.object_store.get(id, "expr").unwrap_or_default();
                let expr = decode_expr(ctx, &expr_id)?;
                Some(Stmt::ExprStmt(Expr::Call { function: Box::new(Expr::Identifier("print".into())), args: vec![expr] }))
            }
            "Let" => {
                let name = ctx.object_store.get(id, "name").unwrap_or_default();
                let expr_id = ctx.object_store.get(id, "value").unwrap_or_default();
                let value = decode_expr(ctx, &expr_id)?;
                Some(Stmt::Let { name, value })
            }
            "Return" => {
                let val_id = ctx.object_store.get(id, "value").unwrap_or_default();
                if val_id.is_empty() { Some(Stmt::Return(None)) } else { Some(Stmt::Return(Some(decode_expr(ctx, &val_id)?))) }
            }
            "Call" => Some(Stmt::ExprStmt(decode_expr(ctx, id)?)),
            _ => None,
        });
    }
    Ok(None)
}

fn compile_rust_src_to(rust_src: &str, dest: &Path) -> Result<(), RuntimeError> {
    let mut tmp = std::env::temp_dir();
    tmp.push("patlang_emit_from_shape");
    let _ = std::fs::create_dir_all(&tmp);
    let src_path = tmp.join("generated_main.rs");
    std::fs::write(&src_path, rust_src).map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("lower_and_compile: write {}: {}", src_path.display(), e),
    ))?;
    if let Some(par) = dest.parent() { let _ = std::fs::create_dir_all(par); }
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    let status = std::process::Command::new(&rustc)
        .arg("-O")
        .arg(&src_path)
        .arg("-o")
        .arg(dest)
        .status()
        .map_err(|e| RuntimeError::new(
            crate::error_handler::RuntimeErrorKind::CoreEvaluator,
            format!("lower_and_compile: failed to run rustc: {}", e),
        ))?;
    if !status.success() {
        return Err(RuntimeError::new(
            crate::error_handler::RuntimeErrorKind::CoreEvaluator,
            format!("lower_and_compile: rustc failed with status {}", status),
        ));
    }
    Ok(())
}

fn parse_tiny_source_impl(ctx: &mut ExecutionContext, path: &str) -> Result<String, RuntimeError> {
    let content = std::fs::read_to_string(path).map_err(|e| RuntimeError::new(
        crate::error_handler::RuntimeErrorKind::CoreEvaluator,
        format!("parse_tiny_source: read '{}': {}", path, e),
    ))?;

    // Create Program object
    let prog_id = new_map_obj(ctx, "Program");
    let stmts_list = {
        let id = format!("__list_{}", ctx.lists.len()+1);
        ctx.lists.insert(id.clone(), Vec::new());
        id
    };
    // Helpers: use functions to avoid long-lived borrows in closures

    let raw_lines: Vec<&str> = content.lines().collect();
    let mut i: usize = 0;
    while i < raw_lines.len() {
        let mut line = raw_lines[i].trim().to_string();
        i += 1;
        if line.is_empty() { continue; }
        if line.starts_with('#') { continue; }
        if line.ends_with(';') { line.pop(); }
        // while cond do ... end (support single-line and multi-line)
        if let Some(rest) = line.strip_prefix("while ") {
            if let Some(do_pos) = rest.find(" do") {
                let cond_src = rest[..do_pos].trim();
                let cond_id = parse_tiny_expr(ctx, cond_src)?;
                let body_list_id = format!("__list_{}", ctx.lists.len()+1);
                ctx.lists.insert(body_list_id.clone(), Vec::new());
                // Case A: single-line: body before ' end'
                if let Some(end_pos) = rest.find(" end") {
                    let body_src = rest[do_pos+3..end_pos].trim();
                    if !body_src.is_empty() {
                        for stmt_txt in body_src.split(';') { tiny_add_stmt_to_list(ctx, &body_list_id, stmt_txt); }
                    }
                } else {
                    // Case B: multi-line: collect until a line 'end'
                    while i < raw_lines.len() {
                        let mut body_line = raw_lines[i].trim().to_string();
                        i += 1;
                        if body_line.is_empty() || body_line.starts_with('#') { continue; }
                        if body_line.ends_with(';') { body_line.pop(); }
                        if body_line == "end" { break; }
                        tiny_add_stmt_to_list(ctx, &body_list_id, &body_line);
                    }
                }
                let s = new_map_obj(ctx, "While");
                ctx.object_store.set(&s, "type", "While");
                ctx.object_store.set(&s, "cond", cond_id);
                ctx.object_store.set(&s, "body", body_list_id);
                push_to_list(ctx, &stmts_list, s);
                continue;
            }
        }
        // if cond then ... else ... end (support single-line and multi-line)
        if let Some(rest) = line.strip_prefix("if ") {
            if let Some(then_pos) = rest.find(" then") {
                let cond_src = rest[..then_pos].trim();
                let cond_id = parse_tiny_expr(ctx, cond_src)?;
                let mut then_id = format!("__list_{}", ctx.lists.len()+1);
                ctx.lists.insert(then_id.clone(), Vec::new());
                let mut else_id: Option<String> = None;
                let after_then = &rest[then_pos+5..];
                if after_then.contains(" end") {
                    // Single-line form
                    let (then_src, else_src) = if let Some(ep) = after_then.find(" else ") { (&after_then[..ep], Some(&after_then[ep+6..])) } else { (after_then, None) };
                    let (then_body, else_body) = match else_src {
                        Some(e) => { let e2 = e.trim_end_matches(" end"); (then_src.trim(), Some(e2.trim())) }
                        None => (then_src.trim_end_matches(" end").trim(), None),
                    };
                    for part in then_body.split(';') { tiny_add_stmt_to_list(ctx, &then_id, part); }
                    if let Some(es) = else_body { let id = format!("__list_{}", ctx.lists.len()+1); ctx.lists.insert(id.clone(), Vec::new()); for part in es.split(';') { tiny_add_stmt_to_list(ctx, &id, part); } else_id = Some(id); }
                } else {
                    // Multi-line form: collect then lines until 'else' or 'end'
                    // If any content appears on the same line after 'then', treat it as a statement line first
                    let trailing = after_then.trim();
                    if !trailing.is_empty() { tiny_add_stmt_to_list(ctx, &then_id, trailing); }
                    // Now consume body lines
                    let mut in_else = false;
                    while i < raw_lines.len() {
                        let mut body_line = raw_lines[i].trim().to_string();
                        i += 1;
                        if body_line.is_empty() || body_line.starts_with('#') { continue; }
                        if body_line.ends_with(';') { body_line.pop(); }
                        if body_line == "else" { in_else = true; let id = format!("__list_{}", ctx.lists.len()+1); ctx.lists.insert(id.clone(), Vec::new()); else_id = Some(id); continue; }
                        if body_line == "end" { break; }
                        match in_else {
                            false => tiny_add_stmt_to_list(ctx, &then_id, &body_line),
                            true => if let Some(ref eid) = else_id { tiny_add_stmt_to_list(ctx, eid, &body_line); },
                        }
                    }
                }
                let s = new_map_obj(ctx, "If");
                ctx.object_store.set(&s, "type", "If");
                ctx.object_store.set(&s, "cond", cond_id);
                ctx.object_store.set(&s, "then", then_id);
                if let Some(eid) = else_id { ctx.object_store.set(&s, "else", eid); }
                push_to_list(ctx, &stmts_list, s);
                continue;
            }
        }
        // let statement
        if let Some(rest) = line.strip_prefix("let ") {
            if let Some(eq_pos) = rest.find('=') {
                let name = rest[..eq_pos].trim().to_string();
                let rhs = rest[eq_pos+1..].trim();
                let expr_id = parse_tiny_expr(ctx, rhs)?;
                let s = new_map_obj(ctx, "Let");
                ctx.object_store.set(&s, "type", "Let");
                ctx.object_store.set(&s, "name", name);
                ctx.object_store.set(&s, "value", expr_id);
                push_to_list(ctx, &stmts_list, s);
                continue;
            }
        }
        // return statement
        if let Some(rest) = line.strip_prefix("return ") {
            let expr_id = if rest.trim().is_empty() { String::new() } else { parse_tiny_expr(ctx, rest.trim())? };
            let s = new_map_obj(ctx, "Return");
            ctx.object_store.set(&s, "type", "Return");
            if !expr_id.is_empty() { ctx.object_store.set(&s, "value", expr_id); }
            push_to_list(ctx, &stmts_list, s);
            continue;
        }
        // print statement as special form for convenience
        if line.starts_with("print(") && line.ends_with(')') {
            let inner = &line[6..line.len()-1];
            let expr_id = parse_tiny_expr(ctx, inner.trim())?;
            let s = new_map_obj(ctx, "Print");
            ctx.object_store.set(&s, "type", "Print");
            ctx.object_store.set(&s, "expr", expr_id);
            push_to_list(ctx, &stmts_list, s);
            continue;
        }
        // generic call statement like fn(a, b)
        if let Some(_paren) = line.find('(') {
            if line.ends_with(')') {
                // Attempt to parse as call expression and wrap into ExprStmt
                let expr_id = parse_tiny_expr(ctx, &line)?;
                let t = ctx.object_store.get(&expr_id, "type").unwrap_or_default();
                if t == "Call" { push_to_list(ctx, &stmts_list, expr_id); continue; }
            }
        }
        // Unknown line: ignore for tiny parser
    }
    ctx.object_store.set(&prog_id, "stmts", stmts_list);
    Ok(prog_id)
}

fn new_map_obj(ctx: &mut ExecutionContext, class: &str) -> String {
    let idx = ctx.counters.entry("map".into()).and_modify(|c| *c += 1).or_insert(1usize);
    let id = format!("__map_{}", *idx);
    let _ = ctx.object_store.ensure(&id, class);
    id
}

fn push_to_list(ctx: &mut ExecutionContext, list_id: &str, value: String) {
    if let Some(v) = ctx.lists.get_mut(list_id) { v.push(value); }
}

// --- Tiny expression parser for parse_tiny_source ---
// Supports numbers, strings, identifiers, function calls, parentheses,
// arithmetic (+,-,*,/,%) and comparisons (==, <, <=, >, >=).

#[derive(Clone, Debug, PartialEq)]
enum TTok {
    Num(String), Str(String), Ident(String),
    LParen, RParen, Comma,
    Op(String),
}

fn tiny_tokenize(input: &str) -> Vec<TTok> {
    let mut t: Vec<TTok> = Vec::new();
    let bytes = input.as_bytes();
    let mut i = 0usize;
    while i < bytes.len() {
        let c = bytes[i] as char;
        if c.is_ascii_whitespace() { i += 1; continue; }
        if c.is_ascii_digit() {
            let start = i; i += 1;
            while i < bytes.len() && (bytes[i] as char).is_ascii_digit() { i += 1; }
            if i < bytes.len() && (bytes[i] as char) == '.' { i += 1; while i < bytes.len() && (bytes[i] as char).is_ascii_digit() { i += 1; } }
            t.push(TTok::Num(String::from_utf8(bytes[start..i].to_vec()).unwrap()));
            continue;
        }
        if c == '"' {
            i += 1; let start = i;
            while i < bytes.len() && (bytes[i] as char) != '"' { i += 1; }
            let s = String::from_utf8(bytes[start..i].to_vec()).unwrap_or_default();
            if i < bytes.len() { i += 1; }
            t.push(TTok::Str(s));
            continue;
        }
        if c.is_ascii_alphabetic() || c == '_' {
            let start = i; i += 1;
            while i < bytes.len() {
                let ch = bytes[i] as char;
                if ch.is_ascii_alphanumeric() || ch == '_' { i += 1; } else { break; }
            }
            t.push(TTok::Ident(String::from_utf8(bytes[start..i].to_vec()).unwrap()));
            continue;
        }
        match c {
            '(' => { t.push(TTok::LParen); i += 1; }
            ')' => { t.push(TTok::RParen); i += 1; }
            ',' => { t.push(TTok::Comma); i += 1; }
            '+' | '-' | '*' | '/' | '%' | '<' | '>' | '=' => {
                // two-char ops: <= >= ==
                if i+1 < bytes.len() {
                    let pair = (bytes[i] as char).to_string() + &(bytes[i+1] as char).to_string();
                    if pair == "<=" || pair == ">=" || pair == "==" { t.push(TTok::Op(pair)); i += 2; continue; }
                }
                t.push(TTok::Op(c.to_string())); i += 1;
            }
            _ => { i += 1; }
        }
    }
    t
}

struct TinyP<'a> { toks: &'a [TTok], pos: usize, ctx: *mut ExecutionContext }

impl<'a> TinyP<'a> {
    fn new(toks: &'a [TTok], ctx: *mut ExecutionContext) -> Self { Self { toks, pos: 0, ctx } }
    fn peek(&self) -> Option<&TTok> { self.toks.get(self.pos) }
    fn bump(&mut self) -> Option<TTok> { let p = self.pos; self.pos += 1; self.toks.get(p).cloned() }

    fn parse_expr(&mut self) -> Result<String, RuntimeError> { self.parse_equality() }
    fn parse_equality(&mut self) -> Result<String, RuntimeError> {
        let mut lhs = self.parse_relation()?;
        loop {
            let op_s = match self.peek() {
                Some(TTok::Op(op)) if op == "==" => op.clone(),
                _ => break,
            };
            let _ = self.bump();
            let rhs = self.parse_relation()?;
            lhs = self.mk_bin(&lhs, &op_s, &rhs);
        }
        Ok(lhs)
    }
    fn parse_relation(&mut self) -> Result<String, RuntimeError> {
        let mut lhs = self.parse_add()?;
        loop {
            let op_s = match self.peek() {
                Some(TTok::Op(op)) if op == "<" || op == "<=" || op == ">" || op == ">=" => op.clone(),
                _ => break,
            };
            let _ = self.bump();
            let rhs = self.parse_add()?;
            lhs = self.mk_bin(&lhs, &op_s, &rhs);
        }
        Ok(lhs)
    }
    fn parse_add(&mut self) -> Result<String, RuntimeError> {
        let mut lhs = self.parse_mul()?;
        loop {
            let op_s = match self.peek() {
                Some(TTok::Op(op)) if op == "+" || op == "-" => op.clone(),
                _ => break,
            };
            let _ = self.bump();
            let rhs = self.parse_mul()?;
            lhs = self.mk_bin(&lhs, &op_s, &rhs);
        }
        Ok(lhs)
    }
    fn parse_mul(&mut self) -> Result<String, RuntimeError> {
        let mut lhs = self.parse_unary()?;
        loop {
            let op_s = match self.peek() {
                Some(TTok::Op(op)) if op == "*" || op == "/" || op == "%" => op.clone(),
                _ => break,
            };
            let _ = self.bump();
            let rhs = self.parse_unary()?;
            lhs = self.mk_bin(&lhs, &op_s, &rhs);
        }
        Ok(lhs)
    }
    fn parse_unary(&mut self) -> Result<String, RuntimeError> {
        match self.peek() {
            Some(TTok::Op(op)) if op == "-" => { let _ = self.bump(); let expr_id = self.parse_unary()?; Ok(self.mk_unary("-", &expr_id)) }
            Some(TTok::Ident(s)) if s == "not" => { let _ = self.bump(); let expr_id = self.parse_unary()?; Ok(self.mk_unary("not", &expr_id)) }
            _ => self.parse_primary(),
        }
    }
    fn parse_primary(&mut self) -> Result<String, RuntimeError> {
        match self.bump() {
            Some(TTok::Num(n)) => Ok(self.mk_number(&n)),
            Some(TTok::Str(s)) => Ok(self.mk_string(&s)),
            Some(TTok::Ident(name)) => {
                // function call?
                if let Some(TTok::LParen) = self.peek() {
                    let _ = self.bump(); // consume '('
                    let args_list_id = self.mk_list();
                    // parse zero or more args
                    if let Some(TTok::RParen) = self.peek() { let _ = self.bump(); } else {
                        loop {
                            let expr_id = self.parse_expr()?;
                            self.list_push(&args_list_id, &expr_id);
                            match self.peek() {
                                Some(TTok::Comma) => { let _ = self.bump(); }
                                Some(TTok::RParen) => { let _ = self.bump(); break; }
                                _ => break,
                            }
                        }
                    }
                    Ok(self.mk_call(&name, args_list_id))
                } else {
                    Ok(self.mk_ident(name.clone()))
                }
            }
            Some(TTok::LParen) => {
                let inner = self.parse_expr()?;
                let _ = self.bump(); // expect RParen (best-effort)
                Ok(inner)
            }
            _ => Ok(self.mk_ident("".into())),
        }
    }

    // --- node builders ---
    fn mk_number(&mut self, n: &str) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "Number");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "Number");
        unsafe { &mut *self.ctx }.object_store.set(&id, "value", n.to_string());
        id
    }
    fn mk_string(&mut self, s: &str) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "String");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "String");
        unsafe { &mut *self.ctx }.object_store.set(&id, "value", s.to_string());
        id
    }
    fn mk_ident(&mut self, name: String) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "Identifier");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "Identifier");
        unsafe { &mut *self.ctx }.object_store.set(&id, "name", name);
        id
    }
    fn mk_list(&mut self) -> String {
        let id = format!("__list_{}", unsafe { &mut *self.ctx }.lists.len()+1);
        unsafe { &mut *self.ctx }.lists.insert(id.clone(), Vec::new());
        id
    }
    fn list_push(&mut self, list_id: &str, value_id: &str) {
        if let Some(v) = unsafe { &mut *self.ctx }.lists.get_mut(list_id) { v.push(value_id.to_string()); }
    }
    fn mk_bin(&mut self, left_id: &str, op: &str, right_id: &str) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "BinaryOp");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "BinaryOp");
        unsafe { &mut *self.ctx }.object_store.set(&id, "op", op.to_string());
        unsafe { &mut *self.ctx }.object_store.set(&id, "left", left_id.to_string());
        unsafe { &mut *self.ctx }.object_store.set(&id, "right", right_id.to_string());
        id
    }
    fn mk_call(&mut self, name: &str, args_list_id: String) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "Call");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "Call");
        unsafe { &mut *self.ctx }.object_store.set(&id, "name", name.to_string());
        unsafe { &mut *self.ctx }.object_store.set(&id, "args", args_list_id);
        id
    }
    fn mk_unary(&mut self, op: &str, expr_id: &str) -> String {
        let id = new_map_obj(unsafe { &mut *self.ctx }, "UnaryOp");
        unsafe { &mut *self.ctx }.object_store.set(&id, "type", "UnaryOp");
        unsafe { &mut *self.ctx }.object_store.set(&id, "op", op.to_string());
        unsafe { &mut *self.ctx }.object_store.set(&id, "expr", expr_id.to_string());
        id
    }
}

fn parse_tiny_expr(ctx: &mut ExecutionContext, src: &str) -> Result<String, RuntimeError> {
    let toks = tiny_tokenize(src);
    let ctx_ptr: *mut ExecutionContext = ctx as *mut _;
    let mut p = TinyP::new(&toks, ctx_ptr);
    p.parse_expr()
}

fn tiny_add_stmt_to_list(ctx: &mut ExecutionContext, list: &str, src: &str) {
    let st = src.trim(); if st.is_empty() { return; }
    if st.starts_with("let ") {
        if let Some(eq) = st.find('=') {
            let name = st[4..eq].trim().to_string();
            let rhs = st[eq+1..].trim();
            if let Ok(expr_id) = parse_tiny_expr(ctx, rhs) {
                let s = new_map_obj(ctx, "Let");
                ctx.object_store.set(&s, "type", "Let");
                ctx.object_store.set(&s, "name", name);
                ctx.object_store.set(&s, "value", expr_id);
                push_to_list(ctx, list, s);
            }
        }
    } else if st.starts_with("print(") && st.ends_with(')') {
        if let Ok(expr_id) = parse_tiny_expr(ctx, &st[6..st.len()-1]) {
            let s = new_map_obj(ctx, "Print");
            ctx.object_store.set(&s, "type", "Print");
            ctx.object_store.set(&s, "expr", expr_id);
            push_to_list(ctx, list, s);
        }
    } else if st.starts_with("return ") {
        let rest = &st[7..];
        if let Ok(expr_id) = parse_tiny_expr(ctx, rest.trim()) {
            let s = new_map_obj(ctx, "Return");
            ctx.object_store.set(&s, "type", "Return");
            if !expr_id.is_empty() { ctx.object_store.set(&s, "value", expr_id); }
            push_to_list(ctx, list, s);
        }
    } else if st.contains('(') && st.ends_with(')') {
        if let Ok(expr_id) = parse_tiny_expr(ctx, st) {
            if ctx.object_store.get(&expr_id, "type").unwrap_or_default() == "Call" { push_to_list(ctx, list, expr_id); }
        }
    }
}
