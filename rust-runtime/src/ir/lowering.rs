use crate::ast::{Expr, Stmt, BinaryOperator};
use std::collections::HashSet;
use super::types::*;

#[derive(Default)]
pub struct Lowerer {
    // minimal tracking of declared locals to avoid lowering unknown identifiers
    // maps declared local name -> whether it was declared `mut` (or is a
    // function parameter, which is always reassignable). Used both to check
    // whether an identifier is safe to lower and to enforce mutability on
    // bare (non-`let`) reassignment.
    known_locals: std::collections::HashMap<String, bool>,
    // track declared function names to allow lowering calls
    known_functions: HashSet<String>,
    // name of the function currently being lowered, for contract-violation messages
    current_function: String,
    // functions synthesized from closure literals, merged into the program
    // once top-level lowering completes
    pending_closures: Vec<Function>,
    // unique naming for synthesized closure functions
    closure_counter: usize,
}

impl Lowerer {
    pub fn new() -> Self { Self::default() }

    pub fn lower_program_basic(&mut self, stmts: &[Stmt]) -> Program {
    let mut main_fn = Function { name: "main".into(), ..Default::default() };
        let mut program = Program::default();
        program.entry = "main".into();
        // Pre-pass: collect all function names so forward references and mutual
        // recursion lower to Call rather than CallHost regardless of definition order
        for s in stmts {
            if let Stmt::Function { name, .. } = s {
                self.known_functions.insert(name.clone());
            }
        }
        // First pass: lower function definitions into program
        for s in stmts {
            if let Stmt::Function { name, params, body } = s.clone() {
                let mut f = Function { name: name.clone(), params: params.clone(), ..Default::default() };
                // Lower the function body
                let mut saved_locals = std::mem::take(&mut self.known_locals);
                let saved_fname = std::mem::replace(&mut self.current_function, name.clone());
                // params are considered known locals; always reassignable
                // (Phase 1 does not require `mut` on parameters).
                self.known_locals = params.iter().map(|p| (p.clone(), true)).collect();
                for st in body {
                    self.lower_stmt(&st, &mut f);
                }
                f.body.push(Instr::Return);
                program.functions.insert(name.clone(), f);
                self.known_locals = saved_locals; // restore
                self.current_function = saved_fname;
            }
        }
    // Synthesize event handlers for when-blocks at top-level
        let mut handler_counter: usize = 0;
        for s in stmts {
            if let Stmt::When { event, body } = s {
                handler_counter += 1;
                let hname = format!("__when_{}_{}", event, handler_counter);
                // Lower body into a standalone function with params 'event_name', 'event_data'
                let mut hf = Function { name: hname.clone(), params: vec!["event_name".into(), "event_data".into()], ..Default::default() };
                // Use a fresh locals set and seed with param names so they can be referenced safely
                let saved = std::mem::take(&mut self.known_locals);
                let saved_fname = std::mem::replace(&mut self.current_function, hname.clone());
                self.known_locals.insert("event_name".into(), true);
                self.known_locals.insert("event_data".into(), true);
                for st in body { self.lower_stmt(st, &mut hf); }
                hf.body.push(Instr::Return);
                program.functions.insert(hname.clone(), hf);
                program.event_handlers.entry(event.clone()).or_default().push(hname);
                self.known_locals = saved;
                self.current_function = saved_fname;
            }
        }
        // Second pass: lower top-level statements into main
        self.current_function = "main".into();
        for s in stmts {
            if !matches!(s, Stmt::Function { .. }) {
                self.lower_stmt(s, &mut main_fn);
            }
        }
        main_fn.body.push(Instr::Return);
        program.functions.insert("main".into(), main_fn);
        for f in self.pending_closures.drain(..) {
            program.functions.insert(f.name.clone(), f);
        }
        program
    }

    fn lower_stmt(&mut self, s: &Stmt, f: &mut Function) {
        match s {
            Stmt::ExprStmt(e) => {
                if self.expr_is_safe(e) {
                    self.lower_expr(e, f);
                } else {
                    // skip unsafe expression statements (unknown identifiers / members)
                }
                // leave value on stack (caller may Return at end)
            }
            Stmt::Let { name, value, is_reassignment, mutable } => {
                self.lower_expr(value, f);
                if *is_reassignment {
                    match self.known_locals.get(name) {
                        Some(true) => { /* declared mut: reassignment is fine */ }
                        Some(false) => {
                            // Statically-known immutable reassignment: emit a
                            // contract_check that always fails at this point,
                            // rather than rejecting the whole program here --
                            // lower_program_basic is infallible today, so this
                            // is enforced as a guaranteed-fail assertion at the
                            // reassignment site instead of a hard compile error.
                            f.body.push(Instr::Const(Value::String(self.current_function.clone())));
                            f.body.push(Instr::Const(Value::String("assert".into())));
                            f.body.push(Instr::Const(Value::String(format!(
                                "cannot assign twice to immutable variable `{}` (declare it `let mut {}` to allow reassignment)",
                                name, name
                            ))));
                            f.body.push(Instr::Const(Value::Bool(false)));
                            f.body.push(Instr::CallHost("contract_check".into(), 4));
                        }
                        None => {
                            // Not seen in this function's local scope (e.g. a
                            // captured/outer-scope name this flat tracker can't
                            // see) -- fall back to the old permissive behaviour
                            // rather than false-positive on legitimate code.
                            self.known_locals.insert(name.clone(), true);
                        }
                    }
                } else {
                    // `let` / `let mut`: always allowed to introduce or shadow.
                    self.known_locals.insert(name.clone(), *mutable);
                }
                f.body.push(Instr::StoreLocal(name.clone()));
            }
            Stmt::Return(opt) => {
                if let Some(e) = opt { self.lower_expr(e, f); }
                f.body.push(Instr::Return);
            }
            Stmt::If { cond, then_branch, else_branch } => {
                self.lower_expr(cond, f);
                // JumpIfFalse to else
                let jif_idx = f.body.len();
                f.body.push(Instr::JumpIfFalse(usize::MAX)); // patch later
                // then
                for s in then_branch { self.lower_stmt(s, f); }
                // Jump over else
                let jmp_over_idx = f.body.len();
                f.body.push(Instr::Jump(usize::MAX)); // patch later
                // else target
                let else_pc = f.body.len();
                // patch JumpIfFalse
                if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = else_pc; }
                if let Some(else_branch) = else_branch {
                    for s in else_branch { self.lower_stmt(s, f); }
                }
                // patch jump over else to here
                let after_else = f.body.len();
                if let Instr::Jump(ref mut tgt) = f.body[jmp_over_idx] { *tgt = after_else; }
            }
            Stmt::While { cond, body } => {
                // loop_start:
                let loop_start = f.body.len();
                // evaluate condition
                self.lower_expr(cond, f);
                // if false -> jump to after loop
                let jif_idx = f.body.len();
                f.body.push(Instr::JumpIfFalse(usize::MAX));
                // body
                for s in body { self.lower_stmt(s, f); }
                // jump back to loop_start
                f.body.push(Instr::Jump(loop_start));
                // patch JumpIfFalse to after body
                let after = f.body.len();
                if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = after; }
            }
            Stmt::Assert { kind, expr } => {
                // contract_check(func_name, kind, condition_text, ok) — pushed in
                // that order so CallHost's arg order matches; ok is evaluated last.
                f.body.push(Instr::Const(Value::String(self.current_function.clone())));
                f.body.push(Instr::Const(Value::String(kind.clone())));
                f.body.push(Instr::Const(Value::String(expr_to_text(expr))));
                self.lower_expr(expr, f);
                f.body.push(Instr::CallHost("contract_check".into(), 4));
            }
            _ => {
                // unsupported yet: ignore safely
            }
        }
    }

    fn expr_is_safe(&self, e: &Expr) -> bool {
        match e {
            Expr::Number(_) | Expr::Float(_) | Expr::String(_) => true,
            Expr::Identifier(name) => name == "true" || name == "false" || self.known_locals.contains_key(name),
            Expr::List(items) => items.iter().all(|it| self.expr_is_safe(it)),
            // Member reads lower to len/get host calls; safe when the object expr is safe
            Expr::Member { object, .. } => self.expr_is_safe(object),
            Expr::Index { object, index } => self.expr_is_safe(object) && self.expr_is_safe(index),
            Expr::UnaryOp { expr, .. } => self.expr_is_safe(expr),
            Expr::BinaryOp { left, right, .. } => self.expr_is_safe(left) && self.expr_is_safe(right),
            Expr::Call { function, args } => {
                let callee_safe = match &**function {
                    Expr::Identifier(name) => {
                        self.is_allowed_host(name) || self.known_functions.contains(name) || self.known_locals.contains_key(name)
                    }
                    // Any other safe callee expression (e.g. an inline closure
                    // literal) dispatches through CallValue, which cannot
                    // corrupt lowering state even if the runtime value turns
                    // out not to be callable.
                    other => self.expr_is_safe(other),
                };
                callee_safe && args.iter().all(|a| self.expr_is_safe(a))
            }
            // Closure literals never fail to lower (MakeClosure is infallible)
            Expr::Closure { .. } => true,
            _ => false,
        }
    }

    fn is_allowed_host(&self, name: &str) -> bool {
        matches!(name,
            "print"|"add"|"multiply"|"subtract"|"max"|"min"|"calculate"|"calculate_result"|
            "get_value"|"process"|"validate"|"len"|"get"|"send"|"emit"|"sed"|
            "list_get"|"list_len"|"list_push"|"list_set"|"char_code"|"substr"|"chr"|"to_num"|"read_file"|"write_file"|"file_exists"|"hash_string"|"argv"|"compile_shape"|"compile_ir"|"run_ir"|"codegen_prelude"|"codegen_prelude_chunk"|"rustc_build"|
            "vec_new"|"vec_push"|"vec_set"|"vec_get"|"vec_len"|"vec_to_list"|"sb_new"|"sb_push"|"sb_str"|
            "str_intern"|"sc_len"|"sc_code"|"sc_char"|"now_ms"|"read_line"|"byte_length"|"read_file_b64"|"exec_capture"|
            "fact"|"query"|"goal"|"new"|"set_var"|"apply"|
            "tcp_listen"|"tcp_connect"|"tcp_accept"|"tcp_accept_timeout"|"sleep_ms"|"tcp_read"|"tcp_write"|"tcp_close"|
            "sqrt"|"pow"|"sin"|"cos"|"tan"|"asin"|"acos"|"atan"|"atan2"|"log"|"exp"|
            "floor"|"ceil"|"round"|"trunc"|"abs"|"numeric_kind"|"type_of"|
            "parallel_map"|"fiber_new"|"fiber_resume"|"fiber_yield"|"fiber_alive"
        )
    }

    fn lower_expr(&mut self, e: &Expr, f: &mut Function) {
        match e {
            // Whole-number literal source syntax (no decimal point) stays on
            // the fast Int path by default (Stage 36 numeric tower).
            Expr::Number(n) => f.body.push(Instr::Const(Value::Int(*n as i64))),
            Expr::Float(n) => f.body.push(Instr::Const(Value::Float(*n))),
            Expr::String(s) => f.body.push(Instr::Const(Value::String(s.clone()))),
            Expr::Identifier(name) => {
                // Treat 'true' and 'false' as boolean literals in Stage 0
                if name == "true" {
                    f.body.push(Instr::Const(Value::Bool(true)));
                } else if name == "false" {
                    f.body.push(Instr::Const(Value::Bool(false)));
                } else {
                    f.body.push(Instr::LoadLocal(name.clone()));
                }
            }
            Expr::List(items) => {
                for it in items { self.lower_expr(it, f); }
                f.body.push(Instr::BuildList(items.len()));
            }
            Expr::Member { object, property } => {
                // Map property reads to host calls: length/len -> len(obj); otherwise get(obj, "prop")
                self.lower_expr(object, f);
                if property == "length" || property == "len" {
                    f.body.push(Instr::CallHost("len".into(), 1));
                } else {
                    f.body.push(Instr::Const(Value::String(property.clone())));
                    f.body.push(Instr::CallHost("get".into(), 2));
                }
            }
            Expr::Index { object, index } => {
                // xs[i] lowers to host list_get(xs, i); also yields string char at i
                self.lower_expr(object, f);
                self.lower_expr(index, f);
                f.body.push(Instr::CallHost("list_get".into(), 2));
            }
            Expr::Call { function, args } => {
                // Identifier calls: static function, closure-valued local, or host call.
                // Member calls map to message send. Any other callee expression
                // (e.g. an inline closure literal called immediately) evaluates to
                // a closure value and dispatches through CallValue.
                match &**function {
                    Expr::Identifier(name) if self.known_functions.contains(name) => {
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::Call(name.clone(), args.len()));
                    }
                    Expr::Identifier(name) if self.known_locals.contains_key(name) => {
                        // Dynamic call through a local variable holding a closure
                        f.body.push(Instr::LoadLocal(name.clone()));
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallValue(args.len()));
                    }
                    Expr::Identifier(name) => {
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallHost(name.clone(), args.len()));
                    }
                    Expr::Member { object, property } => {
                        // send(object, "method", ...args)
                        self.lower_expr(object, f);
                        f.body.push(Instr::Const(Value::String(property.clone())));
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallHost("send".into(), 2 + args.len()));
                    }
                    other => {
                        // Arbitrary callee expression (e.g. an inline closure
                        // literal): evaluate it to a closure value, then CallValue
                        self.lower_expr(other, f);
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallValue(args.len()));
                    }
                }
            }
            Expr::Closure { params, body } => {
                self.lower_closure_literal(params, body, f);
            }
            Expr::UnaryOp { op, expr } => {
                self.lower_expr(expr, f);
                match op.as_str() {
                    "-" => f.body.push(Instr::UnOp(UnOpKind::Neg)),
                    "not" => f.body.push(Instr::UnOp(UnOpKind::Not)),
                    _ => {}
                }
            }
            Expr::BinaryOp { left, op, right } => {
                use BinaryOperator::*;
                match op {
                    And => {
                        // Short-circuit: if left is falsey -> false, else result is truthiness of right
                        self.lower_expr(left, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not)); // !left
                        let jif_idx = f.body.len();
                        f.body.push(Instr::JumpIfFalse(usize::MAX)); // if !left == false => left true -> eval right
                        // left is false path
                        f.body.push(Instr::Const(Value::Bool(false)));
                        let jmp_end_idx = f.body.len();
                        f.body.push(Instr::Jump(usize::MAX));
                        // eval right
                        let eval_right_pc = f.body.len();
                        if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = eval_right_pc; }
                        self.lower_expr(right, f);
                        // coerce to bool using double-not
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        let end_pc = f.body.len();
                        if let Instr::Jump(ref mut tgt) = f.body[jmp_end_idx] { *tgt = end_pc; }
                    }
                    Or => {
                        // Short-circuit: if left is truthy -> true, else result is truthiness of right
                        self.lower_expr(left, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not)); // !left
                        let jif_idx = f.body.len();
                        f.body.push(Instr::JumpIfFalse(usize::MAX)); // when !left == false => left true
                        // left false -> eval right
                        self.lower_expr(right, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        let jmp_end_idx = f.body.len();
                        f.body.push(Instr::Jump(usize::MAX));
                        // push true for left true case
                        let push_true_pc = f.body.len();
                        if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = push_true_pc; }
                        f.body.push(Instr::Const(Value::Bool(true)));
                        let end_pc = f.body.len();
                        if let Instr::Jump(ref mut tgt) = f.body[jmp_end_idx] { *tgt = end_pc; }
                    }
                    _ => {
                        self.lower_expr(left, f);
                        self.lower_expr(right, f);
                        let instr = match op {
                            Add => Instr::BinOp(BinOpKind::Add),
                            Sub => Instr::BinOp(BinOpKind::Sub),
                            Mul => Instr::BinOp(BinOpKind::Mul),
                            Div => Instr::BinOp(BinOpKind::Div),
                            Mod => Instr::BinOp(BinOpKind::Mod),
                            Equal => Instr::BinOp(BinOpKind::Eq),
                            NotEqual => Instr::BinOp(BinOpKind::Ne),
                            Greater => Instr::BinOp(BinOpKind::Gt),
                            GreaterEqual => Instr::BinOp(BinOpKind::Ge),
                            Less => Instr::BinOp(BinOpKind::Lt),
                            LessEqual => Instr::BinOp(BinOpKind::Le),
                            And | Or => unreachable!(),
                        };
                        f.body.push(instr);
                    }
                }
            }
            _ => { /* TODO: calls, lists, etc. */ }
        }
    }

    /// Lowers a closure literal: analyzes free variables, synthesizes a
    /// Function (params = captured names ++ the closure's own params, in
    /// that order) queued in `pending_closures`, and emits the
    /// LoadLocal.../MakeClosure sequence at the creation site in `f`.
    fn lower_closure_literal(&mut self, params: &[String], body: &[Stmt], f: &mut Function) {
        // This language has no block scoping (reassigning a local inside an
        // if/while branch is already visible after it, everywhere else in
        // this codebase) so a flat union of the closure's params and every
        // name it `let`-binds anywhere in its body is a consistent notion of
        // "bound within the closure" for deciding what must be captured.
        let mut own: HashSet<String> = params.iter().cloned().collect();
        collect_let_bound_names(body, &mut own);

        let mut referenced: Vec<String> = Vec::new();
        let mut seen: HashSet<String> = HashSet::new();
        collect_referenced_idents(body, &mut referenced, &mut seen);

        // Capture only names that are (a) free in the closure and (b) actually
        // present in the enclosing scope right now (anything else is presumably
        // a host/global function name, not a variable to snapshot).
        let captured_names: Vec<String> = referenced.into_iter()
            .filter(|n| !own.contains(n) && self.known_locals.contains_key(n))
            .collect();

        self.closure_counter += 1;
        let func_name = format!("__closure_{}", self.closure_counter);
        let mut cf = Function {
            name: func_name.clone(),
            params: captured_names.iter().cloned().chain(params.iter().cloned()).collect(),
            ..Default::default()
        };
        let saved_locals = std::mem::take(&mut self.known_locals);
        let saved_fname = std::mem::replace(&mut self.current_function, func_name.clone());
        self.known_locals = cf.params.iter().map(|p| (p.clone(), true)).collect();
        for st in body { self.lower_stmt(st, &mut cf); }
        cf.body.push(Instr::Return);
        self.known_locals = saved_locals;
        self.current_function = saved_fname;
        self.pending_closures.push(cf);

        // At the creation site, push captured values in the same order used
        // for the synthesized function's leading params, then bundle them.
        for name in &captured_names {
            f.body.push(Instr::LoadLocal(name.clone()));
        }
        f.body.push(Instr::MakeClosure(func_name, captured_names));
    }
}

fn collect_let_bound_names(stmts: &[Stmt], out: &mut HashSet<String>) {
    for s in stmts {
        match s {
            Stmt::Let { name, .. } => { out.insert(name.clone()); }
            Stmt::If { then_branch, else_branch, .. } => {
                collect_let_bound_names(then_branch, out);
                if let Some(eb) = else_branch { collect_let_bound_names(eb, out); }
            }
            Stmt::While { body, .. } => collect_let_bound_names(body, out),
            Stmt::When { body, .. } => collect_let_bound_names(body, out),
            _ => {}
        }
    }
}

fn collect_referenced_idents(stmts: &[Stmt], out: &mut Vec<String>, seen: &mut HashSet<String>) {
    for s in stmts {
        match s {
            Stmt::ExprStmt(e) => collect_ident_expr(e, out, seen),
            Stmt::Let { value, .. } => collect_ident_expr(value, out, seen),
            Stmt::MemberAssign { object, value, .. } => { collect_ident_expr(object, out, seen); collect_ident_expr(value, out, seen); }
            Stmt::Function { body, .. } => collect_referenced_idents(body, out, seen),
            Stmt::Return(opt) => { if let Some(e) = opt { collect_ident_expr(e, out, seen); } }
            Stmt::If { cond, then_branch, else_branch } => {
                collect_ident_expr(cond, out, seen);
                collect_referenced_idents(then_branch, out, seen);
                if let Some(eb) = else_branch { collect_referenced_idents(eb, out, seen); }
            }
            Stmt::While { cond, body } => { collect_ident_expr(cond, out, seen); collect_referenced_idents(body, out, seen); }
            Stmt::Fact { args, .. } | Stmt::Query { args, .. } => { for a in args { collect_ident_expr(a, out, seen); } }
            Stmt::When { body, .. } => collect_referenced_idents(body, out, seen),
            Stmt::Assert { expr, .. } => collect_ident_expr(expr, out, seen),
        }
    }
}

fn collect_ident_expr(e: &Expr, out: &mut Vec<String>, seen: &mut HashSet<String>) {
    match e {
        Expr::Identifier(name) => {
            if name != "true" && name != "false" && seen.insert(name.clone()) {
                out.push(name.clone());
            }
        }
        Expr::List(items) => for it in items { collect_ident_expr(it, out, seen); },
        Expr::Member { object, .. } => collect_ident_expr(object, out, seen),
        Expr::Index { object, index } => { collect_ident_expr(object, out, seen); collect_ident_expr(index, out, seen); }
        Expr::UnaryOp { expr, .. } => collect_ident_expr(expr, out, seen),
        Expr::BinaryOp { left, right, .. } => { collect_ident_expr(left, out, seen); collect_ident_expr(right, out, seen); }
        Expr::Call { function, args } => {
            collect_ident_expr(function, out, seen);
            for a in args { collect_ident_expr(a, out, seen); }
        }
        Expr::Closure { params, body } => {
            // A nested closure's free variables (excluding its own params) are
            // also free variables of the enclosing closure, so they propagate
            // outward and get captured at whichever scope actually has them.
            let mut inner_out = Vec::new();
            let mut inner_seen: HashSet<String> = params.iter().cloned().collect();
            collect_referenced_idents(body, &mut inner_out, &mut inner_seen);
            for n in inner_out {
                if seen.insert(n.clone()) { out.push(n); }
            }
        }
        Expr::Number(_) | Expr::Float(_) | Expr::String(_) => {}
    }
}

/// Render an expression back to readable source text, for contract-violation
/// messages ("require b != 0" should report "b != 0", not a debug dump).
pub fn expr_to_text(e: &Expr) -> String {
    match e {
        Expr::Number(n) => format!("{}", *n as i64),
        Expr::Float(n) => n.to_string(),
        Expr::String(s) => format!("\"{}\"", s),
        Expr::Identifier(name) => name.clone(),
        Expr::List(items) => format!("[{}]", items.iter().map(expr_to_text).collect::<Vec<_>>().join(", ")),
        Expr::Member { object, property } => format!("{}.{}", expr_to_text(object), property),
        Expr::Index { object, index } => format!("{}[{}]", expr_to_text(object), expr_to_text(index)),
        Expr::Closure { .. } => "<closure>".into(),
        Expr::UnaryOp { op, expr } => format!("{}{}", op, expr_to_text(expr)),
        Expr::BinaryOp { left, op, right } => {
            let sym = match op {
                BinaryOperator::Add => "+", BinaryOperator::Sub => "-",
                BinaryOperator::Mul => "*", BinaryOperator::Div => "/", BinaryOperator::Mod => "%",
                BinaryOperator::And => "and", BinaryOperator::Or => "or",
                BinaryOperator::Equal => "==", BinaryOperator::NotEqual => "!=",
                BinaryOperator::Greater => ">", BinaryOperator::GreaterEqual => ">=",
                BinaryOperator::Less => "<", BinaryOperator::LessEqual => "<=",
            };
            format!("{} {} {}", expr_to_text(left), sym, expr_to_text(right))
        }
        Expr::Call { function, args } => format!("{}({})", expr_to_text(function), args.iter().map(expr_to_text).collect::<Vec<_>>().join(", ")),
    }
}
