//! Minimal Patlang parser (Rust)

use crate::ast::{BinaryOperator, Expr, Stmt};
use crate::lexer::{Lexer, LexerError, Token, TokenExpectation};

#[derive(Debug)]
pub enum ParserError {
    Lexer(LexerError),
    UnexpectedToken { token: Token, line: usize, hint: &'static str },
    ExpectedIdentifier { line: usize, hint: &'static str },
    ExpectedToken { expected: &'static str, line: usize, hint: &'static str },
    // A syntactically valid identifier that's forbidden in this position --
    // distinct from ExpectedIdentifier (no identifier found at all). Used
    // for `main`, which collides with the native-compiled backend's own
    // Rust `fn main()` entry point: a user function literally named this
    // used to compile successfully via patc1.exe/pat --patc with no
    // error, but the emitted call recursed into itself infinitely at
    // runtime instead of dispatching to the real program entry,
    // overflowing the stack.
    //
    // Genuinely only a native-compilation problem -- the tree-walking
    // interpreter (--ir-run) has no Rust entry point to collide with,
    // `main` there is just an ordinary function name. Rejected here
    // anyway, for BOTH backends, since the parser can't know at parse
    // time which backend the resulting AST will run on. A deliberate,
    // known over-restriction chosen for simplicity over a heavier,
    // backend-conditional check deferred to codegen time -- worth
    // relaxing if it ever becomes a real nuisance for --ir-run-only
    // code. The honest long-term fix is making native codegen emit an
    // entry-point name that can't collide with any PatLang identifier
    // at all, removing the need for this restriction entirely.
    ReservedName { name: String, line: usize, hint: &'static str },
    // `when` handlers are collected once, statically, at lowering time
    // (ir/lowering.rs's own top-level-only scan for Stmt::When) -- a
    // `when` nested inside an if/while/function body used to parse
    // successfully and then simply never fire, ever, with no error
    // anywhere. Deliberate, not just a simplicity shortcut: PatLang's
    // capability-discovery system (self_hosting/lib/signal_discovery.
    // patlang) treats a service's advertised actions as fixed for the
    // life of the process; if handler registration could vary at
    // runtime, an honest self-description could go stale without a new
    // announcement ever being made. See check_when_placement below.
    MisplacedWhen { line: usize, hint: &'static str },
}

// Walks the parsed statement tree looking for a `Stmt::When` at depth >
// 0 (nested inside If/While/Function bodies, not genuine top level).
// Mirrors self_hosting/lib/parser.patlang's parse_check_when_placement
// exactly -- same rule, same rationale, kept in sync by hand since this
// is a real grammar-level check, not just a host function (see the
// mirror-check skill's "Part 2: grammar parity" distinction).
fn check_when_placement(stmts: &[Stmt], depth: usize) -> Result<(), ParserError> {
    for s in stmts {
        match s {
            Stmt::When { line, .. } if depth > 0 => {
                return Err(ParserError::MisplacedWhen {
                    line: *line,
                    hint: "'when' can only be declared at the top level of a program -- it cannot be nested inside if/while blocks or function bodies, since handlers are registered once, statically, not conditionally at runtime",
                });
            }
            Stmt::If { then_branch, else_branch, .. } => {
                check_when_placement(then_branch, depth + 1)?;
                if let Some(else_b) = else_branch { check_when_placement(else_b, depth + 1)?; }
            }
            Stmt::While { body, .. } => check_when_placement(body, depth + 1)?,
            Stmt::Function { body, .. } => check_when_placement(body, depth + 1)?,
            _ => {}
        }
    }
    Ok(())
}

#[derive(Debug)]
pub struct Parser<'a> {
    lexer: Lexer<'a>,
    curr: Token,
    peek: Token,
    line_no: usize,
    // When true, do not treat a trailing '{ ... }' after an expression as a closure argument.
    // This is used when parsing conditions like `if cond { ... }` to avoid consuming the block.
    stop_trailing_block_for_condition: bool,
    // Label used in diagnostics (warnings/errors) to say which source this
    // Parser is actually reading -- defaults to "<input>" for call sites
    // that don't have a real filename (tests, embedded snippets). Set via
    // `with_source_name`/`set_source_name`.
    source_name: String,
}

impl<'a> Parser<'a> {
    pub fn new(input: &'a str) -> Result<Self, ParserError> {
        let mut lexer = Lexer::new(input);
        let curr = lexer.next_token().map_err(ParserError::Lexer)?;
        let peek = lexer.next_token().map_err(ParserError::Lexer)?;
    Ok(Parser { lexer, curr, peek, line_no: 1, stop_trailing_block_for_condition: false, source_name: "<input>".to_string() })
    }

    pub fn with_source_name(mut self, name: impl Into<String>) -> Self {
        self.source_name = name.into();
        self
    }

    pub fn set_source_name(&mut self, name: impl Into<String>) {
        self.source_name = name.into();
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
            Token::Let | Token::Fn | Token::If | Token::While | Token::Return | Token::Goal | Token::Rule => true,
            Token::Identifier(_) | Token::Number(_) | Token::Float(_) | Token::String(_) | Token::LParen | Token::BlockStart => true, // expression stmt
            _ => false,
        }
    }

    // Shared word-delimited block collector for `do...end`/`then...end`
    // style blocks, replacing what used to be four independently
    // hand-duplicated loops (if/while/when/inline-make-function). Consumes
    // statements via `parse_statement()`, using `can_start_statement()` as
    // the continue-condition, until a bare identifier in `stop_words` is
    // seen (or, when `stop_on_else` is set, the dedicated `Token::Else`).
    // Returns the body plus which stop word was actually found, so callers
    // like `if` can distinguish `else` from `end`.
    fn parse_word_block(&mut self, stop_words: &[&str], stop_on_else: bool) -> Result<(Vec<Stmt>, String), ParserError> {
        let mut body: Vec<Stmt> = Vec::new();
        loop {
            self.consume_newlines()?;
            if stop_on_else && matches!(self.curr, Token::Else) {
                return Ok((body, "else".to_string()));
            }
            if let Token::Identifier(ref t) = self.curr {
                if stop_words.contains(&t.as_str()) {
                    let found = t.clone();
                    self.advance()?;
                    return Ok((body, found));
                }
            }
            if matches!(self.curr, Token::EOF) {
                return Ok((body, "EOF".to_string()));
            }
            if self.can_start_statement() {
                body.push(self.parse_statement()?);
            } else {
                self.advance()?;
            }
        }
    }

    pub fn parse(&mut self) -> Result<Vec<Stmt>, ParserError> {
        let mut stmts = Vec::new();
        // Allow leading newlines
        self.consume_newlines()?;
        while !matches!(self.curr, Token::EOF | Token::BlockEnd) {
            let stmt = self.parse_statement()?;
            stmts.push(stmt);

            // After a statement, collect separators (semicolons/newlines/periods for facts,
            // commas for DSL-style clause sequences)
            let mut saw_sep = false;
            let mut saw_nl = false;
            while matches!(self.curr, Token::Semicolon | Token::Newline | Token::Dot | Token::Comma) {
                if matches!(self.curr, Token::Semicolon | Token::Dot | Token::Comma) { saw_sep = true; }
                if matches!(self.curr, Token::Newline) { saw_nl = true; }
                self.advance()?;
            }

            // If end of input or block, stop
            if matches!(self.curr, Token::EOF | Token::BlockEnd) {
                break;
            }

            // A separator (';'/newline/etc, collected above) is welcome but no longer
            // required: by the time a statement is fully parsed, its own expression
            // parser has already resolved exactly how far it extends (operator
            // lookahead, not newline significance -- see parse_expression's own
            // continuation rule), so there's no remaining ambiguity for a separator
            // to protect against here. The one case that WOULD have been ambiguous --
            // a bare `{ ... }` sitting where it could be misread as either its own
            // statement or a trailing-closure argument to whatever just finished --
            // is handled by rejecting bare `{ ... }` as a statement outright (see
            // parse_statement's Token::BlockStart arm), not by requiring a separator
            // everywhere. `saw_sep`/`saw_nl` remain unused for gating now, kept only
            // because the loop above still needs to consume the separator tokens.
            let _ = (saw_sep, saw_nl);
        }
        check_when_placement(&stmts, 0)?;
        Ok(stmts)
    }

    // Attempts a real `Head(args) :- Body1, Body2.` / `Head(args).` parse
    // (the 'rule' keyword itself already consumed by the caller). Returns
    // None -- rather than propagating a hard ParserError -- on anything
    // that doesn't fit the Prolog-goal shape, so the caller can gracefully
    // degrade to the legacy skip-to-terminator no-op instead of a fatal
    // error on non-conforming `rule ...` uses in the wild.
    fn try_parse_rule_decl(&mut self) -> Option<Stmt> {
        let head_expr = self.parse_expression(0).ok()?;
        let (head_pred, head_args) = match head_expr {
            Expr::Call { function, args } => match *function {
                Expr::Identifier(name) => (name, args),
                _ => return None,
            },
            _ => return None,
        };
        let mut body: Vec<(String, Vec<Expr>)> = Vec::new();
        if matches!(self.curr, Token::Turnstile) {
            self.advance().ok()?;
            loop {
                while matches!(self.curr, Token::Newline) { self.advance().ok()?; }
                let goal_expr = self.parse_expression(0).ok()?;
                match goal_expr {
                    Expr::Call { function, args } => match *function {
                        Expr::Identifier(name) => body.push((name, args)),
                        _ => return None,
                    },
                    _ => return None,
                }
                while matches!(self.curr, Token::Newline) { self.advance().ok()?; }
                match self.curr {
                    Token::Comma => { self.advance().ok()?; }
                    Token::Dot => { self.advance().ok()?; break; }
                    _ => return None,
                }
            }
        } else if matches!(self.curr, Token::Dot) {
            self.advance().ok()?;
        } else {
            return None;
        }
        Some(Stmt::RuleDecl { head_pred, head_args, body })
    }

    fn parse_statement(&mut self) -> Result<Stmt, ParserError> {
        match self.curr {
            // A bare `{ ... }` is only meaningful as a VALUE (parse_primary still
            // turns it into a zero-param closure literal there, e.g. `let f = { ... }`
            // -- a real, deliberate function literal, not a leftover tolerance) --
            // never as its own free-standing statement. Rejecting it here, rather
            // than letting it fall through to the general expression-statement path
            // below, is what makes the statement separator above safe to drop: a
            // bare block sitting right after something that could take a trailing-
            // closure argument (`f(x)`) would otherwise be genuinely ambiguous
            // between "f(x) followed by its own discarded closure statement" and
            // "f(x) { ... }" sugar. With this rejected outright, that ambiguity
            // can't arise.
            Token::BlockStart => Err(ParserError::UnexpectedToken {
                token: Token::BlockStart,
                line: self.line_no,
                hint: "A bare '{ ... }' isn't a statement on its own -- it's a function literal as a VALUE (e.g. `let f = { ... }`, then call it with `f()`), not something to write standalone",
            }),
            Token::Let => self.parse_let(),
            Token::Fn => self.parse_function(),
            Token::Return => self.parse_return(),
            Token::If => self.parse_if(),
            Token::While => self.parse_while(),
            // Native DSL: handle 'goal' and 'rule' tokens directly and skip their bodies/lines.
            Token::Goal => {
                // If followed by '(', treat as normal call: goal(...)
                if matches!(self.peek, Token::LParen) {
                    // Rebind current token to Identifier("goal") and parse as expression statement
                    self.curr = Token::Identifier("goal".into());
                    let expr = self.parse_expression(0)?;
                    return Ok(Stmt::ExprStmt(expr));
                }
                // Real declarative syntax: `goal NAME { dep1(args), dep2(args) }`
                // -- names a target state as a list of fact-terms. Sugar
                // only, lowers to a single goal_def(...) call (see
                // lower_stmt); see Stmt::GoalDecl's doc comment in ast.rs.
                self.advance()?; // consume 'goal'
                let name = match &self.curr {
                    Token::Identifier(s) => { let n = s.clone(); self.advance()?; n }
                    _ => return Err(ParserError::ExpectedToken { expected: "goal name", line: self.line_no, hint: "Use `goal NAME { dep1(args), dep2(args) }`" }),
                };
                self.expect(Token::BlockStart, "'{' after goal name", "Use `goal NAME { dep1(args), dep2(args) }`")?;
                self.consume_newlines()?;
                let mut deps: Vec<(String, Vec<Expr>)> = Vec::new();
                while !matches!(self.curr, Token::BlockEnd | Token::EOF) {
                    let dep_expr = self.parse_expression(0)?;
                    match dep_expr {
                        Expr::Call { function, args } => match *function {
                            Expr::Identifier(n) => deps.push((n, args)),
                            _ => return Err(ParserError::UnexpectedToken { token: self.curr.clone(), line: self.line_no, hint: "Each goal dependency must be a fact-term like pred(args)" }),
                        },
                        _ => return Err(ParserError::UnexpectedToken { token: self.curr.clone(), line: self.line_no, hint: "Each goal dependency must be a fact-term like pred(args)" }),
                    }
                    self.consume_newlines()?;
                    if matches!(self.curr, Token::Comma) {
                        self.advance()?;
                        self.consume_newlines()?;
                    }
                }
                self.expect(Token::BlockEnd, "'}' to close goal block", "Close the goal block with '}'")?;
                Ok(Stmt::GoalDecl { name, deps })
            }
            Token::Rule => {
                // If followed by '(', treat as normal call: rule(...)
                if matches!(self.peek, Token::LParen) {
                    self.curr = Token::Identifier("rule".into());
                    let expr = self.parse_expression(0)?;
                    return Ok(Stmt::ExprStmt(expr));
                }
                // Real declarative syntax: `rule Head(args) :- Body1, Body2.`
                // (a rule) or `rule Head(args).` (a fact -- a rule with an
                // empty body, the standard Prolog trick, matching how
                // rule_add already treats an empty body_list). Sugar only --
                // lowers to exactly the Instr sequence a hand-written
                // rule_add(...) call already produces (see lower_stmt).
                //
                // Not every `rule NAME(...) :- ....` in the wild is actually
                // Prolog-shaped (found the hard way: native_parser/
                // native_parser.patlang uses the same surface syntax for an
                // unrelated pseudo-code convention with arbitrary statement
                // bodies, e.g. `rule f(x) :- x = { a: 1 }.`). Rather than a
                // hard parse error on anything that isn't goal-shaped, fall
                // back to the legacy skip-to-terminator no-op for backward
                // compatibility -- exactly the old behavior for any `rule`
                // statement, now scoped to only the non-conforming case.
                self.advance()?; // consume 'rule'
                let parsed = self.try_parse_rule_decl();
                match parsed {
                    Some(stmt) => Ok(stmt),
                    None => {
                        loop {
                            match self.curr {
                                Token::EOF => break,
                                Token::Dot if matches!(self.peek, Token::Newline | Token::EOF) => { self.advance()?; break; },
                                Token::BlockStart => { self.skip_brace_block()?; },
                                _ => { self.advance()?; }
                            }
                        }
                        Ok(Stmt::ExprStmt(Expr::String(String::new())))
                    }
                }
            }
            // identifier assignment: name = expr (but not member assignment)
            Token::Identifier(_) if matches!(self.peek, Token::Equal) => self.parse_assignment(),
            _ => {
                // Special forms
                if let Token::Identifier(ref s0) = self.curr {
                    let curr_ident = s0.clone();
                    let curr_lc = curr_ident.to_lowercase();
                    // Bare print: `print expr` → treat like call
                    if curr_lc == "print" {
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
                    if curr_lc == "fact" && !matches!(self.peek, Token::LParen) {
                        // Skip rest of the line or until terminating '.'
                        while !matches!(self.curr, Token::Newline | Token::EOF) {
                            if matches!(self.curr, Token::Dot) { self.advance()?; break; }
                            self.advance()?;
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Rules: rule name(args) :- ...  → skip to line end or to '.' when not used as normal call
                    if curr_lc == "rule" && !matches!(self.peek, Token::LParen) {
                        // consume tokens until newline or '.'
                        while !matches!(self.curr, Token::Newline | Token::EOF) {
                            if matches!(self.curr, Token::Dot) { self.advance()?; break; }
                            self.advance()?;
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Goals: goal name { ... } → skip brace block if present (but preserve call form goal(...))
                    if curr_lc == "goal" && !matches!(self.peek, Token::LParen) {
                        // consume until '{' then skip block; otherwise skip rest of line
                        while !matches!(self.curr, Token::BlockStart | Token::Newline | Token::EOF) { self.advance()?; }
                        if matches!(self.curr, Token::BlockStart) { self.skip_brace_block()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Reasoning mode on/off: skip rest of line
                    if curr_lc == "reasoning" {
                        while !matches!(self.curr, Token::Newline | Token::EOF) { self.advance()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Skip 'constrain X :: Y where { ... }' spec blocks used in native self-hosting files
                    if curr_lc == "constrain" {
                        // consume until a '{', then skip the brace block; otherwise skip to end of line
                        while !matches!(self.curr, Token::BlockStart | Token::Newline | Token::EOF) { self.advance()?; }
                        if matches!(self.curr, Token::BlockStart) { self.skip_brace_block()?; }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // `pursue GOAL` is an expression (see parse_primary's
                    // "pursue" special case, mirroring "budgeted"'s
                    // precedent) so it can be used as `let p = pursue GOAL`
                    // -- at the statement level it just falls through to
                    // ordinary expression-statement parsing below, no
                    // special case needed here.
                    // Design-by-contract: require/ensure/assert EXPR
                    if curr_lc == "require" || curr_lc == "ensure" || curr_lc == "assert" {
                        self.advance()?; // consume the keyword
                        let expr = self.parse_expression(0)?;
                        return Ok(Stmt::Assert { kind: curr_lc, expr });
                    }
                    // DSL sugar: make a function called Name { ... }
                    if curr_lc == "make" {
                        if let Some(stmt) = self.parse_make_construct()? { return Ok(stmt); }
                    }
                    // JS-style: function Name(params) { ... }
                    if curr_lc == "function" {
                        if let Token::Identifier(_) = self.peek {
                            self.advance()?; // consume 'function'
                            let fname = match &self.curr {
                                Token::Identifier(s) => { let n = s.clone(); self.advance()?; n }
                                _ => unreachable!(),
                            };
                            let mut params: Vec<String> = Vec::new();
                            if matches!(self.curr, Token::LParen) {
                                self.advance()?;
                                loop {
                                    match &self.curr {
                                        Token::Identifier(s) => { params.push(s.clone()); self.advance()?; }
                                        Token::Comma => { self.advance()?; }
                                        Token::Newline => { self.advance()?; }
                                        Token::RParen => { self.advance()?; break; }
                                        _ => break,
                                    }
                                }
                            }
                            self.consume_newlines()?;
                            let body = if matches!(self.curr, Token::BlockStart) {
                                self.advance()?; // '{'
                                self.parse_block()?
                            } else { vec![] };
                            return Ok(Stmt::Function { name: fname, params, body });
                        }
                    }
                    // DSL events: when <event> { ... } → capture as Stmt::When
                    if curr_lc == "when" {
                        let when_line = self.line_no;
                        self.advance()?; // consume 'when'
                        // capture a simple identifier as event name; otherwise, fallback to skip
                        let event_name = match &self.curr { Token::Identifier(s) => { let n = s.clone(); self.advance()?; n }, _ => String::new() };
                        if matches!(self.curr, Token::BlockStart) {
                            // Parse the block body using normal rules
                            self.advance()?; // '{'
                            let body = self.parse_block()?;
                            return Ok(Stmt::When { event: event_name, body, line: when_line });
                        } else if matches!(&self.curr, Token::Identifier(s) if s == "do") {
                            // Stage 1 form: when EVENT do ... end
                            self.advance()?; // 'do'
                            let (body, _) = self.parse_word_block(&["end"], false)?;
                            return Ok(Stmt::When { event: event_name, body, line: when_line });
                        } else {
                            // Fallback: skip to next block to avoid breaking flow
                            while !matches!(self.curr, Token::BlockStart | Token::EOF) { self.advance()?; }
                            if matches!(self.curr, Token::BlockStart) { self.skip_brace_block()?; }
                            return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                        }
                    }
                    // Relationship declarations: skip until trailing '.'
                    if curr_lc == "relationship" {
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
                    // `activate PLAN` is an expression, see parse_primary's
                    // "activate" special case (mirroring "pursue"/
                    // "budgeted") -- at the statement level it just falls
                    // through to ordinary expression-statement parsing
                    // below, no special case needed here.
                    // Skip 'case ... end' constructs (Ruby-like)
                    if curr_lc == "case" {
                        self.skip_until_ident("end")?;
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Skip inline 'query ... end' blocks used in DSL examples
                    // Only when this is NOT a normal function call like query(...)
                    if curr_lc == "query" && !matches!(self.peek, Token::LParen) {
                        self.skip_until_ident("end")?;
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Skip simple while-do-end loops used in examples
                    if curr_lc == "while" {
                        // consume until we find an Identifier("end")
                        self.skip_until_ident("end")?;
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                    // Label-style lines inside DSL blocks: precondition:, postcondition:, strategy:, etc.
                    // If we see Identifier followed by ':', skip to end of line or block separator.
                    if matches!(self.peek, Token::Colon) {
                        // consume ident and ':'
                        self.advance()?; // ident
                        self.advance()?; // ':'
                        // skip until newline, '}', or EOF
                        while !matches!(self.curr, Token::Newline | Token::BlockEnd | Token::EOF) {
                            self.advance()?;
                        }
                        return Ok(Stmt::ExprStmt(Expr::String(String::new())));
                    }
                }
                // Best-effort fallback: if the current token starts with our DSL words like 'make' or 'when',
                // skip ahead to the next block and consume it, treating it as a no-op block statement.
                if let Token::Identifier(ref s) = self.curr {
                    let lc = s.to_lowercase();
                    if lc == "make" || lc == "when" {
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
                let start_line = self.line_no;
                let expr = self.parse_expression(0)?;
                // If we just parsed a Member expr and see '=', treat as member assignment
                if matches!(self.curr, Token::Equal) {
                    if let Expr::Member { object, property } = expr {
                        // consume '=' and parse value
                        self.advance()?;
                        let value = self.parse_expression(0)?;
                        return Ok(Stmt::MemberAssign { object: *object, property, value });
                    } else if let Expr::Identifier(name) = expr {
                        // fallback: simple identifier assignment (bare reassignment)
                        self.advance()?; // consume '='
                        let value = self.parse_expression(0)?;
                        return Ok(Stmt::Let { name, value, is_reassignment: true, mutable: false });
                    } else {
                        return Err(ParserError::UnexpectedToken { token: self.curr.clone(), line: self.line_no, hint: "Unexpected token; check for missing operators or delimiters" });
                    }
                }
                // "You computed a value and threw it away, sure you want to do
                // that?" -- a soft warning, not an error: only for expressions
                // that structurally cannot have a side effect (a literal,
                // arithmetic/comparison over such, a bare variable read, a list
                // literal of such). A Call is deliberately never flagged here --
                // print(x)'s whole point is a discarded Unit return, and that's
                // the overwhelmingly common shape of a real, intentional bare
                // expression statement.
                //
                // Exempt tail position: the last statement of a block (function/
                // closure/if/while body, or top-level program) is PatLang's
                // implicit return value, not a discarded one -- e.g. `|p| { p }`
                // is a deliberate identity closure. Detected by peeking past any
                // trailing newlines to see whether the block-terminating token
                // (EOF, `}}`, or a stop word like `end`/`elif`/`else`) comes next.
                if is_side_effect_free_expr(&expr) {
                    self.consume_newlines()?;
                    let is_tail = matches!(self.curr, Token::EOF | Token::BlockEnd | Token::Else)
                        || matches!(&self.curr, Token::Identifier(t) if t == "end" || t == "elif");
                    if !is_tail {
                        eprintln!(
                            "warning: {}:{}: this expression's value is computed and discarded -- did you mean to assign it, print it, or was an operator/statement missing?",
                            self.source_name, start_line
                        );
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
        if kind_is_function && name == "main" {
            return Err(ParserError::ReservedName { name, line: self.line_no, hint: "'main' collides with the native-compiled backend's own program entry point -- rename this function" });
        }
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
            // Attempt to parse inline form: optional 'takes' params, optional 'returns <var>' hint,
            // then a sequence of statements ending at 'end'.
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
                    // A reserved keyword here (e.g. `rule`, `goal`, `fn`, `let`,
                    // `if`) is almost always the user trying to name a
                    // parameter after an ordinary English word that happens
                    // to also be a language keyword -- silently falling
                    // through to `_ => break` here used to truncate the
                    // params list right at that point with no error at all,
                    // corrupting the rest of the function's parsing
                    // (found via self_hosting/lib/syntax_dsl.patlang's own
                    // `takes def, rule, line`, which ended up with a
                    // 1-param, 2-instruction function body and no
                    // indication anything had gone wrong until the
                    // corrupted Program later crashed the interpreter).
                    Token::Rule | Token::Goal | Token::Fn | Token::Let | Token::Return
                    | Token::If | Token::While | Token::Else | Token::Elif
                    | Token::And | Token::Or | Token::Not
                    | Token::BAnd | Token::BOr | Token::BXor | Token::BNot
                    | Token::Shl | Token::Shr => {
                        return Err(ParserError::UnexpectedToken {
                            token: self.curr.clone(),
                            line: self.line_no,
                            hint: "This is a reserved keyword, not a valid parameter name -- rename this parameter to something else (e.g. `the_rule` instead of `rule`)",
                        });
                    }
                    _ => break,
                }
            }
            // optional 'returns <var>' hint
            let mut return_hint: Option<String> = None;
            if let Token::Identifier(ref s) = self.curr { if s == "returns" { self.advance()?; }
                if let Token::Identifier(var) = &self.curr {
                    return_hint = Some(var.clone());
                    self.advance()?;
                }
            }
            // Parse statements until we encounter Identifier("end")
            let (mut body, _) = self.parse_word_block(&["end"], false)?;
            // If a return hint was provided and no explicit return found, append it as final return
            if let Some(var) = return_hint {
                let has_return = body.iter().any(|s| matches!(s, Stmt::Return(_)));
                if !has_return {
                    body.push(Stmt::Return(Some(Expr::Identifier(var))));
                }
            }
            return Ok(Some(Stmt::Function { name, params, body }));
        } else if kind_is_template {
            // Inline template: skip to 'end'
            self.skip_until_ident("end")?;
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
        // optional 'mut'
        let mutable = if let Token::Identifier(ref s) = self.curr {
            if s == "mut" { true } else { false }
        } else { false };
        if mutable { self.advance()?; }
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
        Ok(Stmt::Let { name, value, is_reassignment: false, mutable })
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
        Ok(Stmt::Let { name, value, is_reassignment: true, mutable: false })
    }

    fn parse_function(&mut self) -> Result<Stmt, ParserError> {
        // consume 'fn'
        self.advance()?;
        let name = match &self.curr {
            Token::Identifier(s) => s.clone(),
            _ => return Err(ParserError::ExpectedIdentifier { line: self.line_no, hint: "Function name expected after 'fn'" }),
        };
        if name == "main" {
            return Err(ParserError::ReservedName { name, line: self.line_no, hint: "'main' collides with the native-compiled backend's own program entry point -- rename this function" });
        }
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

            // After a statement, collect separators (semicolons/newlines/periods/commas)
            let mut saw_sep = false;
            let mut saw_nl = false;
            while matches!(self.curr, Token::Semicolon | Token::Newline | Token::Dot | Token::Comma) {
                if matches!(self.curr, Token::Semicolon | Token::Dot | Token::Comma) { saw_sep = true; }
                if matches!(self.curr, Token::Newline) { saw_nl = true; }
                self.advance()?;
            }

            // If end of block/input, stop
            if matches!(self.curr, Token::BlockEnd | Token::EOF) { break; }

            // If the next token can start a statement but we didn't see any separator,
            // be tolerant within blocks as well (native .patlang style).
            let _ = (saw_sep, saw_nl);
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
    let prev_flag = self.stop_trailing_block_for_condition;
    self.stop_trailing_block_for_condition = true;
    let cond = self.parse_expression(0)?;
    self.stop_trailing_block_for_condition = prev_flag;
        // allow newlines between condition and block/then
        self.consume_newlines()?;
        // Support two forms:
        // 1) Brace form: if <cond> { ... } [else { ... }]
        // 2) Ruby-like form: if <cond> then ... [else ...] end
        if matches!(self.curr, Token::BlockStart) {
            // then block with '{}'
            self.advance()?;
            let then_branch = self.parse_block()?;
            // optional else/elif
            // allow newlines before else/elif
            self.consume_newlines()?;
            let else_branch = if matches!(self.curr, Token::Else | Token::Elif) {
                match self.curr {
                    Token::Else => {
                        self.advance()?;
                        // tolerate newline before '{'
                        self.consume_newlines()?;
                        self.expect(Token::BlockStart, "'{' to start 'else' block", "Start the 'else' block with '{'" )?;
                        Some(self.parse_block()?)
                    }
                    Token::Elif => {
                        // elif -> else { if ... }
                        self.advance()?;
                        Some(vec![self.parse_if_brace_elif_tail()?])
                    }
                    _ => None,
                }
            } else { None };
            return Ok(Stmt::If { cond, then_branch, else_branch });
        } else if let Token::Identifier(ref s) = self.curr {
            if s == "then" {
                // Ruby-like: if cond then ... [elif cond then ...] [else ...] end
                self.advance()?; // consume 'then'
                return self.parse_if_then_tail(cond);
            }
        }
        // fallback: expecting brace form if none matched
    // allow newlines before '{'
    self.consume_newlines()?;
    self.expect(Token::BlockStart, "'{' to start 'if' block", "Start the 'if' block with '{'" )?;
        let then_branch = self.parse_block()?;
        Ok(Stmt::If { cond, then_branch, else_branch: None })
    }

    // Parses one `elif <cond> { ... }` clause of the brace form, assuming
    // 'elif' has already been consumed: parses its condition and block,
    // then recurses for a further `elif`/`else`/end, so chains of any
    // length nest correctly (mirrors parse_if_then_tail for the `then` form).
    fn parse_if_brace_elif_tail(&mut self) -> Result<Stmt, ParserError> {
        let prev_flag2 = self.stop_trailing_block_for_condition;
        self.stop_trailing_block_for_condition = true;
        let cond2 = self.parse_expression(0)?;
        self.stop_trailing_block_for_condition = prev_flag2;
        // tolerate newline before '{'
        self.consume_newlines()?;
        self.expect(Token::BlockStart, "'{' to start 'elif' block", "Start the 'elif' block with '{'" )?;
        let then2 = self.parse_block()?;
        self.consume_newlines()?;
        let else_branch = if matches!(self.curr, Token::Else | Token::Elif) {
            match self.curr {
                Token::Else => {
                    self.advance()?;
                    self.consume_newlines()?;
                    self.expect(Token::BlockStart, "'{' to start 'else' block", "Start the 'else' block with '{'" )?;
                    Some(self.parse_block()?)
                }
                Token::Elif => {
                    self.advance()?;
                    Some(vec![self.parse_if_brace_elif_tail()?])
                }
                _ => None,
            }
        } else { None };
        Ok(Stmt::If { cond: cond2, then_branch: then2, else_branch })
    }

    // Parses the tail of a Ruby-like `if cond then ...` form, assuming
    // 'then' has already been consumed: then-branch, optional `elif`
    // (desugared to `else { if ... }`, matching the brace form), optional
    // `else`, and the closing `end`.
    fn parse_if_then_tail(&mut self, cond: Expr) -> Result<Stmt, ParserError> {
        let (then_branch, stopper) = self.parse_word_block(&["end", "elif"], true)?;
        let else_branch = if stopper == "else" {
            let (else_body, _) = self.parse_word_block(&["end"], false)?;
            Some(else_body)
        } else if stopper == "elif" {
            let prev_flag2 = self.stop_trailing_block_for_condition;
            self.stop_trailing_block_for_condition = true;
            let cond2 = self.parse_expression(0)?;
            self.stop_trailing_block_for_condition = prev_flag2;
            self.consume_newlines()?;
            if let Token::Identifier(ref s2) = self.curr { if s2 == "then" { self.advance()?; } }
            let nested = self.parse_if_then_tail(cond2)?;
            Some(vec![nested])
        } else { None };
        Ok(Stmt::If { cond, then_branch, else_branch })
    }

    fn parse_while(&mut self) -> Result<Stmt, ParserError> {
        // consume 'while'
        self.advance()?;
        // parse condition (prevent postfix block capture)
        let prev_flag = self.stop_trailing_block_for_condition;
        self.stop_trailing_block_for_condition = true;
        let cond = self.parse_expression(0)?;
        self.stop_trailing_block_for_condition = prev_flag;
        // allow newlines
        self.consume_newlines()?;
        // Two forms: while <cond> { ... }  or  while <cond> do ... end
        if matches!(self.curr, Token::BlockStart) {
            self.advance()?;
            let body = self.parse_block()?;
            return Ok(Stmt::While { cond, body });
        }
        if let Token::Identifier(ref s) = self.curr {
            if s == "do" {
                self.advance()?;
                let (body, _) = self.parse_word_block(&["end"], false)?;
                return Ok(Stmt::While { cond, body });
            }
        }
        // fallback: expect brace form
        self.expect(Token::BlockStart, "'{' to start 'while' block", "Start the 'while' block with '{'")?;
        let body = self.parse_block()?;
        Ok(Stmt::While { cond, body })
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
                    Token::EqualEqual | Token::NotEqual | Token::Greater | Token::GreaterEqual | Token::Less | Token::LessEqual => {
                        self.advance()?;
                    }
                    Token::BAnd | Token::BOr | Token::BXor | Token::Shl | Token::Shr => {
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
            // `obj.prop = value` disambiguation: bare '=' is ALSO a valid binary
            // equality operator (kept for tolerated DSL forms like `if 1 = 1
            // then ...`, see native_compat_parser.rs's accepts_single_equals_
            // as_equality test) -- Token::Equal and Token::EqualEqual both
            // collapse to the same BinaryOperator::Equal AST node, so this must
            // be decided HERE, at the token level, before that distinction is
            // lost; reinterpreting the completed AST afterward (tried first)
            // can't tell a real `p.age == "30"` (double equals, unaffected by
            // this check) apart from `p1.name = "alice"` once both are just
            // BinaryOp{Equal}. Only single '=' directly after a Member expr,
            // outside a condition (stop_trailing_block_for_condition is true
            // during if/while conditions specifically, where single '=' must
            // keep meaning equality), is reinterpreted -- by breaking here
            // without consuming '=', leaving it for parse_statement's existing
            // Member+pending-Equal check to turn into a MemberAssign.
            if matches!(self.curr, Token::Equal) && !self.stop_trailing_block_for_condition && matches!(lhs, Expr::Member { .. }) {
                break;
            }
            let (op, lbp, rbp) = match self.curr {
                Token::Plus => (BinaryOperator::Add, 10, 11),
                Token::Minus => (BinaryOperator::Sub, 10, 11),
                Token::Star => (BinaryOperator::Mul, 20, 21),
                Token::Slash => (BinaryOperator::Div, 20, 21),
                Token::Percent => (BinaryOperator::Mod, 20, 21),
                Token::EqualEqual => (BinaryOperator::Equal, 5, 6),
                Token::NotEqual => (BinaryOperator::NotEqual, 5, 6),
                Token::Equal => (BinaryOperator::Equal, 5, 6),
                Token::Greater => (BinaryOperator::Greater, 7, 8),
                Token::GreaterEqual => (BinaryOperator::GreaterEqual, 7, 8),
                Token::Less => (BinaryOperator::Less, 7, 8),
                Token::LessEqual => (BinaryOperator::LessEqual, 7, 8),
                Token::And => (BinaryOperator::And, 3, 4),
                Token::Or => (BinaryOperator::Or, 2, 3),
                // Bitwise: shl/shr bind tighter than +/- but looser than
                // */%, matching C's own placement. band/bxor/bor share a
                // single combined tier (looser than +/-, tighter than
                // comparisons) rather than three separate C-style tiers --
                // parenthesize mixed band/bxor/bor expressions if a specific
                // grouping matters, same advice as mixing `and`/`or` today.
                Token::Shl => (BinaryOperator::Shl, 15, 16),
                Token::Shr => (BinaryOperator::Shr, 15, 16),
                Token::BAnd => (BinaryOperator::BitAnd, 9, 10),
                Token::BXor => (BinaryOperator::BitXor, 9, 10),
                Token::BOr => (BinaryOperator::BitOr, 9, 10),
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
            Token::BNot => { self.advance()?; let inner = self.parse_primary()?; Expr::UnaryOp { op: "bnot".into(), expr: Box::new(inner) } }
            Token::Minus => { self.advance()?; let inner = self.parse_primary()?; Expr::UnaryOp { op: "-".into(), expr: Box::new(inner) } }
            Token::Number(n) => { let v = *n; self.advance()?; Expr::Number(v) }
            Token::Float(n) => { let v = *n; self.advance()?; Expr::Float(v) }
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
                    // Expect body block: either '{ ... }' or 'do ... end'
                    let body = if matches!(self.curr, Token::BlockStart) {
                        self.advance()?; // '{'
                        self.parse_block()?
                    } else if matches!(&self.curr, Token::Identifier(s) if s == "do") {
                        self.advance()?; // 'do'
                        let (b, _) = self.parse_word_block(&["end"], false)?;
                        b
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
            // `pursue GOAL` -- an expression (so `let p = pursue GOAL`
            // works), desugared into a call against the `pursue` host fn,
            // GOAL taken as a bare name (matching how goal/rule names are
            // bare identifiers elsewhere, not general expressions). The
            // parenthesized form `pursue(x)` is NOT special-cased here --
            // it falls through to ordinary call parsing below and reaches
            // the same host fn with whatever expression `x` evaluates to.
            Token::Identifier(name) if name == "pursue" && !matches!(self.peek, Token::LParen) => {
                self.advance()?; // consume 'pursue'
                let goal_name = match &self.curr {
                    Token::Identifier(s) => { let n = s.clone(); self.advance()?; n }
                    _ => return Err(ParserError::ExpectedToken { expected: "goal name after 'pursue'", line: self.line_no, hint: "Use `pursue GOAL_NAME`" }),
                };
                Expr::Call {
                    function: Box::new(Expr::Identifier("pursue".into())),
                    args: vec![Expr::String(goal_name)],
                }
            }
            // `activate PLAN` -- an expression (its value is the overall
            // success boolean, see lowering.rs's lower_activate), desugared
            // into a call against the `activate(...)` synthesized dispatch
            // loop, PLAN taken as a general expression (unlike `pursue`'s
            // bare goal-name, a plan is an ordinary value -- typically a
            // variable holding a previous `pursue` result).
            Token::Identifier(name) if name == "activate" && !matches!(self.peek, Token::LParen) => {
                self.advance()?; // consume 'activate'
                let plan = self.parse_expression(0)?;
                Expr::Call {
                    function: Box::new(Expr::Identifier("activate".into())),
                    args: vec![plan],
                }
            }
            Token::Identifier(name) if name == "budgeted" && matches!(self.peek, Token::LParen) => {
                self.advance()?; // 'budgeted'
                self.advance()?; // '('
                let ms = self.parse_expression(0)?;
                let existing = if matches!(self.curr, Token::Comma) {
                    self.advance()?;
                    Some(Box::new(self.parse_expression(0)?))
                } else { None };
                self.expect(Token::RParen, "')' after budgeted(...) arguments", "Use budgeted(ms) or budgeted(ms, existing)")?;
                self.consume_newlines()?;
                if matches!(self.curr, Token::BlockStart) {
                    self.advance()?; // '{'
                    let body = self.parse_block()?;
                    Expr::Budgeted { ms: Box::new(ms), existing, body }
                } else if matches!(&self.curr, Token::Identifier(s) if s == "do") {
                    self.advance()?; // 'do'
                    let (body, _) = self.parse_word_block(&["end"], false)?;
                    Expr::Budgeted { ms: Box::new(ms), existing, body }
                } else {
                    return Err(ParserError::ExpectedToken { expected: "'{' or 'do' after budgeted(...)", line: self.line_no, hint: "Use budgeted(ms) { ... } or budgeted(ms) do ... end" });
                }
            }
            Token::Identifier(name) => { let id = name.clone(); self.advance()?; Expr::Identifier(id) }
            // Tolerance: brace block in expression position (e.g. object-literal DSL)
            // parses as a parameterless closure; Stage 0 assigns no semantics yet.
            Token::BlockStart => {
                self.advance()?; // '{'
                let body = self.parse_block()?;
                Expr::Closure { params: vec![], body }
            }
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
                Token::BlockStart => {
                    // If we're parsing a condition (e.g., `if cond { ... }`), do not
                    // consume the block here as a trailing closure; let the caller handle it.
                    if self.stop_trailing_block_for_condition {
                        break;
                    }
                    // Treat a trailing '{ ... }' as an implicit closure block. If expr is a call,
                    // append the closure as the last argument; otherwise, produce a Closure expr.
                    self.advance()?; // consume '{'
                    let block_body = self.parse_block()?;
                    let closure = Expr::Closure { params: vec![], body: block_body };
                    match expr {
                        Expr::Call { function, mut args } => {
                            args.push(closure);
                            expr = Expr::Call { function, args };
                        }
                        _ => {
                            expr = closure;
                        }
                    }
                }
                Token::LBracket => {
                    // Index expression: expr[index]
                    self.advance()?; // '['
                    while matches!(self.curr, Token::Newline) { self.advance()?; }
                    let index = self.parse_expression(0)?;
                    while matches!(self.curr, Token::Newline) { self.advance()?; }
                    self.expect(Token::RBracket, "] to close index", "Close the index with ']'")?;
                    expr = Expr::Index { object: Box::new(expr), index: Box::new(index) };
                }
                Token::Dot => {
                    // Member access requires an identifier to follow; anything
                    // else (e.g. end of a fact/sentence) means this '.' is a
                    // terminator, not part of this expression. Expressed using
                    // the same `TokenExpectation` vocabulary the lexer uses
                    // internally to resolve the analogous decimal-point
                    // ambiguity (see `TokenExpectation` in lexer.rs) — the
                    // parser here declares "I expect a Letter-class token" and
                    // checks the already-buffered lookahead against it.
                    if TokenExpectation::classify_token(&self.peek) == TokenExpectation::Letter {
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

// Only true for expression shapes that structurally cannot perform a side
// effect -- Call/Member/Index/Closure/Budgeted are all deliberately
// excluded (a Call in particular is nearly always intentional, print(x)
// being the paradigm case), so this only flags the cases genuinely likely
// to be a mistake: a stray literal, a bare variable read, an arithmetic/
// comparison expression, or a list built from such.
fn is_side_effect_free_expr(e: &Expr) -> bool {
    match e {
        Expr::Number(_) | Expr::Float(_) | Expr::String(_) | Expr::Identifier(_) => true,
        Expr::List(items) => items.iter().all(is_side_effect_free_expr),
        Expr::UnaryOp { expr, .. } => is_side_effect_free_expr(expr),
        Expr::BinaryOp { left, right, .. } => is_side_effect_free_expr(left) && is_side_effect_free_expr(right),
        Expr::Member { .. } | Expr::Index { .. } | Expr::Closure { .. } | Expr::Call { .. } | Expr::Budgeted { .. } => false,
    }
}
