use std::collections::HashMap;
use std::sync::Arc;
use std::cell::RefCell;
use std::rc::Rc;

use super::types::*;
use super::ops;

// Per-function precomputed dispatch info, cached ONCE PER FUNCTION (keyed by
// the function's own stable address) rather than once per CALL -- see
// run_function's own doc comment for the full story of why a per-CALL
// precompute (an earlier version of this fix) was actually a regression for
// fantgame's real ecosystem_bench.patlang: functions with short bodies but
// millions of calls (update_prey/update_predator/regen_vegetation) were
// paying a fresh Vec-allocation-and-body-scan cost on every single call,
// outweighing the hashing it replaced. Caching per function (safe because a
// Function's body and the Program's function table are both immutable after
// construction -- confirmed, nothing in this codebase ever mutates either
// post-lowering, so a given function's slot/call-target resolution can never
// change mid-run) means that cost is now paid at most once per DISTINCT
// function, ever, not once per call.
struct FnPrecomputed<'p> {
    // Per-instruction resolved local-variable slot index (for LoadLocal/
    // StoreLocal positions; usize::MAX/unused elsewhere). Parameter i always
    // occupies slot i (guaranteed by construction order below), so binding
    // args needs no separate lookup table.
    resolved: Vec<usize>,
    slot_count: usize,
    // Per-instruction resolved callee (for Instr::Call positions only --
    // deliberately NOT extended to Instr::CallValue, whose target is a
    // dynamic Value::Closure read off the stack at runtime and can genuinely
    // differ across calls from the very same instruction position; caching
    // that would be a real correctness bug, not just a missed optimization).
    resolved_call: Vec<Option<&'p Function>>,
    // Per-LoadLocal-instruction "safe to MOVE instead of clone" flag -- see
    // codegen.rs's FnPrecomputed (the compiled-binary counterpart of this
    // same interpreter, which has the identical field with the full
    // rationale) for the complete explanation: LoadLocal always cloning the
    // Arc means `let x = list_push(x, v)` NEVER lets Arc::make_mut see a
    // uniquely-held Arc, forcing a full deep-clone on every call (a real,
    // measured O(n^2): 8192 elems ~521ms, 32768 ~17.4s). This flags the
    // common `let x = f(..., x, ...)` reassignment idiom as move-safe under
    // the same conservative straight-line/no-jump-target-inside conditions.
    move_ok: Vec<bool>,
}

// Keyed by the calling function's own address (stable for as long as the
// Program that owns it isn't dropped) -- created FRESH at every genuine
// call-tree root (Interpreter::run, Interpreter::call_function) and passed
// down through every recursive run_function call within that SAME call
// tree/thread, never shared across threads or across distinct Program
// instances. This is what makes it safe with no synchronization at all:
// each fiber gets its own freshly-cloned Program and would need its own
// fresh cache at its own root (native compiled path only -- this
// interpreter doesn't run fibers itself, see ir/fiber.rs); this
// interpreter's own parallel_map (below) spawns real OS threads sharing
// the SAME Program via std::thread::scope, so each worker closure creates
// its own fresh cache too, rather than trying to share one across threads.
type PrecomputeCache<'p> = RefCell<HashMap<usize, Rc<FnPrecomputed<'p>>>>;

#[derive(Default)]
pub struct HostFuncs {
    map: HashMap<String, fn(&[Value]) -> Result<Value, String>>,
}

impl HostFuncs {
    pub fn new() -> Self { Self { map: HashMap::new() } }
    pub fn insert(&mut self, name: &str, f: fn(&[Value]) -> Result<Value, String>) {
        self.map.insert(name.to_string(), f);
    }
    pub fn get(&self, name: &str) -> Option<&fn(&[Value]) -> Result<Value, String>> { self.map.get(name) }
}

#[derive(Default)]
pub struct Interpreter {
    pub host: HostFuncs,
}

impl Interpreter {
    pub fn new() -> Self { Self { host: HostFuncs::new() } }

    pub fn run(&self, program: &Program) -> Result<Value, String> {
        let entry = program.functions.get(&program.entry)
            .ok_or_else(|| format!("entry function '{}' not found", program.entry))?;
        let cache = PrecomputeCache::default();
        self.run_function(program, entry, &[], &cache)
    }

    /// Call an arbitrary named function in `program` with explicit argument
    /// values, without going through `program.entry`. Used by embedders (e.g.
    /// the `syntax_dsl` source preprocessor) that load a small PatLang library
    /// program once and then repeatedly invoke one of its functions directly,
    /// rather than re-running a `main`/entry point each time.
    pub fn call_function(&self, program: &Program, name: &str, args: &[Value]) -> Result<Value, String> {
        let func = program.functions.get(name)
            .ok_or_else(|| format!("function '{}' not found", name))?;
        let cache = PrecomputeCache::default();
        self.run_function(program, func, args, &cache)
    }

    fn run_function<'p>(&self, program: &'p Program, func: &'p Function, args: &[Value], cache: &PrecomputeCache<'p>) -> Result<Value, String> {
        let mut pc: usize = 0;
        let mut stack: Vec<Value> = Vec::new();

        // Precomputed dispatch table, cached ONCE PER FUNCTION (keyed by this
        // function's own address) rather than rebuilt on every call -- see
        // FnPrecomputed's doc comment above for the full story, including why
        // an earlier once-per-CALL version of this was actually a measured
        // regression for fantgame's real ecosystem_bench.patlang (short-body,
        // many-call functions like update_prey/update_predator/
        // regen_vegetation were paying a fresh Vec-allocation-and-body-scan
        // cost on every one of their 1.6M+ calls). Safe to cache for the
        // whole cache's lifetime because a Function's body and the Program's
        // function table are both immutable after construction -- nothing in
        // this codebase mutates either post-lowering, so this can never go
        // stale mid-run.
        let key = func as *const Function as usize;
        let existing = cache.borrow().get(&key).cloned();
        let precomp = match existing {
            Some(p) => p,
            None => {
                let mut slot_of: HashMap<&str, usize> = HashMap::new();
                for name in &func.params {
                    let next = slot_of.len();
                    slot_of.entry(name.as_str()).or_insert(next);
                }
                for instr in &func.body {
                    if let Instr::LoadLocal(name) | Instr::StoreLocal(name) = instr {
                        let next = slot_of.len();
                        slot_of.entry(name.as_str()).or_insert(next);
                    }
                }
                let resolved: Vec<usize> = func.body.iter().map(|instr| match instr {
                    Instr::LoadLocal(name) | Instr::StoreLocal(name) => slot_of[name.as_str()],
                    _ => usize::MAX,
                }).collect();
                // Instr::Call's target name is fixed at lowering time, so
                // it always resolves to the same function -- safe to cache.
                // Instr::CallValue is deliberately NOT precomputed here (see
                // FnPrecomputed's doc comment): its target is a dynamic
                // Value::Closure read off the stack, which genuinely can
                // differ across calls from the same instruction position.
                let resolved_call: Vec<Option<&'p Function>> = func.body.iter().map(|instr| match instr {
                    Instr::Call(fname, _) => program.functions.get(fname),
                    _ => None,
                }).collect();
                let move_ok: Vec<bool> = (0..func.body.len()).map(|pc0| {
                    if !matches!(func.body[pc0], Instr::LoadLocal(_)) { return false; }
                    let slot = resolved[pc0];
                    let mut store_pc: Option<usize> = None;
                    for pc1 in (pc0 + 1)..func.body.len() {
                        match &func.body[pc1] {
                            Instr::LoadLocal(_) if resolved[pc1] == slot => break,
                            Instr::StoreLocal(_) if resolved[pc1] == slot => { store_pc = Some(pc1); break; }
                            _ => {}
                        }
                    }
                    let store_pc = match store_pc { Some(q) => q, None => return false };
                    for pc1 in (pc0 + 1)..store_pc {
                        if matches!(func.body[pc1], Instr::Jump(_) | Instr::JumpIfFalse(_)) { return false; }
                    }
                    for instr in &func.body {
                        if let Instr::Jump(t) | Instr::JumpIfFalse(t) = instr {
                            if *t > pc0 && *t <= store_pc { return false; }
                        }
                    }
                    true
                }).collect();
                let slot_count = slot_of.len();
                let p = Rc::new(FnPrecomputed { resolved, slot_count, resolved_call, move_ok });
                cache.borrow_mut().insert(key, Rc::clone(&p));
                p
            }
        };
        // Parameter i always occupies slot i, guaranteed by the slot-
        // assignment order above (params inserted first, in order) --
        // no separate name->slot lookup needed to bind args.
        let mut locals: Vec<Value> = vec![Value::Unit; precomp.slot_count];
        for (i, v) in args.iter().enumerate().take(func.params.len()) {
            locals[i] = v.clone();
        }

        while pc < func.body.len() {
            match &func.body[pc] {
                Instr::Const(v) => stack.push(v.clone()),
                Instr::LoadLocal(_) => {
                    let slot = precomp.resolved[pc];
                    if precomp.move_ok[pc] {
                        stack.push(std::mem::replace(&mut locals[slot], Value::Unit));
                    } else {
                        stack.push(locals[slot].clone());
                    }
                }
                Instr::StoreLocal(_) => {
                    let v = stack.pop().ok_or("stack underflow")?;
                    locals[precomp.resolved[pc]] = v;
                }
                Instr::UnOp(kind) => {
                    let a = stack.pop().ok_or("stack underflow")?;
                    let res = match kind {
                        UnOpKind::Neg => ops::negate(&a)?,
                        UnOpKind::Not => Value::Bool(!a.as_bool()?),
                        UnOpKind::BitNot => ops::bitnot(&a)?,
                    };
                    stack.push(res);
                }
                Instr::BinOp(kind) => {
                    use BinOpKind::*;
                    let b = stack.pop().ok_or("stack underflow")?;
                    let a = stack.pop().ok_or("stack underflow")?;
                    let res = match kind {
                        Add => ops::add(&a, &b)?,
                        Sub => ops::sub(&a, &b)?,
                        Mul => ops::mul(&a, &b)?,
                        Div => ops::div(&a, &b)?,
                        Mod => ops::modu(&a, &b)?,
                        Eq | Ne | Lt | Le | Gt | Ge => ops::cmp(kind.clone(), &a, &b)?,
                        And => Value::Bool(a.as_bool()? && b.as_bool()?),
                        Or => Value::Bool(a.as_bool()? || b.as_bool()?),
                        BitAnd => ops::bitand(&a, &b)?,
                        BitOr => ops::bitor(&a, &b)?,
                        BitXor => ops::bitxor(&a, &b)?,
                        Shl => ops::shl(&a, &b)?,
                        Shr => ops::shr(&a, &b)?,
                    };
                    stack.push(res);
                }
                Instr::Jump(target) => { pc = *target; continue; }
                Instr::JumpIfFalse(target) => {
                    let cond = stack.pop().ok_or("stack underflow")?;
                    if !cond.as_bool()? { pc = *target; continue; }
                }
                Instr::CallHost(name, argc) => {
                    let argc = *argc;
                    if stack.len() < argc { return Err("stack underflow".into()); }
                    let args_index = stack.len() - argc;
                    let args: Vec<Value> = stack.drain(args_index..).collect();
                    if name == "emit" {
                        // args: event name (string), optional payload (any)
                        let ev = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new().into() };
                        let payload = args.get(1).cloned().unwrap_or(Value::Unit);
                        let mut last = Value::Unit;
                        // Legacy path: bare-named handlers registered at compile
                        // time (still used by compile_shape/compile_ir's IR-shape
                        // based "When"/EventIR handling, hosts.rs -- those build a
                        // Program from an already-lowered shape, not source-level
                        // `when` blocks, so they're unaffected by lower_when's
                        // move to real closures and still register by name).
                        if let Some(handlers) = program.event_handlers.get(ev.as_str()) {
                            for h in handlers {
                                let callee = program.functions.get(h).ok_or_else(|| format!("function '{}' not found", h))?;
                                // Handlers take (event_name, event_data)
                                last = self.run_function(program, callee, &[Value::String(ev.clone()), payload.clone()], cache)?;
                            }
                        }
                        // Real path: `when EVENT { ... }` source blocks now lower
                        // to a genuine closure, registered at RUNTIME (via
                        // register_event_handler, called from wherever the `when`
                        // statement actually executes) rather than a bare function
                        // name -- see lowering.rs's lower_when doc comment for why
                        // (it's what lets a handler see an enclosing `let`). Called
                        // exactly like Instr::CallValue calls any other closure,
                        // since this IS the interpreter, not a host-fn boundary
                        // (host fns can't call closures themselves).
                        for h in super::hosts::runtime_event_handlers_for(ev.as_str()) {
                            match h {
                                Value::Closure { func_name, captured } => {
                                    let mut full_args: Vec<Value> = captured.into_iter().map(|(_, v)| v).collect();
                                    full_args.push(Value::String(ev.clone()));
                                    full_args.push(payload.clone());
                                    let callee = program.functions.get(&func_name)
                                        .ok_or_else(|| format!("function '{}' not found", func_name))?;
                                    last = self.run_function(program, callee, &full_args, cache)?;
                                }
                                other => return Err(format!("emit: registered event handler is not a closure: {:?}", other)),
                            }
                        }
                        stack.push(last);
                    } else if name == "send" {
                        // Slice 2 of classes/traits/inheritance: send(recv,
                        // method, args...) first checks for a genuine
                        // user-defined method (registered via `class_def`,
                        // see hosts.rs::resolve_class_method) on recv's
                        // class, walking the parent chain -- this needs to
                        // live HERE, not in host_send, since host fns can't
                        // invoke closures themselves (same reason `emit`'s
                        // closure-invocation logic lives here too). Falls
                        // back to today's host_send behavior ("set" etc.)
                        // when no matching method exists anywhere in the
                        // chain, so ad hoc `new("Literal","id")` objects
                        // with no class ever declared keep working exactly
                        // as before.
                        let recv = args.get(0).cloned().unwrap_or(Value::Unit);
                        let method = match args.get(1) { Some(Value::String(s)) => s.as_ref().clone(), _ => String::new() };
                        let recv_class = match &recv {
                            Value::String(s) => super::hosts::obj_get(s.as_ref(), "type"),
                            _ => None,
                        };
                        let resolved = match recv_class {
                            Some(Value::String(cls)) => super::hosts::resolve_class_method(cls.as_ref(), &method),
                            _ => None,
                        };
                        if let Some(Value::Closure { func_name, captured }) = resolved {
                            let mut full_args: Vec<Value> = captured.into_iter().map(|(_, v)| v).collect();
                            full_args.push(recv);
                            full_args.extend(args[2..].iter().cloned());
                            let callee = program.functions.get(&func_name).ok_or_else(|| format!("function '{}' not found", func_name))?;
                            let ret = self.run_function(program, callee, &full_args, cache)?;
                            stack.push(ret);
                        } else {
                            let f = self.host.get(name).ok_or_else(|| format!("host fn '{}' not found", name))?;
                            let res = f(&args)?;
                            stack.push(res);
                        }
                    } else if name == "apply" {
                        // apply(fname, args...): call a program function by name,
                        // enabling higher-order style (map/filter over named fns)
                        let fname = match args.get(0) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("apply: expected function name string, got {:?}", other)),
                        };
                        let callee = program.functions.get(fname.as_str())
                            .ok_or_else(|| format!("apply: function '{}' not found", fname))?;
                        let ret = self.run_function(program, callee, &args[1..], cache)?;
                        stack.push(ret);
                    } else if name == "parallel_map" {
                        // parallel_map(items, "func_name") -> list of
                        // func_name(item) results, computed across REAL OS
                        // threads (std::thread::scope -- each worker
                        // borrows `program`/`self` directly, no cloning
                        // needed, since Program/Interpreter are plain data
                        // with no interior mutability). Genuine parallelism,
                        // unlike fibers (see ir/fiber.rs), which are
                        // cooperative and never actually run concurrently.
                        let items = match args.get(0) {
                            Some(Value::List(xs)) => xs.clone(),
                            other => return Err(format!("parallel_map: expected a list as the first arg, got {:?}", other)),
                        };
                        let fname = match args.get(1) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("parallel_map: expected a function name string as the second arg, got {:?}", other)),
                        };
                        if !program.functions.contains_key(fname.as_str()) {
                            return Err(format!("parallel_map: function '{}' not found", fname));
                        }
                        let results: Result<Vec<Value>, String> = std::thread::scope(|scope| {
                            let handles: Vec<_> = items
                                .iter()
                                .map(|item| {
                                    let fname = &fname;
                                    scope.spawn(move || {
                                        let mut interp = Interpreter::new();
                                        super::hosts::register_stage0_shims(&mut interp);
                                        interp.call_function(program, fname, std::slice::from_ref(item))
                                    })
                                })
                                .collect();
                            handles
                                .into_iter()
                                .map(|h| h.join().unwrap_or_else(|_| Err("parallel_map: a worker thread panicked".to_string())))
                                .collect()
                        });
                        stack.push(Value::List(Arc::new(results?)));
                    } else if name == "fiber_new" {
                        let fname = match args.get(0) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("fiber_new: expected a function name string, got {:?}", other)),
                        };
                        stack.push(super::fiber::fiber_new(program, (*fname).clone())?);
                    } else if name == "fiber_resume" {
                        let id = args.get(0).cloned().unwrap_or(Value::Unit);
                        let arg = args.get(1).cloned().unwrap_or(Value::Unit);
                        stack.push(super::fiber::fiber_resume(&id, arg)?);
                    } else if name == "fiber_yield" {
                        let v = args.get(0).cloned().unwrap_or(Value::Unit);
                        stack.push(super::fiber::fiber_yield(v)?);
                    } else if name == "fiber_alive" {
                        let id = args.get(0).cloned().unwrap_or(Value::Unit);
                        stack.push(super::fiber::fiber_alive(&id)?);
                    } else if name == "budgeted_run" {
                        let ms = match args.get(0) { Some(v) => v.as_number().map_err(|_| "budgeted_run: expected a number of ms".to_string())? as i64, None => return Err("budgeted_run: expected ms".into()) };
                        let fname = match args.get(1) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("budgeted_run: expected a function name string, got {:?}", other)),
                        };
                        let captured = args.get(2).cloned().unwrap_or(Value::List(Arc::new(vec![])));
                        let existing = args.get(3).cloned().unwrap_or(Value::Unit);
                        stack.push(super::fiber::budgeted_run(program, ms, &fname, captured, &existing)?);
                    } else if name == "budget_check" {
                        super::fiber::budget_check()?;
                        stack.push(Value::Unit);
                    } else if name == "list_push" && args.len() == 2 {
                        // See codegen.rs's matching special-case (the
                        // compiled-binary counterpart of this same
                        // interpreter) for the full explanation: routing
                        // through the generic `self.host.get(name)` ->
                        // `host_list_push(&[Value])` path always sees
                        // strong_count > 1 (that function's own borrowed
                        // `args` slice keeps its own Arc reference alive
                        // alongside the clone it makes internally), forcing
                        // Arc::make_mut to deep-clone on every call
                        // regardless of caller uniqueness. Using owned
                        // `args` here (already moved off the stack) avoids
                        // that extra reference entirely.
                        let mut it = args.into_iter();
                        let first = it.next().unwrap();
                        let item = it.next().unwrap();
                        let result = match first {
                            Value::List(mut xs) => { Arc::make_mut(&mut xs).push(item); Value::List(xs) }
                            Value::Unit => Value::List(Arc::new(vec![item])),
                            _ => return Err("list_push: expected list".into()),
                        };
                        stack.push(result);
                    } else if name == "list_set" && args.len() == 3 {
                        let mut it = args.into_iter();
                        let first = it.next().unwrap();
                        let idxv = it.next().unwrap();
                        let value = it.next().unwrap();
                        let idx = match &idxv { Value::String(s) => s.parse::<usize>().unwrap_or(usize::MAX), v => super::ops::as_index(v).unwrap_or(usize::MAX) };
                        let mut xs = match first { Value::List(xs) => xs, _ => return Err("list_set: expected list".into()) };
                        if idx >= xs.len() { return Err(format!("list_set: index {} out of range (len {})", idx, xs.len())); }
                        Arc::make_mut(&mut xs)[idx] = value;
                        stack.push(Value::List(xs));
                    } else {
                        let f = self.host.get(name).ok_or_else(|| format!("host fn '{}' not found", name))?;
                        let res = f(&args)?;
                        stack.push(res);
                    }
                }
                Instr::Call(fname, argc) => {
                    let argc = *argc;
                    if stack.len() < argc { return Err("stack underflow".into()); }
                    let args_index = stack.len() - argc;
                    let argsv: Vec<Value> = stack.drain(args_index..).collect();
                    let callee = precomp.resolved_call[pc].ok_or_else(|| format!("function '{}' not found", fname))?;
                    let ret = self.run_function(program, callee, &argsv, cache)?;
                    stack.push(ret);
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
                    let argc = *argc;
                    if stack.len() < argc { return Err("stack underflow".into()); }
                    let args_index = stack.len() - argc;
                    let call_args: Vec<Value> = stack.drain(args_index..).collect();
                    let callee_val = stack.pop().ok_or("stack underflow")?;
                    match callee_val {
                        Value::Closure { func_name, captured } => {
                            let mut full_args: Vec<Value> = captured.into_iter().map(|(_, v)| v).collect();
                            full_args.extend(call_args);
                            let callee = program.functions.get(&func_name)
                                .ok_or_else(|| format!("function '{}' not found", func_name))?;
                            let ret = self.run_function(program, callee, &full_args, cache)?;
                            stack.push(ret);
                        }
                        other => return Err(format!("cannot call non-closure value: {:?}", other)),
                    }
                }
                Instr::BuildList(n) => {
                    let n = *n;
                    if stack.len() < n { return Err("stack underflow".into()); }
                    let start = stack.len() - n;
                    let items: Vec<Value> = stack.drain(start..).collect();
                    // items are in evaluation order; keep order as-is
                    stack.push(Value::List(Arc::new(items)));
                }
                Instr::Return => {
                    return Ok(stack.pop().unwrap_or(Value::Unit));
                }
            }
            pc += 1;
        }
        Ok(stack.pop().unwrap_or(Value::Unit))
    }
}
