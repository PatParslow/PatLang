use std::collections::HashMap;

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

    fn run_function(&self, program: &Program, func: &Function, args: &[Value]) -> Result<Value, String> {
        let mut pc: usize = 0;
        let mut stack: Vec<Value> = Vec::new();
        let mut locals: HashMap<String, Value> = HashMap::new();
        // Bind parameters as locals if present
        for (i, name) in func.params.iter().enumerate() {
            if let Some(v) = args.get(i) { locals.insert(name.clone(), v.clone()); }
        }

        while pc < func.body.len() {
            match &func.body[pc] {
                Instr::Const(v) => stack.push(v.clone()),
                Instr::LoadLocal(name) => {
                    let v = locals.get(name).cloned().unwrap_or(Value::Unit);
                    stack.push(v);
                }
                Instr::StoreLocal(name) => {
                    let v = stack.pop().ok_or("stack underflow")?;
                    locals.insert(name.clone(), v);
                }
                Instr::UnOp(kind) => {
                    let a = stack.pop().ok_or("stack underflow")?;
                    let res = match kind {
                        UnOpKind::Neg => Value::Number(-a.as_number()?),
                        UnOpKind::Not => Value::Bool(!a.as_bool()?),
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
                        let ev = match args.get(0) { Some(Value::String(s)) => s.clone(), _ => String::new() };
                        let payload = args.get(1).cloned().unwrap_or(Value::Unit);
                        let mut last = Value::Unit;
                        if let Some(handlers) = program.event_handlers.get(&ev) {
                            for h in handlers {
                                let callee = program.functions.get(h).ok_or_else(|| format!("function '{}' not found", h))?;
                                // Handlers take (event_name, event_data)
                                last = self.run_function(program, callee, &[Value::String(ev.clone()), payload.clone()])?;
                            }
                        }
                        stack.push(last);
                    } else if name == "apply" {
                        // apply(fname, args...): call a program function by name,
                        // enabling higher-order style (map/filter over named fns)
                        let fname = match args.get(0) {
                            Some(Value::String(s)) => s.clone(),
                            other => return Err(format!("apply: expected function name string, got {:?}", other)),
                        };
                        let callee = program.functions.get(&fname)
                            .ok_or_else(|| format!("apply: function '{}' not found", fname))?;
                        let ret = self.run_function(program, callee, &args[1..])?;
                        stack.push(ret);
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
                Instr::BuildList(n) => {
                    let n = *n;
                    if stack.len() < n { return Err("stack underflow".into()); }
                    let start = stack.len() - n;
                    let mut items: Vec<Value> = stack.drain(start..).collect();
                    // items are in evaluation order; keep order as-is
                    stack.push(Value::List(items));
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
