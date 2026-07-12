//! Additional tests for AST enums and functions

use patlang_runtime::ast::{Expr, Stmt, BinaryOperator, BinaryOpKind};

#[test]
fn test_expr_variants() {
    // Number
    let e = Expr::Number(42.0);
    match e {
        Expr::Number(n) => assert_eq!(n, 42.0),
        _ => panic!("Expected Expr::Number"),
    }

    // String
    let e = Expr::String("abc".to_string());
    match e {
        Expr::String(s) => assert_eq!(s, "abc"),
        _ => panic!("Expected Expr::String"),
    }

    // Identifier
    let e = Expr::Identifier("x".to_string());
    match e {
        Expr::Identifier(s) => assert_eq!(s, "x"),
        _ => panic!("Expected Expr::Identifier"),
    }

    // UnaryOp
    let e = Expr::UnaryOp {
        op: "-".to_string(),
        expr: Box::new(Expr::Number(1.0)),
    };
    match e {
        Expr::UnaryOp { op, expr } => {
            assert_eq!(op, "-");
            assert_eq!(*expr, Expr::Number(1.0));
        }
        _ => panic!("Expected Expr::UnaryOp"),
    }

    // BinaryOp
    let e = Expr::BinaryOp {
        left: Box::new(Expr::Number(1.0)),
        op: BinaryOperator::Add,
        right: Box::new(Expr::Number(2.0)),
    };
    match e {
        Expr::BinaryOp { left, op, right } => {
            assert_eq!(*left, Expr::Number(1.0));
            assert_eq!(op, BinaryOperator::Add);
            assert_eq!(*right, Expr::Number(2.0));
        }
        _ => panic!("Expected Expr::BinaryOp"),
    }

    // Call
    let e = Expr::Call {
        function: Box::new(Expr::Identifier("foo".to_string())),
        args: vec![Expr::Number(1.0), Expr::Number(2.0)],
    };
    match e {
        Expr::Call { function, args } => {
            assert_eq!(*function, Expr::Identifier("foo".to_string()));
            assert_eq!(args.len(), 2);
        }
        _ => panic!("Expected Expr::Call"),
    }
}

#[test]
fn test_stmt_variants() {
    // ExprStmt
    let s = Stmt::ExprStmt(Expr::Number(1.0));
    match s {
        Stmt::ExprStmt(Expr::Number(n)) => assert_eq!(n, 1.0),
        _ => panic!("Expected Stmt::ExprStmt"),
    }

    // Let
    let s = Stmt::Let {
        name: "x".to_string(),
        value: Expr::Number(2.0),
        is_reassignment: false,
        mutable: false,
    };
    match s {
        Stmt::Let { name, value, .. } => {
            assert_eq!(name, "x");
            assert_eq!(value, Expr::Number(2.0));
        }
        _ => panic!("Expected Stmt::Let"),
    }

    // Function
    let s = Stmt::Function {
        name: "f".to_string(),
        params: vec!["a".to_string(), "b".to_string()],
        body: vec![Stmt::ExprStmt(Expr::Number(3.0))],
    };
    match s {
        Stmt::Function { name, params, body } => {
            assert_eq!(name, "f");
            assert_eq!(params, vec!["a", "b"]);
            assert_eq!(body.len(), 1);
        }
        _ => panic!("Expected Stmt::Function"),
    }

    // Return
    let s = Stmt::Return(Some(Expr::Number(4.0)));
    match s {
        Stmt::Return(Some(Expr::Number(n))) => assert_eq!(n, 4.0),
        _ => panic!("Expected Stmt::Return"),
    }

    // Fact
    let s = Stmt::Fact {
        name: "fact".to_string(),
        args: vec![Expr::Number(5.0)],
    };
    match s {
        Stmt::Fact { name, args } => {
            assert_eq!(name, "fact");
            assert_eq!(args.len(), 1);
        }
        _ => panic!("Expected Stmt::Fact"),
    }

    // Query
    let s = Stmt::Query {
        name: "query".to_string(),
        args: vec![Expr::Number(6.0)],
    };
    match s {
        Stmt::Query { name, args } => {
            assert_eq!(name, "query");
            assert_eq!(args.len(), 1);
        }
        _ => panic!("Expected Stmt::Query"),
    }
}

#[test]
fn test_binary_operator_variants() {
    let ops = [
        BinaryOperator::Add, BinaryOperator::Sub, BinaryOperator::Mul, BinaryOperator::Div, BinaryOperator::Mod,
        BinaryOperator::And, BinaryOperator::Or, BinaryOperator::Equal, BinaryOperator::NotEqual, BinaryOperator::Greater,
        BinaryOperator::GreaterEqual, BinaryOperator::Less, BinaryOperator::LessEqual,
        BinaryOperator::BitAnd, BinaryOperator::BitOr, BinaryOperator::BitXor, BinaryOperator::Shl, BinaryOperator::Shr,
    ];
    for op in ops.iter() {
        match op {
            BinaryOperator::Add | BinaryOperator::Sub | BinaryOperator::Mul | BinaryOperator::Div | BinaryOperator::Mod |
            BinaryOperator::And | BinaryOperator::Or | BinaryOperator::Equal | BinaryOperator::NotEqual | BinaryOperator::Greater |
            BinaryOperator::GreaterEqual | BinaryOperator::Less | BinaryOperator::LessEqual |
            BinaryOperator::BitAnd | BinaryOperator::BitOr | BinaryOperator::BitXor | BinaryOperator::Shl | BinaryOperator::Shr => {}
        }
    }
}

#[test]
fn test_binary_op_kind_and_from_operator() {

    // Arithmetic
    for op in [
        BinaryOperator::Add,
        BinaryOperator::Sub,
        BinaryOperator::Mul,
        BinaryOperator::Div,
        BinaryOperator::Mod,
    ]
    .iter()
    {
        let kind = BinaryOpKind::from_operator(op);
        match kind {
            BinaryOpKind::Arithmetic(o) => assert_eq!(o, *op),
            _ => panic!("Expected Arithmetic"),
        }
    }

    // Logical
    for op in [BinaryOperator::And, BinaryOperator::Or].iter() {
        let kind = BinaryOpKind::from_operator(op);
        match kind {
            BinaryOpKind::Logical(o) => assert_eq!(o, *op),
            _ => panic!("Expected Logical"),
        }
    }

    // Comparison
    for op in [
        BinaryOperator::Equal,
        BinaryOperator::Greater,
        BinaryOperator::GreaterEqual,
        BinaryOperator::Less,
        BinaryOperator::LessEqual,
    ]
    .iter()
    {
        let kind = BinaryOpKind::from_operator(op);
        match kind {
            BinaryOpKind::Comparison(o) => assert_eq!(o, *op),
            _ => panic!("Expected Comparison"),
        }
    }
}