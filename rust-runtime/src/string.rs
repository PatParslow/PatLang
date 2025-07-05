//! String Module Stub
//! Handles string operations for the evaluator.

#[derive(Debug, Clone)]
pub enum StringOp {
    Concat,
    Length,
}

pub fn eval_string(op: StringOp, left: &str, right: Option<&str>) -> String {
    match op {
        StringOp::Concat => format!("{}{}", left, right.unwrap_or("")),
        StringOp::Length => left.len().to_string(),
    }
}