//! Patlang AST definitions for Rust parser

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Expr {
    // Written without a decimal point in source (`42`) — lowers to the fast
    // Value::Int path (Stage 36 numeric tower).
    Number(f64),
    // Written with a decimal point in source (`42.5`) — lowers to
    // Value::Float, standard IEEE double semantics.
    Float(f64),
    String(String),
    Identifier(String),
    // List literal: [a, b, c]
    List(Vec<Expr>),
    Member {
        object: Box<Expr>,
        property: String,
    },
    // Index expression: xs[i]
    Index {
        object: Box<Expr>,
        index: Box<Expr>,
    },
    // Closure literal: |params| { body }
    Closure {
        params: Vec<String>,
        body: Vec<Stmt>,
    },
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
    // Cooperative time-budget block: budgeted(ms[, existing]) { body } /
    // do...end. Evaluates to a tagged list, ["done", value] or
    // ["paused", fiber_id]. Lowers to a synthesized function (like a
    // closure/when-handler) run via an implicit fiber; while-loop
    // back-edges lexically inside the body get a budget check injected
    // that yields (fiber_yield) once the block's budget is exhausted.
    // `existing` (None on a first call) is a paused fiber id from a
    // previous ["paused", id] result -- passing it resumes that same
    // fiber (with a freshly refreshed deadline) instead of starting a new
    // one, which is how a caller-driven scheduling loop keeps a budgeted
    // block moving across many timeslices.
    Budgeted {
        ms: Box<Expr>,
        existing: Option<Box<Expr>>,
        body: Vec<Stmt>,
    },
    // Extend with more expression types as needed
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Stmt {
    ExprStmt(Expr),
    Let {
        name: String,
        value: Expr,
        // true when written as `NAME = value` with no `let` keyword -- a
        // reassignment of an existing binding, not a fresh declaration.
        // Legal at lowering time only if that binding was declared `mut`.
        is_reassignment: bool,
        // true when declared via `let mut NAME = value`. Irrelevant when
        // is_reassignment is true (the original declaration's mutability
        // governs whether reassignment is allowed).
        mutable: bool,
    },
    // Assignment to an object's property: obj.prop = value
    MemberAssign {
        object: Expr,
        property: String,
        value: Expr,
    },
    Function {
        name: String,
        params: Vec<String>,
        body: Vec<Stmt>,
    },
    Return(Option<Expr>),
    If {
        cond: Expr,
        then_branch: Vec<Stmt>,
        else_branch: Option<Vec<Stmt>>,
    },
    While {
        cond: Expr,
        body: Vec<Stmt>,
    },
    Fact {
        name: String,
        args: Vec<Expr>,
    },
    Query {
        name: String,
        args: Vec<Expr>,
    },
    // Event-driven handler: when <event> { body }
    When {
        event: String,
        body: Vec<Stmt>,
    },
    // Design-by-contract check: kind is "require" | "ensure" | "assert".
    // Lowers to a contract_check(func_name, kind, text, ok) host call that
    // aborts execution with a descriptive error when the condition is false.
    Assert {
        kind: String,
        expr: Expr,
    },
    // Extend with more statement types as needed
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum BinaryOperator {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    And,
    Or,
    Equal,
    NotEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    // Extend with more operators as needed
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
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
            BinaryOperator::Equal
            | BinaryOperator::NotEqual
            | BinaryOperator::Greater
            | BinaryOperator::GreaterEqual
            | BinaryOperator::Less
            | BinaryOperator::LessEqual => BinaryOpKind::Comparison(op.clone()),
        }
    }
}