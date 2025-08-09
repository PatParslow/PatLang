use crate::ast::{Expr, Stmt, BinaryOperator};
use std::collections::HashSet;
use super::types::*;

#[derive(Default)]
pub struct Lowerer {
    // minimal tracking of declared locals to avoid lowering unknown identifiers
    known_locals: HashSet<String>,
}

impl Lowerer {
    pub fn new() -> Self { Self::default() }

    pub fn lower_program_basic(&mut self, stmts: &[Stmt]) -> Program {
        let mut f = Function { name: "main".into(), ..Default::default() };
        for s in stmts {
            self.lower_stmt(s, &mut f);
        }
        // implicit return of last value on stack or Unit
        f.body.push(Instr::Return);
        let mut p = Program::default();
        p.entry = "main".into();
        p.functions.insert("main".into(), f);
        p
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
            Expr::Member { .. } => false,
            Expr::UnaryOp { expr, .. } => self.expr_is_safe(expr),
            Expr::BinaryOp { left, right, .. } => self.expr_is_safe(left) && self.expr_is_safe(right),
            Expr::Call { function, args } => {
                if let Expr::Identifier(name) = &**function {
                    self.is_allowed_host(name) && args.iter().all(|a| self.expr_is_safe(a))
                } else { false }
            }
            _ => false,
        }
    }

    fn is_allowed_host(&self, name: &str) -> bool {
        matches!(name,
            "print"|"add"|"multiply"|"subtract"|"max"|"min"|"calculate"|"calculate_result"|
            "get_value"|"process"|"validate"
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
            Expr::Member { object: _, property: _ } => {
                // Stage 0: no object support yet; push Unit to keep expression positions consistent
                f.body.push(Instr::Const(Value::Unit));
            }
            Expr::Call { function, args } => {
                // Stage 0: only support identifier calls as host calls
                if let Expr::Identifier(name) = &**function {
                    for arg in args { self.lower_expr(arg, f); }
                    f.body.push(Instr::CallHost(name.clone(), args.len()));
                } else {
                    // Unsupported callee; no-op for now
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
                self.lower_expr(left, f);
                self.lower_expr(right, f);
                let instr = match op {
                    Add => Instr::BinOp(BinOpKind::Add),
                    Sub => Instr::BinOp(BinOpKind::Sub),
                    Mul => Instr::BinOp(BinOpKind::Mul),
                    Div => Instr::BinOp(BinOpKind::Div),
                    Mod => Instr::BinOp(BinOpKind::Mod),
                    Equal => Instr::BinOp(BinOpKind::Eq),
                    Greater => Instr::BinOp(BinOpKind::Gt),
                    GreaterEqual => Instr::BinOp(BinOpKind::Ge),
                    Less => Instr::BinOp(BinOpKind::Lt),
                    LessEqual => Instr::BinOp(BinOpKind::Le),
                    And => Instr::BinOp(BinOpKind::And),
                    Or => Instr::BinOp(BinOpKind::Or),
                };
                f.body.push(instr);
            }
            _ => { /* TODO: calls, lists, etc. */ }
        }
    }
}
