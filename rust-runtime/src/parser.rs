//! Minimal Patlang parser (Rust)

use crate::ast::{BinaryOperator, Expr, Stmt};
use crate::lexer::{Lexer, LexerError, Token};

#[derive(Debug)]
pub enum ParserError {
    Lexer(LexerError),
    UnexpectedToken { token: Token, line: usize, hint: &'static str },
    ExpectedIdentifier { line: usize, hint: &'static str },
    ExpectedToken { expected: &'static str, line: usize, hint: &'static str },
}

#[derive(Debug)]
pub struct Parser<'a> {
    lexer: Lexer<'a>,
    curr: Token,
    peek: Token,
    line_no: usize,
}

impl<'a> Parser<'a> {
    pub fn new(input: &'a str) -> Result<Self, ParserError> {
        let mut lexer = Lexer::new(input);
        let curr = lexer.next_token().map_err(ParserError::Lexer)?;
        let peek = lexer.next_token().map_err(ParserError::Lexer)?;
        Ok(Parser { lexer, curr, peek, line_no: 1 })
    }

    fn advance(&mut self) -> Result<(), ParserError> {
        if matches!(self.curr, Token::Newline) {
            self.line_no += 1;
        }
        self.curr = std::mem::replace(&mut self.peek, Token::EOF);
        self.peek = self.lexer.next_token().map_err(ParserError::Lexer)?;
        Ok(())
    }

    fn consume_newlines(&mut self) -> Result<(), ParserError> {
        while matches!(self.curr, Token::Newline) {
            self.advance()?;
        }
        Ok(())
    }

    fn at_stmt_terminator(&self) -> bool {
        // Newlines are treated as whitespace; only semicolon is an explicit terminator.
    matches!(self.curr, Token::Semicolon | Token::EOF)
    }

    fn can_start_statement(&self) -> bool {
        match self.curr {
            Token::Let | Token::Fn | Token::If | Token::Return => true,
            Token::Identifier(_) | Token::Number(_) | Token::String(_) | Token::LParen => true, // expression stmt
            _ => false,
        }
    }

    pub fn parse(&mut self) -> Result<Vec<Stmt>, ParserError> {
        let mut stmts = Vec::new();
        // Allow leading newlines
        self.consume_newlines()?;
        while !matches!(self.curr, Token::EOF | Token::BlockEnd) {
            let stmt = self.parse_statement()?;
            stmts.push(stmt);

            // After a statement, collect separators (semicolons/newlines/periods for facts)
            let mut saw_sep = false;
            let mut saw_nl = false;
            while matches!(self.curr, Token::Semicolon | Token::Newline | Token::Dot) {
                if matches!(self.curr, Token::Semicolon) { saw_sep = true; }
                if matches!(self.curr, Token::Newline) { saw_nl = true; }
                if matches!(self.curr, Token::Dot) { saw_sep = true; }
                self.advance()?;
            }

            // If end of input or block, stop
            if matches!(self.curr, Token::EOF | Token::BlockEnd) {
                break;
            }

            // If the next token can start a statement but we didn't see any separator,
            // require either a newline or a semicolon between statements on the same line.
            if self.can_start_statement() && !saw_sep && !saw_nl {
                return Err(ParserError::ExpectedToken {
                    expected: "statement separator",
                    line: self.line_no,
                    hint: "Add ';' or a newline between statements",
                });
            }

            // Otherwise, continue; any non-statement-start here is an error (handled at next parse attempt)
        }
        Ok(stmts)
    }

    fn parse_statement(&mut self) -> Result<Stmt, ParserError> {
        match self.curr {
            Token::Let => self.parse_let(),
            Token::Fn => self.parse_function(),
            Token::Return => self.parse_return(),
            Token::If => self.parse_if(),
            // identifier assignment: name = expr (but not member assignment)
            Token::Identifier(_) if matches!(self.peek, Token::Equal) => self.parse_assignment(),
            _ => {
                // Special forms
                if let Token::Identifier(ref s0) = self.curr {
                    let curr_ident = s0.clone();
                    // Bare print: `print expr` → treat like call
                    if curr_ident == "print" {
                        // If next token is '(', let normal call parsing handle print(...)
                        if matches!(self.peek, Token::LParen) {
                            // fallthrough without consuming 'print'
                        } else {
                            // Bare form: `print expr`
                            self.advance()?; // consume 'print'
                            let arg = self.parse_expression(0)?;
                            return Ok(Stmt::ExprStmt(Expr::Call {
                                function: Box::new(Expr::Identifier("print".into())),
                                args: vec![arg],
                            }));
                        }
                    }
                    // Fact DSL: if used without parentheses (not a normal call), treat as no-op.
                    // If the next token is '(', let normal call parsing handle fact(...)
                    if curr_ident == "fact" && !matches!(self.peek, Token::LParen) {
                        // Skip rest of the line or until terminating '.'
                        while !matches!(self.curr, Token::Newline | Token::EOF) {
                            if matches!(self.curr, Token::Dot) { self.advance()?; break; }
                            self.advance()?;
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Rules: rule name(args) :- ...  → skip to line end or to '.' when not used as normal call
                    if curr_ident == "rule" && !matches!(self.peek, Token::LParen) {
                        // consume tokens until newline or '.'
                        while !matches!(self.curr, Token::Newline | Token::EOF) {
                            if matches!(self.curr, Token::Dot) { self.advance()?; break; }
                            self.advance()?;
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Goals: goal name { ... } → skip brace block if present (but preserve call form goal(...))
                    if curr_ident == "goal" && !matches!(self.peek, Token::LParen) {
                        // consume until '{' then skip block; otherwise skip rest of line
                        while !matches!(self.curr, Token::BlockStart | Token::Newline | Token::EOF) { self.advance()?; }
                        if matches!(self.curr, Token::BlockStart) { self.skip_brace_block()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Reasoning mode on/off: skip rest of line
                    if curr_ident == "reasoning" {
                        while !matches!(self.curr, Token::Newline | Token::EOF) { self.advance()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // pursue ... : skip rest of line
                    if curr_ident == "pursue" {
                        while !matches!(self.curr, Token::Newline | Token::EOF) { self.advance()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // DSL sugar: make a function called Name { ... }
                    if curr_ident == "make" {
                        if let Some(stmt) = self.parse_make_construct()? { return Ok(stmt); }
                    }
                    // DSL events: when <event> { ... } → capture as Stmt::When
                    if curr_ident == "when" {
                        self.advance()?; // consume 'when'
                        // capture a simple identifier as event name; otherwise, fallback to skip
                        let event_name = match &self.curr { Token::Identifier(s) => { let n = s.clone(); self.advance()?; n }, _ => String::new() };
                        if matches!(self.curr, Token::BlockStart) {
                            // Parse the block body using normal rules
                            self.advance()?; // '{'
                            let body = self.parse_block()?;
                            return Ok(Stmt::When { event: event_name, body });
                        } else {
                            // Fallback: skip to next block to avoid breaking flow
                            while !matches!(self.curr, Token::BlockStart | Token::EOF) { self.advance()?; }
                            if matches!(self.curr, Token::BlockStart) { self.skip_brace_block()?; }
                            return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                        }
                    }
                    // Relationship declarations: skip until trailing '.'
                    if curr_ident == "relationship" {
                        // Consume tokens until we find a Dot immediately followed by Newline,
                        // which we treat as the terminator for the relationship declaration.
                        loop {
                            match self.curr {
                                Token::EOF => break,
                                Token::Dot if matches!(self.peek, Token::Newline) => {
                                    // consume '.' and the newline
                                    self.advance()?; // '.'
                                    self.advance()?; // newline
                                    break;
                                }
                                _ => { self.advance()?; }
                            }
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Activation statements: skip rest of line
                    if curr_ident == "activate" {
                        while !matches!(self.curr, Token::Newline | Token::EOF) { self.advance()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Skip 'case ... end' constructs (Ruby-like)
                    if curr_ident == "case" {
                        self.skip_until_ident("end")?;
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Skip inline 'query ... end' blocks used in DSL examples
                    // Only when this is NOT a normal function call like query(...)
                    if curr_ident == "query" && !matches!(self.peek, Token::LParen) {
                        self.skip_until_ident("end")?;
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                }
                // Best-effort fallback: if the current token starts with our DSL words like 'make' or 'when',
                // skip ahead to the next block and consume it, treating it as a no-op block statement.
                if let Token::Identifier(ref s) = self.curr {
                    if s == "make" || s == "when" {
                        // consume tokens until a '{', then consume a block
                        while !matches!(self.curr, Token::BlockStart | Token::EOF) {
                            self.advance()?;
                        }
                        if matches!(self.curr, Token::BlockStart) {
                            // Skip raw block with brace balancing to accommodate DSL contents
                            self.skip_brace_block()?;
                        }
                        // Return an empty expr stmt to advance
                        return Ok(Stmt::ExprStmt(Expr::String("".into())));
                    }
                }
                let expr = self.parse_expression(0)?;
                // If we just parsed a Member expr and see '=', treat as member assignment
                if matches!(self.curr, Token::Equal) {
                    if let Expr::Member { object, property } = expr {
                        // consume '=' and parse value
                        self.advance()?;
                        let value = self.parse_expression(0)?;
                        return Ok(Stmt::MemberAssign { object: *object, property, value });
                    } else if let Expr::Identifier(name) = expr {
                        // fallback: simple identifier assignment
                        self.advance()?; // consume '='
                        let value = self.parse_expression(0)?;
                        return Ok(Stmt::Let { name, value });
                    } else {
                        return Err(ParserError::UnexpectedToken { token: self.curr.clone(), line: self.line_no, hint: "Unexpected token; check for missing operators or delimiters" });
                    }
                }
                Ok(Stmt::ExprStmt(expr))
            }
        }
    }

    // Parse: make a function called Name { ... }
    // Returns Some(stmt) if matched, else None (caller continues normal parsing)
    fn parse_make_construct(&mut self) -> Result<Option<Stmt>, ParserError> {
        // current is Identifier("make")
        // consume 'make'
        self.advance()?;
        // optional 'a'
        if let Token::Identifier(ref s) = self.curr { if s == "a" { self.advance()?; } }
        // expect 'function' or 'template'
        let kind_is_function = if let Token::Identifier(ref s) = self.curr { s == "function" } else { false };
        let kind_is_template = if let Token::Identifier(ref s) = self.curr { s == "template" } else { false };
        if !kind_is_function && !kind_is_template { return Ok(None); }
        self.advance()?; // past kind
        // optional 'called'
        if let Token::Identifier(ref s) = self.curr { if s == "called" { self.advance()?; } }
        // name
        let name = match &self.curr {
            Token::Identifier(s) => s.clone(),
            _ => return Ok(None),
        };
        self.advance()?;
        // Two forms supported:
        // 1) Curly form: { ... returns: { ... } }
        // 2) Inline form: takes x, y returns <expr> end
        if matches!(self.curr, Token::BlockStart) {
            if kind_is_function {
                let body = self.parse_make_function_block()?;
                return Ok(Some(Stmt::Function { name, params: vec![], body }));
            } else if kind_is_template {
                self.skip_brace_block()?;
                return Ok(Some(Stmt::ExprStmt(Expr::String(String::new()))));
            }
        } else if kind_is_function {
            // Attempt to parse inline: optional 'takes' params, then 'returns' expr, ending with 'end'
            let mut params: Vec<String> = Vec::new();
            // optional 'takes'
            if let Token::Identifier(ref s) = self.curr { if s == "takes" { self.advance()?; } }
            // parse zero or more identifiers separated by commas until we see 'returns' or 'end'
            loop {
                match &self.curr {
                    Token::Identifier(s) if s == "returns" || s == "end" => break,
                    Token::Identifier(s) => { params.push(s.clone()); self.advance()?; },
                    Token::Comma => { self.advance()?; },
                    Token::Newline => { self.advance()?; },
                    _ => break,
                }
            }
            // optional 'returns'
            let mut body: Vec<Stmt> = Vec::new();
            if let Token::Identifier(ref s) = self.curr { if s == "returns" { self.advance()?; } }
            // try to parse an expression for return until we hit 'end'
            // allow multi-line expression; stop on Identifier("end") or EOF
            if !matches!(self.curr, Token::Identifier(_)) {
                // nothing to return
            }
            // Save parser state and attempt expression parse; if it fails, skip to 'end'
            let ret_expr = self.parse_expression(0).ok();
            if let Some(expr) = ret_expr { body.push(Stmt::Return(Some(expr))); }
            // consume until 'end'
            while let Token::Identifier(ref s) = self.curr { if s == "end" { break; } else { self.advance()?; } }
            if let Token::Identifier(ref s) = self.curr { if s == "end" { self.advance()?; } }
            return Ok(Some(Stmt::Function { name, params, body }));
        } else if kind_is_template {
            // Inline template: skip to 'end'
            while let Token::Identifier(ref s) = self.curr { if s == "end" { break; } else { self.advance()?; } }
            if let Token::Identifier(ref s) = self.curr { if s == "end" { self.advance()?; } }
            return Ok(Some(Stmt::ExprStmt(Expr::String(String::new()))));
        }
        // If none matched, fall back to None
        Ok(None)
    }

    // Skip a raw balanced-brace block starting at current token which must be '{'
    fn skip_brace_block(&mut self) -> Result<(), ParserError> {
        if !matches!(self.curr, Token::BlockStart) { return Ok(()); }
        // consume the opening '{'
        self.advance()?;
        let mut depth = 1usize;
        while depth > 0 {
            match self.curr {
                Token::BlockStart => { depth += 1; self.advance()?; }
                Token::BlockEnd => { depth -= 1; self.advance()?; }
                Token::EOF => break,
                _ => { self.advance()?; }
            }
        }
        Ok(())
    }

    // Skip tokens until we encounter a specific identifier (e.g., 'end').
    fn skip_until_ident(&mut self, target: &str) -> Result<(), ParserError> {
        loop {
            match &self.curr {
                Token::Identifier(s) if s == target => { self.advance()?; break; }
                Token::BlockStart => { self.skip_brace_block()?; }
                Token::EOF => break,
                _ => { self.advance()?; }
            }
        }
        Ok(())
    }

    // Parse a function block introduced by `make a function called Name { ... }`
    // We scan until we find `returns: { ... }` and parse that inner block with normal rules.
    fn parse_make_function_block(&mut self) -> Result<Vec<Stmt>, ParserError> {
        // current must be '{'
        if !matches!(self.curr, Token::BlockStart) { return Ok(vec![]); }
        // consume '{'
        self.advance()?;
        let mut body: Option<Vec<Stmt>> = None;
        let mut depth: usize = 1;
        while depth > 0 {
            // consume newlines
            while matches!(self.curr, Token::Newline) { self.advance()?; }
            match &self.curr {
                Token::Identifier(s) if s == "returns" => {
                    // consume 'returns'
                    self.advance()?;
                    // optional ':'
                    if matches!(self.curr, Token::Colon) { self.advance()?; }
                    // expect block
                    if matches!(self.curr, Token::BlockStart) {
                        // Enter and parse a standard block as the function's body
                        self.advance()?;
                        let parsed = self.parse_block()?;
                        body = Some(parsed);
                        // continue scanning remaining of outer block
                    } else {
                        // malformed; skip token
                        self.advance()?;
                    }
                }
                Token::BlockStart => { depth += 1; self.advance()?; }
                Token::BlockEnd => { depth -= 1; self.advance()?; }
                Token::EOF => break,
                _ => { self.advance()?; }
            }
        }
        Ok(body.unwrap_or_default())
    }

    fn parse_let(&mut self) -> Result<Stmt, ParserError> {
        // consume 'let'
        self.advance()?;
        let name = match &self.curr {
            Token::Identifier(s) => s.clone(),
            _ => return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Expected variable name after 'let'" }),
        };
        self.advance()?; // name
        // expect '=' (allow newlines before '=')
        while matches!(self.curr, Token::Newline) { self.advance()?; }
        match self.curr {
            Token::Equal => self.advance()?,
            _ => return Err(ParserError::ExpectedToken { expected: "'=' after identifier", line: self.line_no, hint: "Use 'let name = value' or 'name = value'" }),
        }
        // value expression (allow multi-line continuation)
        let value = self.parse_expression(0)?;
        // optional terminator handled by caller
        Ok(Stmt::Let { name, value })
    }

    fn parse_assignment(&mut self) -> Result<Stmt, ParserError> {
        // current token is Identifier and peek is '='
    let name = if let Token::Identifier(ref s) = self.curr { s.clone() } else { return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Assignment must start with an identifier" }) };
        self.advance()?; // move past identifier
    // allow newlines before '=' like in let
    while matches!(self.curr, Token::Newline) { self.advance()?; }
    match self.curr {
            Token::Equal => self.advance()?,
            _ => return Err(ParserError::ExpectedToken { expected: "'=' after identifier", line: self.line_no, hint: "Use 'name = value'" }),
        }
        let value = self.parse_expression(0)?;
        Ok(Stmt::Let { name, value })
    }

    fn parse_function(&mut self) -> Result<Stmt, ParserError> {
        // consume 'fn'
        self.advance()?;
        let name = match &self.curr {
            Token::Identifier(s) => s.clone(),
            _ => return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Function name expected after 'fn'" }),
        };
        self.advance()?; // name
        // params
    self.expect(Token::LParen, "'(' after function name", "Define parameter list e.g. fn f(a, b)")?;
        let mut params = Vec::new();
        // allow empty param list
        while matches!(self.curr, Token::Newline) { self.advance()?; }
        if !matches!(self.curr, Token::RParen) {
            loop {
                match &self.curr {
                    Token::Identifier(s) => params.push(s.clone()),
                    _ => return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Parameter name expected" }),
                }
                self.advance()?;
                while matches!(self.curr, Token::Newline) { self.advance()?; }
                match self.curr {
                    Token::Comma => { self.advance()?; while matches!(self.curr, Token::Newline) { self.advance()?; } }
                    Token::RParen => break,
                    _ => return Err(ParserError::ExpectedToken { expected: ") or ,", line: self.line_no, hint: "Separate parameters with ',' or close with ')'" }),
                }
            }
        }
        self.expect(Token::RParen, ")' to close parameter list", "Close the parameter list with ')'" )?;
        // body
        self.expect(Token::BlockStart, "'{' to start function body", "Start the function body with '{'" )?;
        let body = self.parse_block()?;
        Ok(Stmt::Function { name, params, body })
    }

    fn parse_block(&mut self) -> Result<Vec<Stmt>, ParserError> {
        let mut body = Vec::new();
        // consume leading newlines inside block
        self.consume_newlines()?;
        while !matches!(self.curr, Token::BlockEnd | Token::EOF) {
            let stmt = self.parse_statement()?;
            body.push(stmt);

            // After a statement, collect separators (semicolons/newlines/periods)
            let mut saw_sep = false;
            let mut saw_nl = false;
            while matches!(self.curr, Token::Semicolon | Token::Newline | Token::Dot) {
                if matches!(self.curr, Token::Semicolon) { saw_sep = true; }
                if matches!(self.curr, Token::Newline) { saw_nl = true; }
                if matches!(self.curr, Token::Dot) { saw_sep = true; }
                self.advance()?;
            }

            // If end of block/input, stop
            if matches!(self.curr, Token::BlockEnd | Token::EOF) { break; }

            // If the next token can start a statement but we didn't see any separator,
            // require either a newline or a semicolon between statements on the same line.
            if self.can_start_statement() && !saw_sep && !saw_nl {
                return Err(ParserError::ExpectedToken {
                    expected: "statement separator",
                    line: self.line_no,
                    hint: "Add ';' or a newline between statements",
                });
            }
        }
        self.expect(Token::BlockEnd, "'}' to close block", "Close the block with '}'" )?;
        Ok(body)
    }

    fn parse_return(&mut self) -> Result<Stmt, ParserError> {
        // consume 'return'
        self.advance()?;
        // optional expression until terminator
        if matches!(self.curr, Token::Semicolon | Token::Newline | Token::EOF | Token::BlockEnd) {
            return Ok(Stmt::Return(None));
        }
        let expr = self.parse_expression(0)?;
        Ok(Stmt::Return(Some(expr)))
    }

    fn parse_if(&mut self) -> Result<Stmt, ParserError> {
        // consume 'if'
        self.advance()?;
        // condition expression
        let cond = self.parse_expression(0)?;
        // then block
        self.expect(Token::BlockStart, "'{' to start 'if' block", "Start the 'if' block with '{'" )?;
        let then_branch = self.parse_block()?;
        // optional else/elif
        let else_branch = if matches!(self.curr, Token::Else | Token::Elif) {
            match self.curr {
                Token::Else => {
                    self.advance()?;
                    self.expect(Token::BlockStart, "'{' to start 'else' block", "Start the 'else' block with '{'" )?;
                    Some(self.parse_block()?)
                }
                Token::Elif => {
                    // elif -> else { if ... }
                    self.advance()?;
                    let cond2 = self.parse_expression(0)?;
                    self.expect(Token::BlockStart, "'{' to start 'elif' block", "Start the 'elif' block with '{'" )?;
                    let then2 = self.parse_block()?;
                    Some(vec![Stmt::If { cond: cond2, then_branch: then2, else_branch: None }])
                }
                _ => None,
            }
        } else { None };
        Ok(Stmt::If { cond, then_branch, else_branch })
    }

    // Pratt parser
    fn parse_expression(&mut self, min_bp: u8) -> Result<Expr, ParserError> {
        // skip newlines before a primary (continuation lines)
        while matches!(self.curr, Token::Newline) { self.advance()?; }
        let mut lhs = self.parse_primary()?;
        loop {
            // If we're at a newline and the next token is an operator, treat it as continuation
            if matches!(self.curr, Token::Newline) {
                match self.peek {
                    Token::Plus | Token::Minus | Token::Star | Token::Slash | Token::Percent => {
                        self.advance()?; // consume newline and continue
                    }
                    Token::EqualEqual | Token::Greater | Token::GreaterEqual | Token::Less | Token::LessEqual => {
                        self.advance()?;
                    }
                    _ => { /* newline may separate statements; do not consume here */ }
                }
            }
            // do not skip potential statement-separating newlines here; only handle newline after operator below
            // Special-case pipeline operator to lower into a function call: rhs(lhs)
            if matches!(self.curr, Token::PipeGreater) {
                // consume '|>'
                self.advance()?;
                while matches!(self.curr, Token::Newline) { self.advance()?; }
                let rhs = self.parse_expression(2)?;
                // transform to Call { function: rhs, args: [lhs] }
                lhs = Expr::Call { function: Box::new(rhs), args: vec![lhs] };
                continue;
            }
            let (op, lbp, rbp) = match self.curr {
                Token::Plus => (BinaryOperator::Add, 10, 11),
                Token::Minus => (BinaryOperator::Sub, 10, 11),
                Token::Star => (BinaryOperator::Mul, 20, 21),
                Token::Slash => (BinaryOperator::Div, 20, 21),
                Token::Percent => (BinaryOperator::Mod, 20, 21),
                Token::EqualEqual => (BinaryOperator::Equal, 5, 6),
                Token::Greater => (BinaryOperator::Greater, 7, 8),
                Token::GreaterEqual => (BinaryOperator::GreaterEqual, 7, 8),
                Token::Less => (BinaryOperator::Less, 7, 8),
                Token::LessEqual => (BinaryOperator::LessEqual, 7, 8),
                Token::And => (BinaryOperator::And, 3, 4),
                Token::Or => (BinaryOperator::Or, 2, 3),
                _ => break,
            };
            if lbp < min_bp { break; }
            // consume op
            self.advance()?;
            // allow newline after operator
            while matches!(self.curr, Token::Newline) { self.advance()?; }
            let rhs = self.parse_expression(rbp)?;
            lhs = Expr::BinaryOp {
                left: Box::new(lhs),
                op,
                right: Box::new(rhs),
            };
        }
        Ok(lhs)
    }

    fn parse_primary(&mut self) -> Result<Expr, ParserError> {
        // parse base
        let mut expr = match &self.curr {
            Token::Not => { self.advance()?; let inner = self.parse_primary()?; Expr::UnaryOp { op: "not".into(), expr: Box::new(inner) } }
            Token::Number(n) => { let v = *n; self.advance()?; Expr::Number(v) }
            Token::String(s) => { let v = s.clone(); self.advance()?; Expr::String(v) }
            Token::Goal => { self.advance()?; Expr::Identifier("goal".to_string()) }
            Token::Rule => { self.advance()?; Expr::Identifier("rule".to_string()) }
            // Minimal closure literal: |params| { ... } -> treat as string token
                Token::Pipe => {
                    // Parse closure: |param1, param2| { ... }
                    self.advance()?; // first '|'
                    let mut params: Vec<String> = Vec::new();
                    // gather parameter list until next '|'
                    loop {
                        match &self.curr {
                            Token::Identifier(s) => { params.push(s.clone()); self.advance()?; },
                            Token::Comma => { self.advance()?; },
                            Token::Newline => { self.advance()?; },
                            Token::Pipe => { self.advance()?; break; },
                            _ => { break; }
                        }
                    }
                    // Expect body block
                    let body = if matches!(self.curr, Token::BlockStart) {
                        self.advance()?; // '{'
                        self.parse_block()?
                    } else { vec![] };
                    Expr::Closure { params, body }
                }
            // Minimal list literal: [a, b, ...]
            Token::LBracket => {
                self.advance()?; // '['
                let mut items: Vec<Expr> = Vec::new();
                // elements until ']'
                if !matches!(self.curr, Token::RBracket) {
                    loop {
                        let item = self.parse_expression(0)?;
                        items.push(item);
                        while matches!(self.curr, Token::Newline) { self.advance()?; }
                        match self.curr {
                            Token::Comma => { self.advance()?; while matches!(self.curr, Token::Newline) { self.advance()?; } }
                            Token::RBracket => break,
                            _ => break,
                        }
                    }
                }
                self.expect(Token::RBracket, "] to close list", "Close list with ']'" )?;
                Expr::List(items)
            }
            Token::Identifier(name) => { let id = name.clone(); self.advance()?; Expr::Identifier(id) }
            Token::LParen => {
                self.advance()?; // '('
                let inner = self.parse_expression(0)?;
                while matches!(self.curr, Token::Newline) { self.advance()?; }
                self.expect(Token::RParen, ")' to close grouping", "Close the grouping with ')'" )?;
                inner
            }
            t => return Err(ParserError::UnexpectedToken { token: t.clone(), line: self.line_no, hint: "Unexpected token; check for missing operators or delimiters" }),
        };

        // parse postfix: calls and member access, allow chaining
    loop {
            match &self.curr {
                Token::LParen => {
                    self.advance()?; // '('
                    let mut args = Vec::new();
                    while matches!(self.curr, Token::Newline) { self.advance()?; }
                    if !matches!(self.curr, Token::RParen) {
                        loop {
                            let arg = self.parse_expression(0)?;
                            args.push(arg);
                            while matches!(self.curr, Token::Newline) { self.advance()?; }
                            match self.curr {
                                Token::Comma => { self.advance()?; while matches!(self.curr, Token::Newline) { self.advance()?; } }
                                Token::RParen => break,
                                _ => return Err(ParserError::ExpectedToken { expected: ") or ,", line: self.line_no, hint: "Separate arguments with ',' or close with ')'" }),
                            }
                        }
                    }
                    self.expect(Token::RParen, ")' after arguments", "Close the call with ')'" )?;
                    expr = Expr::Call { function: Box::new(expr), args };
                }
                Token::Dot => {
                    // Only treat as member access if next token is an identifier; otherwise it's a terminator (e.g., facts)
                    if let Token::Identifier(_) = self.peek {
                        self.advance()?; // '.'
                        let prop = match &self.curr {
                            Token::Identifier(s) => s.clone(),
                            _ => return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Property name expected after '.'" }),
                        };
                        self.advance()?;
                        expr = Expr::Member { object: Box::new(expr), property: prop };
                    } else {
                        // do not consume '.'; let outer statement parser treat it as separator
                        break;
                    }
                }
                _ => break,
            }
        }
        Ok(expr)
    }

    fn expect(&mut self, tk: Token, _msg: &'static str, hint: &'static str) -> Result<(), ParserError> {
        if std::mem::discriminant(&self.curr) == std::mem::discriminant(&tk) {
            self.advance()?;
            Ok(())
        } else {
            Err(ParserError::ExpectedToken { expected: "mismatched token", line: self.line_no, hint })
        }
    }
}
