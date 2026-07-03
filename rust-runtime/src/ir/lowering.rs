use crate::ast::{Expr, Stmt, BinaryOperator};
use std::collections::HashSet;
use super::types::*;

#[derive(Default)]
pub struct Lowerer {
    // minimal tracking of declared locals to avoid lowering unknown identifiers
    known_locals: HashSet<String>,
    // track declared function names to allow lowering calls
    known_functions: HashSet<String>,
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
                // params are considered known locals
                self.known_locals = params.iter().cloned().collect();
                for st in body {
                    self.lower_stmt(&st, &mut f);
                }
                f.body.push(Instr::Return);
                program.functions.insert(name.clone(), f);
                self.known_locals = saved_locals; // restore
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
                self.known_locals.insert("event_name".into());
                self.known_locals.insert("event_data".into());
                for st in body { self.lower_stmt(st, &mut hf); }
                hf.body.push(Instr::Return);
                program.functions.insert(hname.clone(), hf);
                program.event_handlers.entry(event.clone()).or_default().push(hname);
                self.known_locals = saved;
            }
        }
        // Second pass: lower top-level statements into main
        for s in stmts {
            if !matches!(s, Stmt::Function { .. }) {
                self.lower_stmt(s, &mut main_fn);
            }
        }
        main_fn.body.push(Instr::Return);
        program.functions.insert("main".into(), main_fn);
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
            Stmt::Let { name, value } => {
                self.lower_expr(value, f);
                f.body.push(Instr::StoreLocal(name.clone()));
                self.known_locals.insert(name.clone());
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
            _ => {
                // unsupported yet: ignore safely
            }
        }
    }

    fn expr_is_safe(&self, e: &Expr) -> bool {
        match e {
            Expr::Number(_) | Expr::String(_) => true,
            Expr::Identifier(name) => name == "true" || name == "false" || self.known_locals.contains(name),
            Expr::List(items) => items.iter().all(|it| self.expr_is_safe(it)),
            // Member reads lower to len/get host calls; safe when the object expr is safe
            Expr::Member { object, .. } => self.expr_is_safe(object),
            Expr::Index { object, index } => self.expr_is_safe(object) && self.expr_is_safe(index),
            Expr::UnaryOp { expr, .. } => self.expr_is_safe(expr),
            Expr::BinaryOp { left, right, .. } => self.expr_is_safe(left) && self.expr_is_safe(right),
            Expr::Call { function, args } => {
                if let Expr::Identifier(name) = &**function {
                    (self.is_allowed_host(name) || self.known_functions.contains(name)) && args.iter().all(|a| self.expr_is_safe(a))
                } else { false }
            }
            _ => false,
        }
    }

    fn is_allowed_host(&self, name: &str) -> bool {
        matches!(name,
            "print"|"add"|"multiply"|"subtract"|"max"|"min"|"calculate"|"calculate_result"|
            "get_value"|"process"|"validate"|"len"|"get"|"send"|"emit"|"sed"|
            "list_get"|"list_len"|"list_push"|"char_code"|"substr"|"to_num"|"read_file"|"compile_shape"
        )
    }

    fn lower_expr(&mut self, e: &Expr, f: &mut Function) {
        match e {
            Expr::Number(n) => f.body.push(Instr::Const(Value::Number(*n))),
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
                // Identifier calls map to host calls; member calls map to message send
                match &**function {
                    Expr::Identifier(name) => {
                        for arg in args { self.lower_expr(arg, f); }
                        // If identifier refers to known local function, emit Call; otherwise host call
                        if self.known_functions.contains(name) {
                            f.body.push(Instr::Call(name.clone(), args.len()));
                        } else {
                            f.body.push(Instr::CallHost(name.clone(), args.len()));
                        }
                    }
                    Expr::Member { object, property } => {
                        // send(object, "method", ...args)
                        self.lower_expr(object, f);
                        f.body.push(Instr::Const(Value::String(property.clone())));
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallHost("send".into(), 2 + args.len()));
                    }
                    _ => {
                        // Unsupported callee; no-op for now
                    }
                }
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
}
