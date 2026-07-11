use patlang_runtime::ast::{BinaryOperator, Expr, Stmt};

#[test]
fn test_expr_json_roundtrip() {
    let expr = Expr::BinaryOp {
        left: Box::new(Expr::UnaryOp {
            op: "-".to_string(),
            expr: Box::new(Expr::Number(1.0)),
        }),
        op: BinaryOperator::Add,
        right: Box::new(Expr::Call {
            function: Box::new(Expr::Identifier("f".into())),
            args: vec![Expr::Number(2.0), Expr::String("x".into())],
        }),
    };

    let json = serde_json::to_string_pretty(&expr).expect("serialize expr");
    let de: Expr = serde_json::from_str(&json).expect("deserialize expr");
    assert_eq!(expr, de);
}

#[test]
fn test_stmt_json_roundtrip() {
    let stmt = Stmt::Function {
        name: "g".into(),
        params: vec!["a".into(), "b".into()],
        body: vec![
            Stmt::Let { name: "x".into(), value: Expr::Number(3.14), is_reassignment: false, mutable: false },
            Stmt::Return(Some(Expr::BinaryOp {
                left: Box::new(Expr::Identifier("a".into())),
                op: BinaryOperator::Mul,
                right: Box::new(Expr::Identifier("b".into())),
            })),
        ],
    };

    let json = serde_json::to_string_pretty(&stmt).expect("serialize stmt");
    let de: Stmt = serde_json::from_str(&json).expect("deserialize stmt");
    assert_eq!(stmt, de);
}
