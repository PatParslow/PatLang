// use crate::ast::Expr; // no direct use; keep parser conversions local
// Core Evaluator Module
//
// Responsibilities:
// - Traverse and execute AST nodes
// - Manage execution context and scope
// - Integrate with Event System, Message Queue, Error Handler, and Secure Distributed Code Support
//
// Extensibility Points:
// - Custom AST node handlers
// - Pluggable execution strategies
// - Context/scope extensions
//
// This is a scaffold for the core evaluator logic.

use crate::event_system::{Event, EventListener};
use crate::message_queue::MessageConsumer;
use crate::error_handler::{ErrorHandler, RuntimeError};
use crate::secure_distributed_code_support::{SecurityPolicy, DistributedProtocol};
use crate::object::ObjectStore;
use crate::runtime_integration::TypeInferenceRegistry;
use std::collections::HashMap;
use crate::builtins;

#[derive(Debug, Clone)]
pub enum AstKind {
    Number(f64),
    String(String),
    Identifier(String),
    List(Vec<AstNode>),
    Closure { params: Vec<String>, body: Vec<AstNode> },
    Print(Box<AstNode>),
    If {
        cond: Box<AstNode>,
        then_branch: Vec<AstNode>,
        else_branch: Option<Vec<AstNode>>,
    },
    While {
        cond: Box<AstNode>,
        body: Vec<AstNode>,
    },
    BinaryOp {
        op: crate::ast::BinaryOpKind,
        left: Box<AstNode>,
        right: Box<AstNode>,
    },
    StringOp {
        op: crate::string::StringOp,
        left: Box<AstNode>,
        right: Option<Box<AstNode>>,
    },
    FunctionCall {
        name: String,
        args: Vec<AstNode>,
    },
    // Pipeline application: input |> function/identifier/closure
    Pipeline {
        input: Box<AstNode>,
        func: Box<AstNode>,
    },
    ObjectOp {
        class_name: String,
        // Extend as needed
    },
    ReasoningOp {
        op: crate::reasoning::ReasoningOp,
        input: Box<AstNode>,
    },
    // Add more as needed
    Block(Vec<AstNode>),
    // Register an event handler captured from: when <event> { body }
    WhenRegister { event: String, body: Vec<AstNode> },
}

#[derive(Debug, Clone)]
pub struct AstNode {
    pub kind: AstKind,
    pub children: Vec<AstNode>,
    // Add fields as required for real AST
}

impl From<crate::ast::Expr> for AstNode {
    fn from(expr: crate::ast::Expr) -> Self {
        let kind = expr_to_astkind(&expr);
        AstNode { kind, children: vec![] }
    }
}

/// Execution context holding scope and environment information.
pub struct ExecutionContext {
    // Add fields for variable scope, environment, etc.
    pub logic_engine: crate::logic_engine::LogicEngine,
    pub query_results: Vec<Vec<(String, String)>>,
    pub last_print: Option<String>,
    pub object_store: ObjectStore,
    pub goals: Vec<(String, Vec<String>)>,
    pub contracts: std::collections::HashMap<String, Vec<String>>, // method_key -> arg types
    pub type_infer: TypeInferenceRegistry,
    // Registered user-defined functions: name -> (params, body)
    pub functions: HashMap<String, (Vec<String>, Vec<crate::ast::Stmt>)>,
    // Lexical scopes stack: each scope is name -> string value
    pub scopes: Vec<HashMap<String, String>>,
    // Simple list values: name -> Vec<String>
    pub lists: HashMap<String, Vec<String>>,
    // Stored closures: id -> (params, body nodes)
    pub closures: HashMap<String, (Vec<String>, Vec<AstNode>)>,
    // Simple counters for generating ids per class/type
    pub counters: HashMap<String, usize>,
    // Event handlers registry: event name -> list of handler bodies (as AST nodes)
    pub event_handlers: HashMap<String, Vec<Vec<AstNode>>>,
}

impl ExecutionContext {
    /// Create a new execution context.
    pub fn new() -> Self {
        ExecutionContext {
            // Initialize fields
            logic_engine: crate::logic_engine::LogicEngine::new(),
            query_results: Vec::new(),
            last_print: None,
            object_store: ObjectStore::new(),
            goals: Vec::new(),
            contracts: std::collections::HashMap::new(),
            type_infer: TypeInferenceRegistry::new(),
            functions: HashMap::new(),
            scopes: vec![HashMap::new()], // root scope
            lists: HashMap::new(),
            closures: HashMap::new(),
            counters: HashMap::new(),
            event_handlers: HashMap::new(),
        }
    }

    // --- Lexical scope helpers ---
    pub fn push_scope(&mut self) {
        self.scopes.push(HashMap::new());
    }
    pub fn pop_scope(&mut self) {
        if self.scopes.len() > 1 { self.scopes.pop(); }
    }
    pub fn set_var(&mut self, key: &str, val: String) {
        if let Some(top) = self.scopes.last_mut() {
            top.insert(key.to_string(), val);
        }
    }
    pub fn get_var(&self, key: &str) -> Option<String> {
        for scope in self.scopes.iter().rev() {
            if let Some(v) = scope.get(key) { return Some(v.clone()); }
        }
        None
    }
}

/// Core Evaluator responsible for traversing and executing AST nodes.
pub struct CoreEvaluator<'a> {
    pub context: ExecutionContext,
    pub event_listener: Option<&'a dyn EventListener>,
    pub message_consumer: Option<&'a dyn MessageConsumer>,
    pub error_handler: Option<&'a dyn ErrorHandler>,
    pub security_policy: Option<&'a dyn SecurityPolicy>,
    pub distributed_protocol: Option<&'a dyn DistributedProtocol>,
}

impl<'a> CoreEvaluator<'a> {
    /// Create a new CoreEvaluator with optional integrations.
    pub fn new(
        event_listener: Option<&'a dyn EventListener>,
        message_consumer: Option<&'a dyn MessageConsumer>,
        error_handler: Option<&'a dyn ErrorHandler>,
        security_policy: Option<&'a dyn SecurityPolicy>,
        distributed_protocol: Option<&'a dyn DistributedProtocol>,
    ) -> Self {
        CoreEvaluator {
            context: ExecutionContext::new(),
            event_listener,
            message_consumer,
            error_handler,
            security_policy,
            distributed_protocol,
        }
    }

    /// Traverse the AST and delegate execution.
    pub fn traverse_and_execute(&mut self, node: &AstNode) -> Result<String, RuntimeError> {
        // Example event integration
        if let Some(listener) = self.event_listener {
            let event = Event { event_type: "...".to_string(), payload: "...".to_string() };
            listener.on_event(&event);
        }

        // Example security integration
        if let Some(policy) = self.security_policy {
            // policy.enforce(&self.context, node); // Uncomment when implemented
        }

        // Basic traversal logic (stub)
        self.execute_node(node)
    }

    /// Execute a single AST node (stub).
    pub fn execute_node(&mut self, node: &AstNode) -> Result<String, RuntimeError> {
        
        use crate::string::eval_string;

        // Optional debug logging
        if std::env::var("PATLANG_DEBUG").is_ok() {
            println!("[DEBUG] Evaluating node: {:?}", node.kind);
        }

        match &node.kind {
            AstKind::Number(n) => {
                Ok(n.to_string())
            }
            AstKind::String(s) => {
                // Interpolate #{var} and #{a.b} using current context
                let mut out = String::new();
                let mut i = 0usize;
                let bytes = s.as_bytes();
                while i < bytes.len() {
                    if i + 2 < bytes.len() && bytes[i] as char == '#' && bytes[i+1] as char == '{' {
                        i += 2; let start = i;
                        while i < bytes.len() && bytes[i] as char != '}' { i += 1; }
                        let key = &s[start..i];
                        let val = self.resolve_identifier_value(key);
                        out.push_str(&val);
                        if i < bytes.len() && bytes[i] as char == '}' { i += 1; }
                    } else {
                        out.push(bytes[i] as char); i += 1;
                    }
                }
                Ok(out)
            }
            AstKind::Identifier(id) if id == "true" => {
                Ok("true".to_string())
            }
            AstKind::Identifier(id) if id == "false" => {
                Ok("false".to_string())
            }
            AstKind::Identifier(id) if id.starts_with("unary:not") => {
                // crude unary not handler for debugging
                if id.contains("true") {
                    Ok("false".to_string())
                } else if id.contains("false") {
                    Ok("true".to_string())
                } else {
                    Ok(format!("not({})", id))
                }
            }
            AstKind::Identifier(id) => {
                Ok(self.resolve_identifier_value(id))
            }
            AstKind::List(items) => {
                // Evaluate items to strings and return a synthetic list id stored in context
                let mut vals: Vec<String> = Vec::new();
                for it in items { vals.push(self.execute_node(it)?); }
                let list_id = format!("__list_{}", self.context.lists.len()+1);
                self.context.lists.insert(list_id.clone(), vals);
                Ok(list_id)
            }
            AstKind::Closure { params, body } => {
                // Store closure in context and return its id
                let idx = self.context.counters.entry("closure".into()).and_modify(|c| *c += 1).or_insert(1usize);
                let closure_id = format!("__closure_{}", *idx);
                self.context.closures.insert(closure_id.clone(), (params.clone(), body.clone()));
                Ok(closure_id)
            }
            AstKind::Print(expr) => {
                // Evaluate the expression and return its string representation
                let val = self.execute_node(expr)?;
                if std::env::var("PATLANG_DEBUG").is_ok() {
                    println!("[DEBUG][evaluator] Print node evaluated to: {:?}", val);
                    println!("[DEBUG][evaluator] Print node inner AST: {:?}", expr.kind);
                }
                // Track last print in context
                self.context.last_print = Some(val.clone());
                Ok(val)
            }
            AstKind::FunctionCall { name, args } => {
                // Evaluate args once
                let mut eval_args: Vec<String> = Vec::with_capacity(args.len());
                for a in args { eval_args.push(self.execute_node(a)?); }
                // Special-case: emit(event_name[, payload]) triggers registered when-handlers
                if name == "emit" {
                    if let Some(ev) = eval_args.get(0) {
                        let payload = eval_args.get(1).cloned();
                        return self.emit_event(ev, payload);
                    } else {
                        return Ok(String::new());
                    }
                }
                // Enforce contracts if present (best-effort)
                if !self.check_contract_with_values(name, &eval_args)? {
                    return Ok(String::new());
                }
                // Call user-defined function by name if present
                if let Some((params, body_stmts)) = self.context.functions.get(name).cloned() {
                    self.context.push_scope();
                    for (i, p) in params.iter().enumerate() {
                        if let Some(v) = eval_args.get(i) { self.context.set_var(p, v.clone()); }
                    }
                    let mut last = String::new();
                    for s in &body_stmts {
                        let n = stmt_to_astnode(s);
                        last = self.execute_node(&n)?;
                    }
                    self.context.pop_scope();
                    return Ok(last);
                }
                // If function name refers to a stored closure id, execute the closure body with bindings
                if let Some((params, body)) = self.context.closures.get(name).cloned() {
                    // Execute in a new lexical scope
                    self.context.push_scope();
                    for (i, p) in params.iter().enumerate() {
                        if let Some(v) = eval_args.get(i) { self.context.set_var(p, v.clone()); }
                    }
                    let mut last = String::new();
                    for n in body {
                        last = self.execute_node(&n)?;
                    }
                    self.context.pop_scope();
                    return Ok(last);
                }
                // Delegate to built-ins
                if let Some(res) = builtins::handle_function(&mut self.context, name, &eval_args) {
                    return res;
                }
                // Support calling closures and functions via pipeline lowering in expr_to_astkind
                // Attempt OO-style chained member dispatch: a.b.c(...)
                if name.contains('.') {
                    let parts: Vec<&str> = name.split('.').collect();
                    let mut receiver = self.context.get_var(parts[0]).unwrap_or_else(|| parts[0].to_string());
                    // Traverse intermediate links by attempting zero-arg method call; fallback to property get
                    for prop in &parts[1..parts.len()-1] {
                        if self.context.lists.contains_key(&receiver) { break; }
                        if let Some(res) = builtins::handle_method(&mut self.context, &receiver, prop, &[]) {
                            // Use result as new receiver id/value
                            receiver = res.ok().unwrap_or_default();
                        } else {
                            // fallback to property get
                            if let Some(val) = self.context.object_store.get(&receiver, prop) { receiver = val; }
                        }
                    }
                    let method = parts.last().unwrap().to_string();
            // Special-case list.each(closure) with proper closure execution in current evaluator
                    if method == "each" && self.context.lists.contains_key(&receiver) && !eval_args.is_empty() {
                        let closure_id = &eval_args[0];
                        if let Some((params, body)) = self.context.closures.get(closure_id).cloned() {
                            let param_name = params.get(0).cloned();
                            let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                            let mut last = String::new();
                            for item in items {
                                self.context.push_scope();
                                if let Some(p) = &param_name { self.context.set_var(p, item); }
                                for n in &body { last = self.execute_node(n)?; }
                                self.context.pop_scope();
                            }
                return Ok(last);
                        }
                    }
                    // Functional list methods handled here so closures run with lexical scoping
                    if self.context.lists.contains_key(&receiver) {
                        match method.as_str() {
                            "map" => {
                                if eval_args.len() != 1 { return Ok(receiver); }
                                let closure_id = &eval_args[0];
                                let mut out: Vec<String> = Vec::new();
                                let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                                for item in items {
                                    let res = self.run_closure(closure_id, vec![item.clone()])?;
                                    out.push(if res.is_empty() { item } else { res });
                                }
                                let id = format!("__list_{}", self.context.lists.len()+1);
                                self.context.lists.insert(id.clone(), out);
                                return Ok(id);
                            }
                            "filter" => {
                                if eval_args.len() != 1 { return Ok(receiver); }
                                let closure_id = &eval_args[0];
                                let mut out: Vec<String> = Vec::new();
                                let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                                for item in items {
                                    let res = self.run_closure(closure_id, vec![item.clone()])?;
                                    let keep = !res.is_empty() && res != "false" && res != "0";
                                    if keep { out.push(item); }
                                }
                                let id = format!("__list_{}", self.context.lists.len()+1);
                                self.context.lists.insert(id.clone(), out);
                                return Ok(id);
                            }
                            "reduce" => {
                                if eval_args.len() != 2 { return Ok(String::new()); }
                                let mut acc = eval_args[0].clone();
                                let closure_id = &eval_args[1];
                                let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                                for item in items {
                                    let res = self.run_closure(closure_id, vec![acc.clone(), item.clone()])?;
                                    if !res.is_empty() { acc = res; }
                                }
                                return Ok(acc);
                            }
                            "unique_by" => {
                                if eval_args.len() != 1 { return Ok(receiver); }
                                let closure_id = &eval_args[0];
                                let mut seen = std::collections::HashSet::new();
                                let mut out: Vec<String> = Vec::new();
                                let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                                for item in items {
                                    let key = self.run_closure(closure_id, vec![item.clone()])?;
                                    if seen.insert(key) { out.push(item); }
                                }
                                let id = format!("__list_{}", self.context.lists.len()+1);
                                self.context.lists.insert(id.clone(), out);
                                return Ok(id);
                            }
                            "any?" => {
                                if eval_args.len() != 1 { return Ok("false".into()); }
                                let closure_id = &eval_args[0];
                                let items = self.context.lists.get(&receiver).cloned().unwrap_or_default();
                                for item in items {
                                    let res = self.run_closure(closure_id, vec![item.clone()])?;
                                    if !res.is_empty() && res != "false" && res != "0" { return Ok("true".into()); }
                                }
                                return Ok("false".into());
                            }
                            "parallel_collect" => {
                                return Ok(receiver);
                            }
                            _ => {}
                        }
                    }
                    if let Some(res) = builtins::handle_method(&mut self.context, &receiver, &method, &eval_args) { return res; }
                    // Final fallback: try as free function
                    if let Some((_params, body)) = self.context.functions.get(&method).cloned() {
                        let mut body_nodes: Vec<AstNode> = Vec::new();
                        for s in &body { body_nodes.push(stmt_to_astnode(s)); }
                        let body_block = AstNode { kind: AstKind::Block(body_nodes), children: vec![] };
                        return self.execute_node(&body_block);
                    }
                    return Ok(String::new());
                } else {
                    // User-defined function call?
                    if let Some((_params, body)) = self.context.functions.get(name).cloned() {
                        let mut body_nodes: Vec<AstNode> = Vec::new();
                        for s in &body { body_nodes.push(stmt_to_astnode(s)); }
                        let body_block = AstNode { kind: AstKind::Block(body_nodes), children: vec![] };
                        self.execute_node(&body_block)
                    } else {
                        // Unknown function: no-op
                        Ok(String::new())
                    }
                }
            }
            AstKind::Pipeline { input, func } => {
                // Evaluate input first
                let input_val = self.execute_node(input)?;
                // func may be identifier of method or closure id
                match &func.kind {
                    AstKind::Identifier(fname) => {
                        // Call fname(input_val)
                        let arg_node = AstNode { kind: AstKind::String(input_val), children: vec![] };
                        let call = AstKind::FunctionCall { name: fname.clone(), args: vec![arg_node] };
                        self.execute_node(&AstNode { kind: call, children: vec![] })
                    }
                    AstKind::String(s) => {
                        // Treat as function name as well
                        let arg_node = AstNode { kind: AstKind::String(input_val), children: vec![] };
                        let call = AstKind::FunctionCall { name: s.clone(), args: vec![arg_node] };
                        self.execute_node(&AstNode { kind: call, children: vec![] })
                    }
                    _ => Ok(input_val),
                }
            }
            AstKind::BinaryOp { op, left, right } => {
                // Recursively evaluate left and right operands
                let left_str = self.execute_node(left)?;
                let right_str = self.execute_node(right)?;

                // Debug logs for operand values
                println!("[DEBUG][evaluator] BinaryOp left evaluated to: {:?}", left_str);
                println!("[DEBUG][evaluator] BinaryOp right evaluated to: {:?}", right_str);

                // Try to parse as f64 for arithmetic/logical/comparison
                let left_val = left_str.parse::<f64>().ok();
                let right_val = right_str.parse::<f64>().ok();

                match op {
                    crate::ast::BinaryOpKind::Arithmetic(binop) => {
                        use crate::arithmetic::{eval_arithmetic, ArithmeticOp};
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let result = match binop {
                            crate::ast::BinaryOperator::Add => eval_arithmetic(ArithmeticOp::Add, l, r),
                            crate::ast::BinaryOperator::Sub => eval_arithmetic(ArithmeticOp::Sub, l, r),
                            crate::ast::BinaryOperator::Mul => eval_arithmetic(ArithmeticOp::Mul, l, r),
                            crate::ast::BinaryOperator::Div => eval_arithmetic(ArithmeticOp::Div, l, r),
                            crate::ast::BinaryOperator::Mod => eval_arithmetic(ArithmeticOp::Mod, l, r),
                            _ => 0.0,
                        };
                        Ok(result.to_string())
                    }
                    crate::ast::BinaryOpKind::Logical(binop) => {
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let b = match binop {
                            crate::ast::BinaryOperator::And => l != 0.0 && r != 0.0,
                            crate::ast::BinaryOperator::Or => l != 0.0 || r != 0.0,
                            _ => false,
                        };
                        Ok(if b { "true".to_string() } else { "false".to_string() })
                    }
            crate::ast::BinaryOpKind::Comparison(binop) => {
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let b = match binop {
                crate::ast::BinaryOperator::Equal => left_str == right_str,
                            crate::ast::BinaryOperator::Greater => l > r,
                            crate::ast::BinaryOperator::GreaterEqual => l >= r,
                            crate::ast::BinaryOperator::Less => l < r,
                            crate::ast::BinaryOperator::LessEqual => l <= r,
                            _ => false,
                        };
                        Ok(if b { "true".to_string() } else { "false".to_string() })
                    }
                    crate::ast::BinaryOpKind::Bitwise(binop) => {
                        // This legacy string/f64 evaluator predates the
                        // bitwise operators; truncate to i64 for a
                        // best-effort result, matching this function's own
                        // existing "parse as f64" convention throughout.
                        let l = left_val.unwrap_or(0.0) as i64;
                        let r = right_val.unwrap_or(0.0) as i64;
                        let result = match binop {
                            crate::ast::BinaryOperator::BitAnd => l & r,
                            crate::ast::BinaryOperator::BitOr => l | r,
                            crate::ast::BinaryOperator::BitXor => l ^ r,
                            crate::ast::BinaryOperator::Shl => if (0..64).contains(&r) { l << r } else { 0 },
                            crate::ast::BinaryOperator::Shr => if (0..64).contains(&r) { l >> r } else { 0 },
                            _ => 0,
                        };
                        Ok(result.to_string())
                    }
                }
            }
            AstKind::StringOp { op, left, right } => {
                let left_val = if let AstKind::String(ref s) = left.kind { s } else { "" };
                let right_val = right.as_ref().and_then(|n| if let AstKind::String(ref s) = n.kind { Some(s.as_str()) } else { None });
                let result = eval_string(op.clone(), left_val, right_val);
                Ok(result)
            }
            AstKind::Block(stmts) => {
                let mut last = String::new();
                for stmt in stmts {
                    last = self.execute_node(stmt)?;
                }
                Ok(last)
            }
            AstKind::If { cond, then_branch, else_branch } => {
                let cval = self.execute_node(cond)?;
                let truthy = !cval.is_empty() && cval != "false" && cval != "0";
                let branch = if truthy { Some(then_branch) } else { else_branch.as_ref() };
                if let Some(stmts) = branch {
                    let mut last = String::new();
                    for n in stmts { last = self.execute_node(n)?; }
                    Ok(last)
                } else {
                    Ok(String::new())
                }
            }
            AstKind::While { cond, body } => {
                let mut last = String::new();
                // crude loop guard to avoid infinite loops in buggy input
                let mut iter = 0usize;
                while {
                    let cval = self.execute_node(cond)?;
                    let truthy = !cval.is_empty() && cval != "false" && cval != "0";
                    truthy && iter < 1_000_000
                } {
                    for n in body { last = self.execute_node(n)?; }
                    iter += 1;
                }
                Ok(last)
            }
            AstKind::WhenRegister { event, body } => {
                // Store handler body for the event
                self.context
                    .event_handlers
                    .entry(event.clone())
                    .or_default()
                    .push(body.clone());
                Ok(String::new())
            }
            _ => {
                // Recursively execute children
                let mut last = String::new();
                for child in &node.children {
                    last = self.execute_node(child)?;
                }
                Ok(last)
            }
        }
    }

    fn run_closure(&mut self, closure_id: &str, args: Vec<String>) -> Result<String, RuntimeError> {
        if let Some((params, body)) = self.context.closures.get(closure_id).cloned() {
            self.context.push_scope();
            for (i, p) in params.iter().enumerate() {
                if let Some(v) = args.get(i) { self.context.set_var(p, v.clone()); }
            }
            let mut last = String::new();
            for n in &body { last = self.execute_node(n)?; }
            self.context.pop_scope();
            return Ok(last);
        }
        Ok(String::new())
    }

    fn ensure_person_object(&mut self, name: &str) {
        let _ = self.context.object_store.ensure(name, "Person");
    }

    // Resolve identifiers like "name" or dotted like "obj.prop" via vars and object store.
    fn resolve_identifier_value(&mut self, id: &str) -> String {
        if let Some(v) = self.context.get_var(id) { return v; }
        if let Some((first, rest)) = id.split_once('.') {
            // Determine initial receiver: var value or object name
            let mut receiver = self.context.get_var(first).unwrap_or_else(|| first.to_string());
            let mut remainder = rest;
            while let Some((prop, more)) = remainder.split_once('.') {
                if let Some(val) = self.context.object_store.get(&receiver, prop) {
                    receiver = val;
                    remainder = more;
                } else {
                    // Cannot resolve deeper; return original id
                    return id.to_string();
                }
            }
            // Last segment
            if let Some(val) = self.context.object_store.get(&receiver, remainder) { return val; }
        }
        id.to_string()
    }

    fn check_contract(&mut self, name: &str, args: &Vec<AstNode>) -> Result<bool, RuntimeError> {
        // Build possible keys: exact name, method by object type, or plain method
        let mut keys: Vec<String> = vec![name.to_string()];
        if let Some((obj, method)) = name.rsplit_once('.') {
            if let Some(obj_type) = self.context.object_store.get(obj, "type") {
                keys.insert(0, format!("{}.{}", obj_type, method));
            }
            keys.push(method.to_string());
        }
        // Find first matching contract
        let contract = keys.iter().find_map(|k| self.context.contracts.get(k)).cloned();
        if let Some(spec) = contract {
            // Validate arg count and types
            if args.len() < spec.len() { return Ok(false); }
            for (i, expected) in spec.iter().enumerate() {
                let val = self.execute_node(&args[i])?;
                let ok = match expected.as_str() {
                    "number" => val.parse::<f64>().is_ok(),
                    "string" => true, // everything is a string value here
                    "any" => true,
                    _ => true,
                };
                if !ok { return Ok(false); }
            }
        }
        Ok(true)
    }

    fn check_contract_with_values(&mut self, name: &str, eval_args: &Vec<String>) -> Result<bool, RuntimeError> {
        let mut keys: Vec<String> = vec![name.to_string()];
        if let Some((obj, method)) = name.rsplit_once('.') {
            if let Some(obj_type) = self.context.object_store.get(obj, "type") {
                keys.insert(0, format!("{}.{}", obj_type, method));
            }
            keys.push(method.to_string());
        }
        let contract = keys.iter().find_map(|k| self.context.contracts.get(k)).cloned();
        if let Some(spec) = contract {
            if eval_args.len() < spec.len() { return Ok(false); }
            for (i, expected) in spec.iter().enumerate() {
                let val = &eval_args[i];
                let ok = match expected.as_str() {
                    "number" => val.parse::<f64>().is_ok(),
                    "string" => true,
                    "any" => true,
                    _ => true,
                };
                if !ok { return Ok(false); }
            }
        }
        Ok(true)
    }

    // Emit an event by name: run all registered handlers sequentially, binding payload.
    fn emit_event(&mut self, event: &str, payload: Option<String>) -> Result<String, RuntimeError> {
        if let Some(handlers) = self.context.event_handlers.get(event).cloned() {
            let mut last = String::new();
            for body in handlers {
                // Execute each handler body in its own lexical scope with bound variables
                self.context.push_scope();
                self.context.set_var("event_name", event.to_string());
                if let Some(p) = &payload { self.context.set_var("event_data", p.clone()); }
                for n in body {
                    last = self.execute_node(&n)?;
                }
                self.context.pop_scope();
            }
            Ok(last)
        } else {
            Ok(String::new())
        }
    }

    /// Manage context and scope (stub).
    pub fn enter_scope(&mut self) {
        // Push new scope
    }

    pub fn exit_scope(&mut self) {
        // Pop scope
    }
}

// Simple result and error types for evaluation
#[derive(Debug)]
pub struct EvalResult {
    pub message: String,
    pub query_results: Vec<Vec<(String, String)>>,
    pub objects: Vec<(String, Vec<(String, String)>)>,
    pub goals: Vec<(String, Vec<String>)>,
}

#[derive(Debug)]
pub struct EvalError {
    pub message: String,
}

/// Evaluate Patlang source code string.
/// This stub "parses" the source into a dummy AST node and evaluates it.
pub fn evaluate_patlang_source(source: &str) -> Result<EvalResult, EvalError> {
    use crate::parser::Parser;
    
    // Parse the source into statements
    let mut parser = Parser::new(source).map_err(|e| EvalError { message: format!("Parse error: {:?}", e) })?;
    if std::env::var("PATLANG_DEBUG").is_ok() {
        println!("[DEBUG] Starting parse of source:\n{}", source);
    }
    let stmts = parser.parse().map_err(|e| EvalError { message: format!("Parse error: {:?}", e) })?;
    if std::env::var("PATLANG_DEBUG").is_ok() {
        println!("[DEBUG] Parsed statements: {:#?}", stmts);
    }
    // Convert statements to a Block and evaluate with a single evaluator to retain context.
    // Also register any user-defined functions into the context.
    let mut nodes: Vec<AstNode> = Vec::new();
    let mut evaluator = CoreEvaluator::new(None, None, None, None, None);
    for stmt in &stmts {
        if let crate::ast::Stmt::Function { name, params, body } = stmt {
            evaluator.context.functions.insert(name.clone(), (params.clone(), body.clone()));
        } else {
            nodes.push(stmt_to_astnode(stmt));
        }
    }
    let program = AstNode { kind: AstKind::Block(nodes), children: vec![] };
    let exec_res = evaluator.traverse_and_execute(&program);
    if let Err(e) = exec_res.as_ref() {
        return Err(EvalError { message: format!("Evaluation failed: {}", e) });
    }
    let mut last = evaluator.context.last_print.clone().unwrap_or_default();
    if last.is_empty() {
        if let Ok(v) = exec_res { last = v; }
    }
    // Snapshot objects and goals
    let mut objects: Vec<(String, Vec<(String, String)>)> = Vec::new();
    for (name, obj) in evaluator.context.object_store.iter() {
        let mut pv: Vec<(String, String)> = obj.properties.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        pv.sort_by(|a, b| a.0.cmp(&b.0));
        objects.push((name.clone(), pv));
    }
    objects.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(EvalResult {
        message: last,
        query_results: evaluator.context.query_results.clone(),
        objects,
        goals: evaluator.context.goals.clone(),
    })
}
// Helper: Convert Stmt to AstNode (minimal stub)
fn stmt_to_astnode(stmt: &crate::ast::Stmt) -> AstNode {
    match stmt {
        crate::ast::Stmt::ExprStmt(expr) => AstNode::from(expr.clone()),
    // Recognize `let name = Class.new(...)` and convert to built-in new("Class","name")
        crate::ast::Stmt::Let { name, value, .. } => {
            if let crate::ast::Expr::Call { function, args: _ } = value {
                if let crate::ast::Expr::Member { object, property } = &**function {
                    if let crate::ast::Expr::Identifier(class_name) = &**object {
                        if property == "new" {
                            // Emit two calls: new(class_name, name) then set_var(name, name)
                            let arg1 = AstNode { kind: AstKind::String(class_name.clone()), children: vec![] };
                            let arg2 = AstNode { kind: AstKind::String(name.clone()), children: vec![] };
                            let call_new = AstNode { kind: AstKind::FunctionCall { name: "new".to_string(), args: vec![arg1, arg2] }, children: vec![] };
                            let name_node1 = AstNode { kind: AstKind::String(name.clone()), children: vec![] };
                            let name_node2 = AstNode { kind: AstKind::String(name.clone()), children: vec![] };
                            let setv = AstNode { kind: AstKind::FunctionCall { name: "set_var".to_string(), args: vec![name_node1, name_node2] }, children: vec![] };
                            return AstNode { kind: AstKind::Block(vec![call_new, setv]), children: vec![] };
                        }
                    }
                }
            }
            // Fallback: set variable to evaluated RHS string value via built-in set_var
            let name_node = AstNode { kind: AstKind::String(name.clone()), children: vec![] };
            let value_node = AstNode { kind: expr_to_astkind(value), children: vec![] };
            AstNode { kind: AstKind::FunctionCall { name: "set_var".to_string(), args: vec![name_node, value_node] }, children: vec![] }
        }
        crate::ast::Stmt::If { cond, then_branch, else_branch } => {
            let cond_node = AstNode::from(cond.clone());
            let mut then_nodes: Vec<AstNode> = Vec::new();
            for s in then_branch { then_nodes.push(stmt_to_astnode(s)); }
            let else_nodes: Option<Vec<AstNode>> = else_branch.as_ref().map(|v| v.iter().map(stmt_to_astnode).collect());
            AstNode { kind: AstKind::If { cond: Box::new(cond_node), then_branch: then_nodes, else_branch: else_nodes }, children: vec![] }
        }
        crate::ast::Stmt::MemberAssign { object, property, value } => {
            // Translate obj.prop = value into a method call: obj.set("prop", value)
            let obj_ident = match object {
                crate::ast::Expr::Identifier(s) => s.clone(),
                crate::ast::Expr::Member { object: inner_obj, property: inner_prop } => {
                    // Flatten nested member like a.b -> "a.b"
                    fn collect(e: &crate::ast::Expr, out: &mut Vec<String>) {
                        match e {
                            crate::ast::Expr::Identifier(s) => out.push(s.clone()),
                            crate::ast::Expr::Member { object, property } => {
                                collect(object, out);
                                out.push(property.clone());
                            }
                            _ => {}
                        }
                    }
                    let mut segs = Vec::new();
                    collect(&*inner_obj, &mut segs);
                    segs.push(inner_prop.clone());
                    segs.join(".")
                }
                other => format!("{:?}", other),
            };
            let fname = format!("{}.set", obj_ident);
            let prop_node = AstNode { kind: AstKind::String(property.clone()), children: vec![] };
            let value_node = AstNode { kind: expr_to_astkind(value), children: vec![] };
            AstNode { kind: AstKind::FunctionCall { name: fname, args: vec![prop_node, value_node] }, children: vec![] }
        }
        crate::ast::Stmt::While { cond, body } => {
            let cond_node = AstNode::from(cond.clone());
            let mut body_nodes: Vec<AstNode> = Vec::new();
            for s in body { body_nodes.push(stmt_to_astnode(s)); }
            AstNode { kind: AstKind::While { cond: Box::new(cond_node), body: body_nodes }, children: vec![] }
        }
        // Extend for other Stmt variants as needed
        crate::ast::Stmt::When { event, body, .. } => {
            let body_nodes: Vec<AstNode> = body.iter().map(|s| stmt_to_astnode(s)).collect();
            AstNode { kind: AstKind::WhenRegister { event: event.clone(), body: body_nodes }, children: vec![] }
        }
        _ => AstNode { kind: AstKind::Block(vec![]), children: vec![] },
    }
}

// Helper: Convert Expr to AstKind (minimal stub)
fn expr_to_astkind(expr: &crate::ast::Expr) -> AstKind {
    match expr {
        crate::ast::Expr::Number(n) => AstKind::Number(*n),
        crate::ast::Expr::String(s) => AstKind::String(s.clone()),
        crate::ast::Expr::Identifier(s) => AstKind::Identifier(s.clone()),
        crate::ast::Expr::List(items) => {
            let nodes = items.iter().map(|e| AstNode { kind: expr_to_astkind(e), children: vec![] }).collect();
            AstKind::List(nodes)
        }
        crate::ast::Expr::Closure { params, body } => {
            // Convert body stmts to nodes
            let body_nodes = body.iter().map(|s| stmt_to_astnode(s)).collect();
            AstKind::Closure { params: params.clone(), body: body_nodes }
        }
        crate::ast::Expr::Member { object, property } => {
            // For now, stringify member access as identifier-like "obj.prop"
            let obj = match expr_to_astkind(object) {
                AstKind::Identifier(id) => id,
                AstKind::String(s) => s,
                other => format!("{:?}", other),
            };
            AstKind::Identifier(format!("{}.{}", obj, property))
        }
        crate::ast::Expr::Call { function, args } => {
            if std::env::var("PATLANG_DEBUG").is_ok() {
                println!("[DEBUG] Expr::Call detected: function={:?}, args={:?}", function, args);
            }
            // Detect print calls: function is identifier "print" and one argument
            if let crate::ast::Expr::Identifier(name) = &**function {
                if std::env::var("PATLANG_DEBUG").is_ok() {
                    println!("[DEBUG] Expr::Call function identifier: {}", name);
                }
                if name == "print" && args.len() == 1 {
                    let arg_node = AstNode {
                        kind: expr_to_astkind(&args[0]),
                        children: vec![],
                    };
                    if std::env::var("PATLANG_DEBUG").is_ok() {
                        println!("[DEBUG] Matched print call, converting to AstKind::Print");
                    }
                    return AstKind::Print(Box::new(arg_node));
                }
            }
            // Generic function call: convert to AstKind::FunctionCall(name,args)
            let fname = match &**function {
                crate::ast::Expr::Identifier(n) => n.clone(),
                crate::ast::Expr::Member { object, property } => {
                    // stringify member function like obj.fn
                    let obj = match expr_to_astkind(object) {
                        AstKind::Identifier(id) => id,
                        AstKind::String(s) => s,
                        other => format!("{:?}", other),
                    };
                    format!("{}.{}", obj, property)
                }
                other => {
                    // If other is a closure literal, first convert to closure id by evaluating Closure into AstKind and returning a synthetic id
                    match other {
                        crate::ast::Expr::Closure { .. } => "<closure>".to_string(),
                        _ => "<lambda>".to_string(),
                    }
                }
            };
            let conv_args = args.iter().map(|a| AstNode { kind: expr_to_astkind(a), children: vec![] }).collect();
            AstKind::FunctionCall { name: fname, args: conv_args }
        }
        crate::ast::Expr::BinaryOp { left, op, right } => {
            let kind = crate::ast::BinaryOpKind::from_operator(op);
            AstKind::BinaryOp {
                op: kind,
                left: Box::new(AstNode { kind: expr_to_astkind(left), children: vec![] }),
                right: Box::new(AstNode { kind: expr_to_astkind(right), children: vec![] }),
            }
        }
        _ => AstKind::Block(vec![]),
    }
}

// Public API stubs for module consumers

/// Traverse and execute an AST using the core evaluator.
pub fn evaluate_ast(
    root: &AstNode,
    event_listener: Option<&dyn EventListener>,
    message_consumer: Option<&dyn MessageConsumer>,
    error_handler: Option<&dyn ErrorHandler>,
    security_policy: Option<&dyn SecurityPolicy>,
    distributed_protocol: Option<&dyn DistributedProtocol>,
) -> Result<String, RuntimeError> {
    let mut evaluator = CoreEvaluator::new(
        event_listener,
        message_consumer,
        error_handler,
        security_policy,
        distributed_protocol,
    );
    evaluator.traverse_and_execute(root)
}