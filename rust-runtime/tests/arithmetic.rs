use patlang_runtime::arithmetic::{eval_arithmetic, ArithmeticOp};

#[test]
fn test_add() {
    assert_eq!(eval_arithmetic(ArithmeticOp::Add, 2.0, 3.0), 5.0);
}

#[test]
fn test_sub() {
    assert_eq!(eval_arithmetic(ArithmeticOp::Sub, 5.0, 3.0), 2.0);
}

#[test]
fn test_mul() {
    assert_eq!(eval_arithmetic(ArithmeticOp::Mul, 2.0, 3.0), 6.0);
}

#[test]
fn test_div() {
    assert_eq!(eval_arithmetic(ArithmeticOp::Div, 6.0, 3.0), 2.0);
}

#[test]
fn test_div_by_zero() {
    let result = eval_arithmetic(ArithmeticOp::Div, 1.0, 0.0);
    assert!(result.is_infinite());
}

#[test]
fn test_mod() {
    assert_eq!(eval_arithmetic(ArithmeticOp::Mod, 7.0, 4.0), 3.0);
}

#[test]
fn test_mod_by_zero() {
    let result = eval_arithmetic(ArithmeticOp::Mod, 1.0, 0.0);
    assert!(result.is_nan());
}