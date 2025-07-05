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

    pub fn parse(&mut self) -> Result<Vec<Stmt>, ParserError> {
        let mut statements = Vec::new();
        let mut statement_count = 0;
        loop {
            println!("[DEBUG][parse] Top of loop: current_token = {:?}", self.current_token);
            // Skip all newlines before a statement
            while self.current_token == Token::Newline {
                println!("[DEBUG][parse] Skipping newline before statement");
                self.advance()?;
            }
            // If we hit EOF after skipping newlines, we're done
            if self.current_token == Token::EOF {
                println!("[DEBUG][parse] Hit EOF after skipping newlines, breaking");
                break;
            }
            // If the next token is not a valid statement start, break
            match self.current_token {
                Token::Identifier(_) | Token::Number(_) | Token::String(_) | Token::LParen => {},
                Token::EOF => {
                    println!("[DEBUG][parse] Hit EOF, breaking");
                    break;
                },
                ref t => {
                    println!("[DEBUG][parse] Unexpected token at statement start: {:?}", t);
                    break;
                }
            }
            let stmt = self.parse_statement()?;
            statement_count += 1;
            println!("[DEBUG][parse] Parsed statement #{}: {:?}", statement_count, stmt);
            statements.push(stmt);
            // Skip all newlines after a statement
            while self.current_token == Token::Newline {
                println!("[DEBUG][parse] Skipping newline after statement");
                self.advance()?;
            }
            // If we hit EOF after skipping newlines, we're done
            if self.current_token == Token::EOF {
                println!("[DEBUG][parse] Hit EOF after statement, breaking");
                break;
            }
        }
        println!("[DEBUG][parse] Finished parsing. Total statements: {}", statement_count);
        Ok(statements)
    }

    fn parse_statement(&mut self) -> Result<Stmt, ParserError> {
        // Stub: dispatch to subparsers based on current_token
        self.parse_expression_statement()
    }

    fn parse_expression_statement(&mut self) -> Result<Stmt, ParserError> {
        let expr = self.parse_expression()?;
        // Only advance if not at EOF or Newline (avoid advancing past end)
        if self.current_token != Token::EOF && self.current_token != Token::Newline {
            self.advance()?;
        }
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
                    if self.current_token != Token::RParen {
                        loop {
                            // Parse a full expression as an argument!
                            let arg = self.parse_expression()?;
                            args.push(arg);
                            if self.current_token == Token::Comma {
                                self.advance()?;
                            } else {
                                break;
                            }
                        }
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
                let expr = self.parse_expression()?;
                println!("[DEBUG][parse_primary] Parsed inner expr: {:?}", expr);
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
