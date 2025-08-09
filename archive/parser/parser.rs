/// Patlang Parser for Rust

use crate::lexer::{Lexer, Token, LexerError};
use crate::ast;

use ast::{Expr, Stmt};

#[derive(Debug)]
pub enum ParserError {
    UnexpectedToken(Token),
    UnexpectedEOF,
    LexerError(LexerError),
    // Extend with more error types as needed
}
#[derive(Debug)]
pub struct Parser<'a> {
    lexer: Lexer<'a>,
    current_token: Token,
}

impl<'a> Parser<'a> {
    pub fn new(input: &'a str) -> Result<Self, ParserError> {
        let mut lexer = Lexer::new(input);
        let first_token = lexer.next_token().map_err(ParserError::LexerError)?;
        Ok(Parser { lexer, current_token: first_token })
    }

    /// Helper: Returns true if the token can start a statement.
    fn is_start_of_statement(token: &Token) -> bool {
        match token {
            Token::Identifier(_) | Token::Let | Token::Fn | Token::Goal | Token::Rule => true,
            Token::Number(_) | Token::String(_) | Token::LParen => true,
            // Extend as needed for other statement starters
            _ => false,
        }
    }

    /// Peek the next token without consuming it.
    fn peek_next_token(&self) -> Result<Token, ParserError> {
        let mut lookahead = self.lexer.clone();
        lookahead.next_token().map_err(ParserError::LexerError)
    }

    pub fn parse(&mut self) -> Result<Vec<Stmt>, ParserError> {
        let mut statements = Vec::new();
        let mut statement_count = 0;
        loop {
            println!("[DEBUG][parse] Top of loop: current_token = {:?}", self.current_token);

            // Skip newlines that are not statement boundaries
            while self.current_token == Token::Newline {
                let next_token = self.peek_next_token()?;
                if Self::is_start_of_statement(&next_token) {
                    // NEWLINE is a statement boundary, advance and break to parse statement
                    self.advance()?;
                    break;
                } else if next_token == Token::EOF {
                    // Only trailing newlines remain
                    self.advance()?;
                } else {
                    // Ignore insignificant newline (e.g., inside multi-line construct)
                    self.advance()?;
                }
            }

            // After skipping, check for EOF
            if self.current_token == Token::EOF {
                println!("[DEBUG][parse] Hit EOF after skipping newlines, breaking");
                break;
            }

            // Only parse if current token is a valid statement start
            if !Self::is_start_of_statement(&self.current_token) {
                break;
            }

            // Error recovery: try to parse a statement, recover on error
            match self.parse_statement() {
                Ok(stmt) => {
                    statement_count += 1;
                    println!("[DEBUG][parse] Parsed statement #{}: {:?}", statement_count, stmt);
                    statements.push(stmt);
                }
                Err(e) => {
                    println!("[ERROR][parse] Parse error: {:?}. Entering recovery.", e);
                    // Recovery: skip tokens until a start of statement, newline, or EOF
                    loop {
                        if self.current_token == Token::EOF {
                            println!("[ERROR][parse] Recovery hit EOF, breaking.");
                            break;
                        }
                        if Self::is_start_of_statement(&self.current_token) {
                            println!("[ERROR][parse] Recovery found start of statement: {:?}", self.current_token);
                            break;
                        }
                        if self.current_token == Token::Newline {
                            // Lookahead: if next token is a statement start, break
                            let next_token = self.peek_next_token().unwrap_or(Token::EOF);
                            if Self::is_start_of_statement(&next_token) || next_token == Token::EOF {
                                self.advance().ok();
                                println!("[ERROR][parse] Recovery found newline with statement start or EOF ahead.");
                                break;
                            }
                        }
                        // Otherwise, skip this token
                        self.advance().ok();
                    }
                    // After recovery, continue loop to try next statement or break on EOF
                }
            }

            // After a statement or recovery, skip newlines that are not statement boundaries
            while self.current_token == Token::Newline {
                let next_token = self.peek_next_token()?;
                if Self::is_start_of_statement(&next_token) {
                    // NEWLINE is a statement boundary, advance and break to parse next statement
                    self.advance()?;
                    break;
                } else if next_token == Token::EOF {
                    self.advance()?;
                } else {
                    // Ignore insignificant newline
                    self.advance()?;
                }
            }

            if self.current_token == Token::EOF {
                println!("[DEBUG][parse] Hit EOF after statement, breaking (accepted as valid)");
                break;
            }
        }
        println!("[DEBUG][parse] Finished parsing. Total statements: {}", statement_count);
        Ok(statements)
    }

    fn parse_statement(&mut self) -> Result<Stmt, ParserError> {
        // Prolog-like Query: query IDENTIFIER (args...) .
        if let Token::Identifier(ref kw) = self.current_token {
            if kw == "query" {
                self.advance()?; // consume 'query'
                if let Token::Identifier(ref name) = self.current_token {
                    let pred_name = name.clone();
                    self.advance()?; // consume predicate name
                    let args = self.parse_predicate_args()?;
                    if self.current_token != Token::Dot {
                        return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                    }
                    self.advance()?; // consume '.'
                    return Ok(Stmt::Query { name: pred_name, args });
                } else {
                    return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                }
            }
        }
        // Prolog-like Fact: IDENTIFIER (args...) .
        if let Token::Identifier(ref name) = self.current_token {
            let pred_name = name.clone();
            let mut lookahead = self.lexer.clone();
            if let Ok(Token::LParen) = lookahead.next_token() {
                // Looks like a predicate fact
                self.advance()?; // consume predicate name
                let args = self.parse_predicate_args()?;
                if self.current_token != Token::Dot {
                    return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                }
                self.advance()?; // consume '.'
                return Ok(Stmt::Fact { name: pred_name, args });
            }
        }
        // Fallback to original dispatch
        match &self.current_token {
            Token::Goal => self.parse_goal_block(),
            Token::Rule => self.parse_rule_block(),
            _ => self.parse_expression_statement(),
        }
    }

    /// Parse arguments for a predicate: (arg1, arg2, ...)
    fn parse_predicate_args(&mut self) -> Result<Vec<ast::Expr>, ParserError> {
        if self.current_token != Token::LParen {
            return Err(ParserError::UnexpectedToken(self.current_token.clone()));
        }
        self.advance()?; // consume '('
        let mut args = Vec::new();
        let mut expect_arg = true;
        loop {
            // Skip newlines between arguments
            while self.current_token == Token::Newline {
                self.advance()?;
            }
            match &self.current_token {
                Token::RParen => {
                    self.advance()?; // consume ')'
                    break;
                }
                Token::Comma => {
                    self.advance()?; // consume ','
                    expect_arg = true;
                }
                Token::EOF => {
                    return Err(ParserError::UnexpectedEOF);
                }
                _ if expect_arg => {
                    let expr = self.parse_expression()?;
                    args.push(expr);
                    expect_arg = false;
                }
                _ => {
                    return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                }
            }
        }
        Ok(args)
    }
    
    // Stub implementations for goal/rule blocks
    fn parse_goal_block(&mut self) -> Result<Stmt, ParserError> {
        // For now, just consume the 'goal' token and the next identifier, then skip to next newline or EOF
        self.advance()?; // consume 'goal'
        let name = if let Token::Identifier(ref s) = self.current_token {
            s.clone()
        } else {
            return Err(ParserError::UnexpectedToken(self.current_token.clone()));
        };
        self.advance()?; // consume identifier
        // Optionally parse parameters, block, etc.
        // For now, skip to next newline or EOF
        while self.current_token != Token::EOF && self.current_token != Token::Newline {
            self.advance()?;
        }
        Ok(Stmt::ExprStmt(Expr::Identifier(format!("goal:{}", name))))
    }
    
    fn parse_rule_block(&mut self) -> Result<Stmt, ParserError> {
        // For now, just consume the 'rule' token and the next identifier, then skip to next newline or EOF
        self.advance()?; // consume 'rule'
        let name = if let Token::Identifier(ref s) = self.current_token {
            s.clone()
        } else {
            return Err(ParserError::UnexpectedToken(self.current_token.clone()));
        };
        self.advance()?; // consume identifier
        // Optionally parse parameters, block, etc.
        // For now, skip to next newline or EOF
        while self.current_token != Token::EOF && self.current_token != Token::Newline {
            self.advance()?;
        }
        Ok(Stmt::ExprStmt(Expr::Identifier(format!("rule:{}", name))))
    }

    fn parse_expression_statement(&mut self) -> Result<Stmt, ParserError> {
        let expr = self.parse_expression()?;
        // Accept EOF, Newline, or Dot as valid statement terminators after an expression or function call.
        // Always consume trailing newlines after an expression statement
        while self.current_token == Token::Newline {
            self.advance()?;
        }
        // Accept EOF as valid terminator, do not advance past EOF
        if self.current_token == Token::EOF {
            return Ok(Stmt::ExprStmt(expr));
        }
        // Accept Dot as valid terminator, advance past Dot
        if self.current_token == Token::Dot {
            self.advance()?;
            return Ok(Stmt::ExprStmt(expr));
        }
        // If after advancing, we hit EOF or Newline, do not advance again
        if self.current_token == Token::EOF || self.current_token == Token::Newline {
            return Ok(Stmt::ExprStmt(expr));
        }
        // Otherwise, advance and return
        self.advance()?;
        Ok(Stmt::ExprStmt(expr))
    }

    fn parse_expression(&mut self) -> Result<Expr, ParserError> {
        self.parse_binary_expression(0)
    }

    // Operator precedence: * / > + -
    fn get_precedence(token: &Token) -> u8 {
        match token {
            Token::Star | Token::Slash | Token::Percent => 4,
            Token::Plus | Token::Minus => 3,
            Token::Greater | Token::GreaterEqual | Token::Less | Token::LessEqual => 2,
            Token::Identifier(id) if id == "and" => 1,
            Token::Identifier(id) if id == "or" => 1,
            _ => 0,
        }
    }

    fn parse_binary_expression(&mut self, min_prec: u8) -> Result<Expr, ParserError> {
        let mut left = self.parse_primary()?;

        println!(
            "[DEBUG][parse_binary_expression] Start: min_prec = {}, left = {:?}, current_token = {:?}",
            min_prec, left, self.current_token
        );

        loop {
            // Skip newlines between binary operators unless contextually significant
            while self.current_token == Token::Newline {
                self.advance()?;
            }
            let prec = Self::get_precedence(&self.current_token);
            println!(
                "[DEBUG][parse_binary_expression] Loop: min_prec = {}, token = {:?}, prec = {}",
                min_prec, self.current_token, prec
            );
            if prec < min_prec || prec == 0 {
                println!(
                    "[DEBUG][parse_binary_expression] Breaking: prec < min_prec or prec == 0 (prec = {}, min_prec = {})",
                    prec, min_prec
                );
                break;
            }

            let op_token = self.current_token.clone();
            self.advance()?;

            // Skip newlines after operator
            while self.current_token == Token::Newline {
                self.advance()?;
            }

            println!(
                "[DEBUG][parse_binary_expression] Parsing right side: op_token = {:?}, next_token = {:?}, next_prec = {}",
                op_token, self.current_token, Self::get_precedence(&self.current_token)
            );

            let mut right = self.parse_binary_expression(prec + 1)?;

            println!(
                "[DEBUG][parse_binary_expression] Building BinaryOp: left = {:?}, op_token = {:?}, right = {:?}",
                left, op_token, right
            );

            let op = match op_token {
                Token::Plus => ast::BinaryOperator::Add,
                Token::Minus => ast::BinaryOperator::Sub,
                Token::Star => ast::BinaryOperator::Mul,
                Token::Slash => ast::BinaryOperator::Div,
                Token::Percent => ast::BinaryOperator::Mod,
                Token::Greater => ast::BinaryOperator::Greater,
                Token::GreaterEqual => ast::BinaryOperator::GreaterEqual,
                Token::Less => ast::BinaryOperator::Less,
                Token::LessEqual => ast::BinaryOperator::LessEqual,
                Token::Identifier(id) if id == "and" => ast::BinaryOperator::And,
                Token::Identifier(id) if id == "or" => ast::BinaryOperator::Or,
                _ => return Err(ParserError::UnexpectedToken(op_token)),
            };

            left = Expr::BinaryOp {
                left: Box::new(left),
                op,
                right: Box::new(right),
            };
            println!(
                "[DEBUG][parse_binary_expression] Updated left: {:?}",
                left
            );
        }

        println!(
            "[DEBUG][parse_binary_expression] Returning: {:?}",
            left
        );
        Ok(left)
    }

    fn parse_primary(&mut self) -> Result<Expr, ParserError> {
        let token = self.current_token.clone();
        match token {
            Token::Number(n) => {
                let expr = Expr::Number(n);
                self.advance()?;
                Ok(expr)
            }
            Token::String(s) => {
                let expr = Expr::String(s);
                self.advance()?;
                Ok(expr)
            }
            Token::Identifier(ref id) if id == "not" => {
                self.advance()?;
                let expr = self.parse_primary()?;
                Ok(Expr::UnaryOp {
                    op: "not".to_string(),
                    expr: Box::new(expr),
                })
            }
            Token::Identifier(ref id) => {
                // Treat "true" and "false" as boolean literals, else identifier or function call
                let ident_expr = match id.as_str() {
                    "true" => Expr::Identifier("true".to_string()),
                    "false" => Expr::Identifier("false".to_string()),
                    _ => Expr::Identifier(id.clone()),
                };
                self.advance()?;
                // Check for function call: identifier followed by '('
                if self.current_token == Token::LParen {
                    self.advance()?;
                    let mut args = Vec::new();
                    // Skip newlines before arguments
                    while self.current_token == Token::Newline {
                        self.advance()?;
                    }
                    if self.current_token != Token::RParen {
                        loop {
                            // Skip newlines between arguments
                            while self.current_token == Token::Newline {
                                self.advance()?;
                            }
                            // Parse a full expression as an argument!
                            let arg = self.parse_expression()?;
                            args.push(arg);
                            // Skip newlines after argument
                            while self.current_token == Token::Newline {
                                self.advance()?;
                            }
                            if self.current_token == Token::Comma {
                                self.advance()?;
                            } else {
                                break;
                            }
                        }
                    }
                    // Skip newlines before closing paren
                    while self.current_token == Token::Newline {
                        self.advance()?;
                    }
                    if self.current_token != Token::RParen {
                        return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                    }
                    self.advance()?;
                    println!("[DEBUG] Parsed function call: {}({:?})", id, args);
                    Ok(Expr::Call {
                        function: Box::new(ident_expr),
                        args,
                    })
                } else {
                    Ok(ident_expr)
                }
            }
            Token::LParen => {
                println!("[DEBUG][parse_primary] Found LParen, entering parenthesized expression");
                self.advance()?;
                // Skip newlines after '('
                while self.current_token == Token::Newline {
                    self.advance()?;
                }
                let expr = self.parse_expression()?;
                println!("[DEBUG][parse_primary] Parsed inner expr: {:?}", expr);
                // Skip newlines before ')'
                while self.current_token == Token::Newline {
                    self.advance()?;
                }
                if self.current_token != Token::RParen {
                    println!(
                        "[DEBUG][parse_primary] Expected RParen, found {:?}",
                        self.current_token
                    );
                    return Err(ParserError::UnexpectedToken(self.current_token.clone()));
                }
                self.advance()?;
                println!("[DEBUG][parse_primary] Closed parenthesized expression, returning {:?}", expr);
                Ok(expr)
            }
            _ => Err(ParserError::UnexpectedToken(self.current_token.clone())),
        }
    }

    fn advance(&mut self) -> Result<(), ParserError> {
        self.current_token = self.lexer.next_token().map_err(ParserError::LexerError)?;
        Ok(())
    }

    // Add more subparsers for functions, let, etc.
}

/// Conversion from parser AST to evaluator AST

use crate::core_evaluator::{AstNode, AstKind};

impl From<ast::Expr> for AstNode {
    fn from(expr: ast::Expr) -> Self {
        match expr {
            ast::Expr::Number(n) => AstNode { kind: AstKind::Number(n), children: vec![] },
            ast::Expr::String(s) => AstNode { kind: AstKind::String(s), children: vec![] },
            ast::Expr::Identifier(id) => AstNode { kind: AstKind::Identifier(id), children: vec![] },
            ast::Expr::UnaryOp { op, expr } => {
                // For now, just wrap the unary op as a string node for debugging
                AstNode {
                    kind: AstKind::Identifier(format!("unary:{}({:?})", op, expr)),
                    children: vec![],
                }
            }
            ast::Expr::BinaryOp { left, op, right } => AstNode {
                kind: AstKind::BinaryOp {
                    op: crate::ast::BinaryOpKind::from_operator(&op),
                    left: Box::new(AstNode::from(*left)),
                    right: Box::new(AstNode::from(*right)),
                },
                children: vec![],
            },
            ast::Expr::Call { function, args } => {
                // Special-case print: convert to AstKind::Print
                if let ast::Expr::Identifier(ref name) = *function {
                    if name == "print" && args.len() == 1 {
                        return AstNode {
                            kind: AstKind::Print(Box::new(AstNode::from(args.into_iter().next().unwrap()))),
                            children: vec![],
                        };
                    }
                }
                AstNode {
                    kind: AstKind::FunctionCall {
                        name: match *function {
                            ast::Expr::Identifier(id) => id,
                            _ => "<anon>".to_string(),
                        },
                        args: args.into_iter().map(AstNode::from).collect(),
                    },
                    children: vec![],
                }
            },
        }
    }
}

// Add similar conversion for ast::Stmt if needed
