use std::collections::HashMap;
use std::sync::Arc;

use super::types::*;
use super::ops;

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
        self.run_function(program, entry, &[])
    }

    /// Call an arbitrary named function in `program` with explicit argument
    /// values, without going through `program.entry`. Used by embedders (e.g.
    /// the `syntax_dsl` source preprocessor) that load a small PatLang library
    /// program once and then repeatedly invoke one of its functions directly,
    /// rather than re-running a `main`/entry point each time.
    pub fn call_function(&self, program: &Program, name: &str, args: &[Value]) -> Result<Value, String> {
        let func = program.functions.get(name)
            .ok_or_else(|| format!("function '{}' not found", name))?;
        self.run_function(program, func, args)
    }

    fn run_function(&self, program: &Program, func: &Function, args: &[Value]) -> Result<Value, String> {
        let mut pc: usize = 0;
        let mut stack: Vec<Value> = Vec::new();

        // Slot table, precomputed ONCE per call (not once per instruction):
        // every distinct local name referenced by this function (params
        // plus every LoadLocal/StoreLocal target in the body) gets a fixed
        // integer slot, and `locals` becomes a plain Vec<Value> indexed by
        // that slot instead of a HashMap<String,Value> re-hashed on every
        // single read/write. Real, measured bottleneck this fixes: a bare
        // loop with NO arithmetic at all (`while i < N do let i = i + 1
        // end`) cost ~240ns/iteration natively compiled -- confirmed via
        // fantgame's PHASE0_SPIKE_RESULTS.md (a Ruby-to-PatLang port
        // reporting ~21x slower than Ruby, originally misattributed to the
        // numeric tower) that the dominant cost was this per-name hashmap
        // lookup, uniform across int/float workloads. Function.locals:
        // Vec<String> exists but is never populated by lowering.rs, so
        // this resolves names fresh per call rather than relying on it --
        // still a strict win (one linear pass over the body vs. rehashing
        // a string on every one of potentially millions of iterations).
        let mut slot_of: HashMap<&str, usize> = HashMap::new();
        for name in &func.params {
            let next = slot_of.len();
            slot_of.entry(name.as_str()).or_insert(next);
        }
        for instr in &func.body {
            match instr {
                Instr::LoadLocal(name) | Instr::StoreLocal(name) => {
                    let next = slot_of.len();
                    slot_of.entry(name.as_str()).or_insert(next);
                }
                _ => {}
            }
        }
        let resolved: Vec<usize> = func.body.iter().map(|instr| match instr {
            Instr::LoadLocal(name) | Instr::StoreLocal(name) => slot_of[name.as_str()],
            _ => usize::MAX, // never read for any other instruction kind
        }).collect();
        let mut locals: Vec<Value> = vec![Value::Unit; slot_of.len()];
        for (i, name) in func.params.iter().enumerate() {
            if let Some(v) = args.get(i) { locals[slot_of[name.as_str()]] = v.clone(); }
        }

        while pc < func.body.len() {
            match &func.body[pc] {
                Instr::Const(v) => stack.push(v.clone()),
                Instr::LoadLocal(_) => {
                    stack.push(locals[resolved[pc]].clone());
                }
                Instr::StoreLocal(_) => {
                    let v = stack.pop().ok_or("stack underflow")?;
                    locals[resolved[pc]] = v;
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
                                last = self.run_function(program, callee, &[Value::String(ev.clone()), payload.clone()])?;
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
                                    last = self.run_function(program, callee, &full_args)?;
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
                            let ret = self.run_function(program, callee, &full_args)?;
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
                        let ret = self.run_function(program, callee, &args[1..])?;
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
                    let callee = program.functions.get(fname).ok_or_else(|| format!("function '{}' not found", fname))?;
                    let ret = self.run_function(program, callee, &argsv)?;
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
                            let ret = self.run_function(program, callee, &full_args)?;
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
