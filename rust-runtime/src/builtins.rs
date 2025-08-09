//! Built-in functions registry and handlers.
//!
//! This module centralizes handling for core built-ins so the evaluator stays generic.

use crate::error_handler::RuntimeError;
use crate::logic_engine::{Fact, Query, Term};
use crate::runtime_integration::on_query_results;

// We reuse the evaluator's ExecutionContext type to avoid large refactors right now.
use crate::core_evaluator::ExecutionContext;

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
