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
        // Source line `when` appeared on -- used only for the top-level-
        // placement check (check_when_placement in parser.rs), so a
        // nested/misplaced `when` can be reported at the right line.
        line: usize,
    },
    // Design-by-contract check: kind is "require" | "ensure" | "assert".
    // Lowers to a contract_check(func_name, kind, text, ok) host call that
    // aborts execution with a descriptive error when the condition is false.
    Assert {
        kind: String,
        expr: Expr,
    },
    // Real `rule Head(args) :- Body1, Body2.` / `rule Head(args).` (a fact:
    // empty body) declarative syntax. Sugar only -- lowers to exactly the
    // Instr sequence a hand-written `rule_add(head_pred, [args], [[pred,
    // [args]], ...])` call already produces (see lower_stmt). Body goal
    // args are ordinary Exprs (usually Expr::Identifier); the `^[A-Z]`-is-
    // a-logic-variable convention is a pure runtime string convention
    // applied at lowering time, not validated here.
    RuleDecl {
        head_pred: String,
        head_args: Vec<Expr>,
        body: Vec<(String, Vec<Expr>)>,
    },
    // `goal NAME { dep1(args), dep2(args), ... }` -- names a target state
    // as a list of fact-terms ("dependencies"). Sugar only -- lowers to a
    // single goal_def(NAME, [[pred, [args]], ...]) host call (see
    // lower_stmt). `pursue NAME` (an expression, see Expr::Call desugaring
    // in parser.rs) looks this registration up and plans against it;
    // `activate PLAN` runs the resulting plan (see lowering.rs).
    GoalDecl {
        name: String,
        deps: Vec<(String, Vec<Expr>)>,
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
    // Bitwise: operate on Value::Int only, distinct from Arithmetic since
    // they don't participate in the numeric-tower promotion rules (see
    // BinaryOpKind::Bitwise below).
    BitAnd,
    BitOr,
    BitXor,
    Shl,
    Shr,
    // Extend with more operators as needed
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum BinaryOpKind {
    Arithmetic(BinaryOperator),
    Logical(BinaryOperator),
    Comparison(BinaryOperator),
    Bitwise(BinaryOperator),
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
            BinaryOperator::BitAnd
            | BinaryOperator::BitOr
            | BinaryOperator::BitXor
            | BinaryOperator::Shl
            | BinaryOperator::Shr => BinaryOpKind::Bitwise(op.clone()),
        }
    }
}