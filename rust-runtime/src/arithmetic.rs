//! Arithmetic Module Stub
//! Handles arithmetic operations for the evaluator.

#[derive(Debug, Clone)]
pub enum ArithmeticOp {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
}

pub fn eval_arithmetic(op: ArithmeticOp, left: f64, right: f64) -> f64 {
    match op {
        ArithmeticOp::Add => left + right,
        ArithmeticOp::Sub => left - right,
        ArithmeticOp::Mul => left * right,
        ArithmeticOp::Div => left / right,
        ArithmeticOp::Mod => left % right,
    }
}