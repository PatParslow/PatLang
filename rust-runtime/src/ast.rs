//! Patlang AST definitions for Rust parser

#[derive(Debug, Clone, PartialEq)]
pub enum Expr {
    Number(f64),
    String(String),
    Identifier(String),
    UnaryOp {
        op: String,
        expr: Box<Expr>,
    },
    BinaryOp {
        left: Box<Expr>,
        op: BinaryOperator,
        right: Box<Expr>,
    },
    Call {
        function: Box<Expr>,
        args: Vec<Expr>,
    },
    // Extend with more expression types as needed
}

#[derive(Debug, Clone, PartialEq)]
pub enum Stmt {
    ExprStmt(Expr),
    Let {
        name: String,
        value: Expr,
    },
    Function {
        name: String,
        params: Vec<String>,
        body: Vec<Stmt>,
    },
    Return(Option<Expr>),
    // Extend with more statement types as needed
}

#[derive(Debug, Clone, PartialEq)]
pub enum BinaryOperator {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    And,
    Or,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    // Extend with more operators as needed
}

#[derive(Debug, Clone, PartialEq)]
pub enum BinaryOpKind {
    Arithmetic(BinaryOperator),
    Logical(BinaryOperator),
    Comparison(BinaryOperator),
}

impl BinaryOpKind {
    pub fn from_operator(op: &BinaryOperator) -> Self {
        match op {
            BinaryOperator::Add
            | BinaryOperator::Sub
            | BinaryOperator::Mul
            | BinaryOperator::Div
            | BinaryOperator::Mod => BinaryOpKind::Arithmetic(op.clone()),
            BinaryOperator::And
            | BinaryOperator::Or => BinaryOpKind::Logical(op.clone()),
            BinaryOperator::Greater
            | BinaryOperator::GreaterEqual
            | BinaryOperator::Less
            | BinaryOperator::LessEqual => BinaryOpKind::Comparison(op.clone()),
        }
    }
}