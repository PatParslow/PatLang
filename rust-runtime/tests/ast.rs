use patlang_runtime::ast::{Expr, Stmt, BinaryOperator};

#[test]
fn test_number_expr_equality() {
    assert_eq!(Expr::Number(42.0), Expr::Number(42.0));
}

#[test]
fn test_string_expr() {
    let expr = Expr::String("hello".to_string());
    if let Expr::String(s) = expr {
        assert_eq!(s, "hello");
    } else {
        panic!("Expected Expr::String");
    }
}

#[test]
fn test_nested_binary_op() {
    let left = Expr::Number(1.0);
    let right = Expr::Number(2.0);
    let bin = Expr::BinaryOp {
        left: Box::new(left.clone()),
        op: BinaryOperator::Add,
        right: Box::new(right.clone()),
    };
    if let Expr::BinaryOp { left: l, op, right: r } = bin {
        assert_eq!(*l, left);
        assert_eq!(*r, right);
        assert_eq!(op, BinaryOperator::Add);
    } else {
        panic!("Expected Expr::BinaryOp");
    }
}

#[test]
fn test_let_stmt() {
    let stmt = Stmt::Let {
        name: "x".to_string(),
        value: Expr::Number(5.0),
    };
    if let Stmt::Let { name, value } = stmt {
        assert_eq!(name, "x");
        assert_eq!(value, Expr::Number(5.0));
    } else {
        panic!("Expected Stmt::Let");
    }
}

#[test]
fn test_function_stmt_empty_body() {
    let stmt = Stmt::Function {
        name: "f".to_string(),
        params: vec!["a".to_string()],
        body: vec![],
    };
    if let Stmt::Function { name, params, body } = stmt {
        assert_eq!(name, "f");
        assert_eq!(params, vec!["a".to_string()]);
        assert!(body.is_empty());
    } else {
        panic!("Expected Stmt::Function");
    }
}