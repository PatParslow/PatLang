use crate::ast::Expr;
// Core Evaluator Module
//
// Responsibilities:
// - Traverse and execute AST nodes
// - Manage execution context and scope
// - Integrate with Event System, Message Queue, Error Handler, and Secure Distributed Code Support
//
// Extensibility Points:
// - Custom AST node handlers
// - Pluggable execution strategies
// - Context/scope extensions
//
// This is a scaffold for the core evaluator logic.

use crate::event_system::{Event, EventListener};
use crate::message_queue::MessageConsumer;
use crate::error_handler::{ErrorHandler, RuntimeError};
use crate::secure_distributed_code_support::{SecurityPolicy, DistributedProtocol};

#[derive(Debug, Clone)]
pub enum AstKind {
    Number(f64),
    String(String),
    Identifier(String),
    Print(Box<AstNode>),
    BinaryOp {
        op: crate::ast::BinaryOpKind,
        left: Box<AstNode>,
        right: Box<AstNode>,
    },
    StringOp {
        op: crate::string::StringOp,
        left: Box<AstNode>,
        right: Option<Box<AstNode>>,
    },
    FunctionCall {
        name: String,
        args: Vec<AstNode>,
    },
    ObjectOp {
        class_name: String,
        // Extend as needed
    },
    ReasoningOp {
        op: crate::reasoning::ReasoningOp,
        input: Box<AstNode>,
    },
    // Add more as needed
    Block(Vec<AstNode>),
}

#[derive(Debug, Clone)]
pub struct AstNode {
    pub kind: AstKind,
    pub children: Vec<AstNode>,
    // Add fields as required for real AST
}

/// Execution context holding scope and environment information.
pub struct ExecutionContext {
    // Add fields for variable scope, environment, etc.
}

impl ExecutionContext {
    /// Create a new execution context.
    pub fn new() -> Self {
        ExecutionContext {
            // Initialize fields
        }
    }
}

/// Core Evaluator responsible for traversing and executing AST nodes.
pub struct CoreEvaluator<'a> {
    pub context: ExecutionContext,
    pub event_listener: Option<&'a dyn EventListener>,
    pub message_consumer: Option<&'a dyn MessageConsumer>,
    pub error_handler: Option<&'a dyn ErrorHandler>,
    pub security_policy: Option<&'a dyn SecurityPolicy>,
    pub distributed_protocol: Option<&'a dyn DistributedProtocol>,
}

impl<'a> CoreEvaluator<'a> {
    /// Create a new CoreEvaluator with optional integrations.
    pub fn new(
        event_listener: Option<&'a dyn EventListener>,
        message_consumer: Option<&'a dyn MessageConsumer>,
        error_handler: Option<&'a dyn ErrorHandler>,
        security_policy: Option<&'a dyn SecurityPolicy>,
        distributed_protocol: Option<&'a dyn DistributedProtocol>,
    ) -> Self {
        CoreEvaluator {
            context: ExecutionContext::new(),
            event_listener,
            message_consumer,
            error_handler,
            security_policy,
            distributed_protocol,
        }
    }

    /// Traverse the AST and delegate execution.
    pub fn traverse_and_execute(&mut self, node: &AstNode) -> Result<String, RuntimeError> {
        // Example event integration
        if let Some(listener) = self.event_listener {
            let event = Event { event_type: "...".to_string(), payload: "...".to_string() };
            listener.on_event(&event);
        }

        // Example security integration
        if let Some(policy) = self.security_policy {
            // policy.enforce(&self.context, node); // Uncomment when implemented
        }

        // Basic traversal logic (stub)
        self.execute_node(node)
    }

    /// Execute a single AST node (stub).
    pub fn execute_node(&mut self, node: &AstNode) -> Result<String, RuntimeError> {
        use crate::arithmetic::{eval_arithmetic, ArithmeticOp};
        use crate::string::{eval_string, StringOp};

        // TEMP DEBUG: Log each node as it is evaluated
        println!("[DEBUG] Evaluating node: {:?}", node.kind);

        match &node.kind {
            AstKind::Number(n) => {
                Ok(n.to_string())
            }
            AstKind::String(s) => {
                Ok(s.clone())
            }
            AstKind::Identifier(id) if id == "true" => {
                Ok("true".to_string())
            }
            AstKind::Identifier(id) if id == "false" => {
                Ok("false".to_string())
            }
            AstKind::Identifier(id) if id.starts_with("unary:not") => {
                // crude unary not handler for debugging
                if id.contains("true") {
                    Ok("false".to_string())
                } else if id.contains("false") {
                    Ok("true".to_string())
                } else {
                    Ok(format!("not({})", id))
                }
            }
            AstKind::Print(expr) => {
                // Evaluate the expression and return its string representation
                let val = self.execute_node(expr)?;
                println!("[DEBUG][evaluator] Print node evaluated to: {:?}", val);
                println!("[DEBUG][evaluator] Print node inner AST: {:?}", expr.kind);
                Ok(val)
            }
            AstKind::BinaryOp { op, left, right } => {
                // Recursively evaluate left and right operands
                let left_str = self.execute_node(left)?;
                let right_str = self.execute_node(right)?;

                // Debug logs for operand values
                println!("[DEBUG][evaluator] BinaryOp left evaluated to: {:?}", left_str);
                println!("[DEBUG][evaluator] BinaryOp right evaluated to: {:?}", right_str);

                // Try to parse as f64 for arithmetic/logical/comparison
                let left_val = left_str.parse::<f64>().ok();
                let right_val = right_str.parse::<f64>().ok();

                match op {
                    crate::ast::BinaryOpKind::Arithmetic(binop) => {
                        use crate::arithmetic::{eval_arithmetic, ArithmeticOp};
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let result = match binop {
                            crate::ast::BinaryOperator::Add => eval_arithmetic(ArithmeticOp::Add, l, r),
                            crate::ast::BinaryOperator::Sub => eval_arithmetic(ArithmeticOp::Sub, l, r),
                            crate::ast::BinaryOperator::Mul => eval_arithmetic(ArithmeticOp::Mul, l, r),
                            crate::ast::BinaryOperator::Div => eval_arithmetic(ArithmeticOp::Div, l, r),
                            crate::ast::BinaryOperator::Mod => eval_arithmetic(ArithmeticOp::Mod, l, r),
                            _ => 0.0,
                        };
                        Ok(result.to_string())
                    }
                    crate::ast::BinaryOpKind::Logical(binop) => {
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let b = match binop {
                            crate::ast::BinaryOperator::And => l != 0.0 && r != 0.0,
                            crate::ast::BinaryOperator::Or => l != 0.0 || r != 0.0,
                            _ => false,
                        };
                        Ok(if b { "true".to_string() } else { "false".to_string() })
                    }
                    crate::ast::BinaryOpKind::Comparison(binop) => {
                        let l = left_val.unwrap_or(0.0);
                        let r = right_val.unwrap_or(0.0);
                        let b = match binop {
                            crate::ast::BinaryOperator::Greater => l > r,
                            crate::ast::BinaryOperator::GreaterEqual => l >= r,
                            crate::ast::BinaryOperator::Less => l < r,
                            crate::ast::BinaryOperator::LessEqual => l <= r,
                            _ => false,
                        };
                        Ok(if b { "true".to_string() } else { "false".to_string() })
                    }
                }
            }
            AstKind::StringOp { op, left, right } => {
                let left_val = if let AstKind::String(ref s) = left.kind { s } else { "" };
                let right_val = right.as_ref().and_then(|n| if let AstKind::String(ref s) = n.kind { Some(s.as_str()) } else { None });
                let result = eval_string(op.clone(), left_val, right_val);
                Ok(result)
            }
            AstKind::Block(stmts) => {
                let mut last = String::new();
                for stmt in stmts {
                    last = self.execute_node(stmt)?;
                }
                Ok(last)
            }
            _ => {
                // Recursively execute children
                let mut last = String::new();
                for child in &node.children {
                    last = self.execute_node(child)?;
                }
                Ok(last)
            }
        }
    }

    /// Manage context and scope (stub).
    pub fn enter_scope(&mut self) {
        // Push new scope
    }

    pub fn exit_scope(&mut self) {
        // Pop scope
    }
}

// Simple result and error types for evaluation
pub struct EvalResult {
    pub message: String,
}

pub struct EvalError {
    pub message: String,
}

/// Evaluate Patlang source code string.
/// This stub "parses" the source into a dummy AST node and evaluates it.
pub fn evaluate_patlang_source(source: &str) -> Result<EvalResult, EvalError> {
    use crate::parser::Parser;
    use crate::ast::{Stmt, Expr};
    // Parse the source into statements
    let mut parser = Parser::new(source).map_err(|e| EvalError { message: format!("Parse error: {:?}", e) })?;
    let stmts = parser.parse().map_err(|e| EvalError { message: format!("Parse error: {:?}", e) })?;
    println!("[DEBUG] Parsed statements: {:#?}", stmts);
    // Only collect output for print statements
    let mut results = Vec::new();
    for stmt in &stmts {
        if let Stmt::ExprStmt(Expr::Call { function, args }) = stmt {
            println!("[DEBUG] Found ExprStmt::Call: function={:?}, args={:?}", function, args);
            if let Expr::Identifier(name) = &**function {
                println!("[DEBUG] Call function identifier: {}", name);
                if name == "print" {
                    let ast = stmt_to_astnode(stmt);
                    match evaluate_ast(&ast, None, None, None, None, None) {
                        Ok(val) => results.push(val),
                        Err(e) => return Err(EvalError { message: format!("Evaluation failed: {}", e) }),
                    }
                }
            }
        }
    }
    Ok(EvalResult {
        message: if results.is_empty() {
            String::from("")
        } else {
            results.join("\n")
        },
    })
}
// Helper: Convert Stmt to AstNode (minimal stub)
fn stmt_to_astnode(stmt: &crate::ast::Stmt) -> AstNode {
    match stmt {
        crate::ast::Stmt::ExprStmt(expr) => AstNode::from(expr.clone()),
        // Extend for other Stmt variants as needed
        _ => AstNode {
            kind: AstKind::Block(vec![]),
            children: vec![],
        },
    }
}

// Helper: Convert Expr to AstKind (minimal stub)
fn expr_to_astkind(expr: &crate::ast::Expr) -> AstKind {
    match expr {
        crate::ast::Expr::Number(n) => AstKind::Number(*n),
        crate::ast::Expr::String(s) => AstKind::String(s.clone()),
        crate::ast::Expr::Call { function, args } => {
            println!("[DEBUG] Expr::Call detected: function={:?}, args={:?}", function, args);
            // Detect print calls: function is identifier "print" and one argument
            if let crate::ast::Expr::Identifier(name) = &**function {
                println!("[DEBUG] Expr::Call function identifier: {}", name);
                if name == "print" && args.len() == 1 {
                    let arg_node = AstNode {
                        kind: expr_to_astkind(&args[0]),
                        children: vec![],
                    };
                    println!("[DEBUG] Matched print call, converting to AstKind::Print");
                    return AstKind::Print(Box::new(arg_node));
                }
            }
            AstKind::Block(vec![]) // fallback for other calls
        }
        _ => AstKind::Block(vec![]),
    }
}

// Public API stubs for module consumers

/// Traverse and execute an AST using the core evaluator.
pub fn evaluate_ast(
    root: &AstNode,
    event_listener: Option<&dyn EventListener>,
    message_consumer: Option<&dyn MessageConsumer>,
    error_handler: Option<&dyn ErrorHandler>,
    security_policy: Option<&dyn SecurityPolicy>,
    distributed_protocol: Option<&dyn DistributedProtocol>,
) -> Result<String, RuntimeError> {
    let mut evaluator = CoreEvaluator::new(
        event_listener,
        message_consumer,
        error_handler,
        security_policy,
        distributed_protocol,
    );
    evaluator.traverse_and_execute(root)
}