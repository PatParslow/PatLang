//! Patlang Lexer for Rust parser

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Number(f64),
    // Stage 36: a literal written with a decimal point (`42.5`), distinct
    // from `Number` (`42`) so the IR lowering step can pick the fast `Int`
    // path by default and only pay for `Float` when the source explicitly
    // asked for it.
    Float(f64),
    String(String),
    Identifier(String),
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    LParen,
    RParen,
    Comma,
    Semicolon,
    Dot, // Added for fact/query termination
    Colon,
    // ':-' -- rule turnstile (`rule Head(...) :- Body1, Body2.`)
    Turnstile,
    Pipe,
    // Combined pipeline operator '|>'
    PipeGreater,
    LBracket,
    RBracket,
    Let,
    Fn,
    Return,
    If,
    While,
    Else,
    Elif,
    Equal,
    EqualEqual,
    NotEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    And,
    Or,
    Not,
    // Bitwise keyword operators (word-form, matching and/or/not's own
    // convention -- `|` and `&` are already taken by Pipe/PipeGreater and
    // closure `|params|` syntax, so symbol-based bitwise ops would collide).
    BAnd,
    BOr,
    BXor,
    BNot,
    Shl,
    Shr,
    Newline,
    EOF,
    // Patlang-specific tokens
    Goal,
    Rule,
    BlockStart, // e.g. '{'
    BlockEnd,   // e.g. '}'
    // Extend with more tokens as needed
}

#[derive(Debug, Clone)]
pub struct Lexer<'a> {
    input: &'a str,
    position: usize,
    // Add more fields as needed
}

#[derive(Debug, PartialEq)]
pub enum LexerError {
    UnexpectedCharacter(char, usize),
    UnterminatedString(usize),
    /// A caller (typically the parser, via `next_token_expecting`) declared a
    /// set of acceptable next-token classes and the lexer found something
    /// outside that set. Carries what was actually found so the caller can
    /// report a precise diagnostic instead of a generic parse error.
    UnexpectedContinuation { found: TokenExpectation, expected: Vec<TokenExpectation>, position: usize },
    // Extend with more error types as needed
}

/// A coarse classification of "what kind of thing comes next", used to let a
/// caller (the parser, or in the future a user-defined grammar extension)
/// declare what it is willing to accept *before* the lexer commits to a
/// specific token. This is the seed of an expectation-driven lexer/parser
/// protocol: rather than the lexer unilaterally deciding token boundaries via
/// its own hard-coded lookahead, ambiguous positions (like a `.` that could be
/// a decimal point, a member-access operator, or a plain statement
/// terminator) can be resolved by asking "given what I'm expecting next, does
/// this character/token qualify?" and reporting a clear failure if not.
///
/// Today this is wired into the one place that already had a hand-rolled
/// version of this decision (integer-vs-decimal continuation, see
/// `next_token`'s number-lexing branch) and into the parser's member-access
/// (`.identifier`) handling. Extending it so the *parser* proactively drives
/// every token fetch with an explicit expected set (rather than the parser's
/// two-token lookahead buffer being filled unconstrained) is a larger,
/// follow-on architectural change — see `docs/plans/` for the write-up.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TokenExpectation {
    /// An ASCII digit — e.g. valid continuation of an integer/fraction.
    Digit,
    /// A literal '.' — decimal point or member-access/terminator dot.
    Dot,
    /// An arithmetic/comparison/logical operator character.
    Operator,
    /// Whitespace, a statement/expression terminator, or end of input —
    /// anything that legitimately ends a token run.
    Terminator,
    /// The start of an identifier or keyword (ASCII letter or `_`).
    Letter,
    /// No constraint — accept whatever the lexer produces. Used by every
    /// existing call site that doesn't (yet) participate in this protocol,
    /// so introducing it does not change behavior anywhere else.
    Any,
}

impl TokenExpectation {
    /// Classify a single lookahead character into its coarse expectation
    /// class. `None` represents end-of-input.
    fn classify_char(c: Option<char>) -> TokenExpectation {
        match c {
            None => TokenExpectation::Terminator,
            Some(c) if c.is_ascii_digit() => TokenExpectation::Digit,
            Some('.') => TokenExpectation::Dot,
            Some(c) if "+-*/%<>=!&|".contains(c) => TokenExpectation::Operator,
            Some(c) if c.is_whitespace() || matches!(c, ';' | ',' | ')' | ']' | '}') => TokenExpectation::Terminator,
            Some(c) if c.is_ascii_alphabetic() || c == '_' => TokenExpectation::Letter,
            Some(_) => TokenExpectation::Any,
        }
    }

    /// Classify an already-lexed `Token` into the same coarse vocabulary, so
    /// the parser can validate tokens it already holds (e.g. in its
    /// lookahead buffer) against an expected set using the same names.
    pub fn classify_token(tok: &Token) -> TokenExpectation {
        match tok {
            Token::Number(_) | Token::Float(_) => TokenExpectation::Digit,
            Token::Dot => TokenExpectation::Dot,
            Token::Plus | Token::Minus | Token::Star | Token::Slash | Token::Percent
            | Token::Equal | Token::EqualEqual | Token::NotEqual
            | Token::Greater | Token::GreaterEqual | Token::Less | Token::LessEqual
            | Token::And | Token::Or | Token::Not
            | Token::BAnd | Token::BOr | Token::BXor | Token::BNot | Token::Shl | Token::Shr => TokenExpectation::Operator,
            Token::Identifier(_) => TokenExpectation::Letter,
            Token::Newline | Token::EOF | Token::Semicolon | Token::Comma
            | Token::RParen | Token::RBracket | Token::BlockEnd => TokenExpectation::Terminator,
            _ => TokenExpectation::Any,
        }
    }
}

macro_rules! lex_debug {
    ($($arg:tt)*) => {{
        if std::env::var("PATLANG_LEXER_DEBUG").map(|v| v == "1").unwrap_or(false) {
            eprintln!($($arg)*);
        }
    }};
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        lex_debug!("[DEBUG] Lexer::new called with input:\n{}", input);
        // Tolerate (strip) a leading UTF-8 byte-order mark -- common,
        // harmless, and written by default by several widespread tools
        // (e.g. .NET's `System.Text.Encoding.UTF8`/File.WriteAllText).
        // Without this, since the lexer works over raw bytes rather than
        // decoded chars for structural scanning, the BOM's first byte
        // hit the "unrecognized character" fallback below -- see that
        // fallback's own comment for what that used to silently do.
        let input = input.strip_prefix('\u{FEFF}').unwrap_or(input);
        Lexer { input, position: 0 }
    }

    /// Fetch the next token with no constraint on what it may be — the
    /// existing, unconstrained entry point used by the vast majority of the
    /// parser, preserved unchanged for backward compatibility.
    pub fn next_token(&mut self) -> Result<Token, LexerError> {
        self.next_token_expecting(&[])
    }

    /// Fetch the next token, optionally validating it against a declared set
    /// of acceptable coarse classes (`expected`). An empty `expected` slice
    /// means "accept anything" (equivalent to plain `next_token`).
    ///
    /// This is the entry point for the expectation-driven protocol: a caller
    /// that knows, from grammar context, what kind of thing must come next
    /// (e.g. "an identifier after this '.'", or internally, "a digit or a
    /// decimal point after this integer run") can pass that expectation in
    /// and get back either a matching token or a precise
    /// `LexerError::UnexpectedContinuation` naming what was actually found.
    pub fn next_token_expecting(&mut self, expected: &[TokenExpectation]) -> Result<Token, LexerError> {
        let tok = self.next_token_unconstrained()?;
        if !expected.is_empty() {
            let found = TokenExpectation::classify_token(&tok);
            if !expected.contains(&found) && !expected.contains(&TokenExpectation::Any) {
                return Err(LexerError::UnexpectedContinuation {
                    found,
                    expected: expected.to_vec(),
                    position: self.position,
                });
            }
        }
        Ok(tok)
    }

    fn next_token_unconstrained(&mut self) -> Result<Token, LexerError> {
        let bytes = self.input.as_bytes();
        let len = bytes.len();
        while self.position < len {
            let c = bytes[self.position] as char;
            lex_debug!("[DEBUG][lexer] At position {}: char {:?}", self.position, c);

            // Recognize '.' as Dot token
            if c == '.' {
                self.position += 1;
                return Ok(Token::Dot);
            }
            // Recognize ':-' (rule turnstile) or standalone ':' (Colon)
            if c == ':' {
                if self.position + 1 < len && bytes[self.position + 1] as char == '-' {
                    self.position += 2;
                    return Ok(Token::Turnstile);
                } else {
                    self.position += 1;
                    return Ok(Token::Colon);
                }
            }
            // Recognize pipeline '|>' or standalone '|'
            if c == '|' {
                if self.position + 1 < len && bytes[self.position + 1] as char == '>' {
                    self.position += 2;
                    return Ok(Token::PipeGreater);
                } else {
                    self.position += 1;
                    return Ok(Token::Pipe);
                }
            }
            // Recognize '[' and ']'
            if c == '[' {
                self.position += 1;
                return Ok(Token::LBracket);
            }
            if c == ']' {
                self.position += 1;
                return Ok(Token::RBracket);
            }
            // Newline as statement separator
            if c == '\n' {
                self.position += 1;
                lex_debug!("[DEBUG][lexer] Returning Token::Newline");
                return Ok(Token::Newline);
            }
            // Skip whitespace (except newline)
            if c.is_whitespace() && c != '\n' {
                self.position += 1;
                continue;
            }
            // Skip comments
            if c == '#' {
                while self.position < len && bytes[self.position] as char != '\n' {
                    self.position += 1;
                }
                continue;
            }
            // Numbers: integer part, optionally followed by a decimal point and
            // fractional digits (e.g. `42`, `3.14`). This is the concrete
            // worked example of the expectation-driven disambiguation
            // described on `TokenExpectation`: after the integer run, the
            // only two classes of continuation we're willing to accept as
            // "still part of this literal" are (a) a '.' immediately
            // followed by a digit (decimal point) or (b) nothing — anything
            // else (an operator, a letter, a lone '.' not followed by a
            // digit, whitespace/terminator) ends the literal here and is
            // left untouched for the *next* call to `next_token` to
            // classify on its own. This is what makes `2.34.to_s` lex as
            // Number(2.34), Dot, Identifier("to_s") rather than greedily
            // misreading the second '.' as another decimal point.
            if c.is_ascii_digit() {
                let start = self.position;
                while self.position < len && (bytes[self.position] as char).is_ascii_digit() {
                    self.position += 1;
                }
                let next_class = TokenExpectation::classify_char(bytes.get(self.position).map(|b| *b as char));
                let after_next_class = TokenExpectation::classify_char(bytes.get(self.position + 1).map(|b| *b as char));
                let mut is_float = false;
                if next_class == TokenExpectation::Dot && after_next_class == TokenExpectation::Digit {
                    // '.' followed by a digit: consume it and the fractional digits.
                    is_float = true;
                    self.position += 1;
                    while self.position < len && (bytes[self.position] as char).is_ascii_digit() {
                        self.position += 1;
                    }
                }
                // Any other next_class (Dot-not-followed-by-digit, Letter,
                // Operator, Terminator) is not a valid numeric continuation —
                // stop here and let the next `next_token` call classify it.
                let num_str = &self.input[start..self.position];
                let num = num_str.parse::<f64>().unwrap_or(0.0);
                if is_float {
                    lex_debug!("[DEBUG][lexer] Returning Token::Float({})", num);
                    return Ok(Token::Float(num));
                }
                lex_debug!("[DEBUG][lexer] Returning Token::Number({})", num);
                return Ok(Token::Number(num));
            }
            // Identifiers and keywords (allow trailing '?' like any?)
        if c.is_ascii_alphabetic() || c == '_' {
                let start = self.position;
                self.position += 1;
                while self.position < len {
                    let nc = bytes[self.position] as char;
            if nc.is_ascii_alphanumeric() || nc == '_' || nc == '?' {
                        self.position += 1;
                    } else {
                        break;
                    }
                }
                let ident = &self.input[start..self.position];
                lex_debug!("[DEBUG][lexer] Returning Token::Identifier({})", ident);
                return Ok(match ident {
                    "let" => Token::Let,
                    "fn" => Token::Fn,
                    "return" => Token::Return,
                    "if" => Token::If,
                    "while" => Token::While,
                    "else" => Token::Else,
                    "elif" => Token::Elif,
                    "goal" => Token::Goal,
                    "rule" => Token::Rule,
                    "and" => Token::And,
                    "or" => Token::Or,
                    "not" => Token::Not,
                    "band" => Token::BAnd,
                    "bor" => Token::BOr,
                    "bxor" => Token::BXor,
                    "bnot" => Token::BNot,
                    "shl" => Token::Shl,
                    "shr" => Token::Shr,
                    "true" | "false" => Token::Identifier(ident.to_string()), // treat as identifier for now
                    "print" => Token::Identifier(ident.to_string()),
                    _ => Token::Identifier(ident.to_string()),
                });
            }
            // Block delimiters (for future use, e.g. '{' and '}')
            if c == '{' {
                self.position += 1;
                return Ok(Token::BlockStart);
            }
            if c == '}' {
                self.position += 1;
                return Ok(Token::BlockEnd);
            }
            // String literals with standard escapes: \" \\ \n \t \r
            if c == '"' {
                self.position += 1;
                let mut s = String::new();
                while self.position < len && bytes[self.position] as char != '"' {
                    let ch = bytes[self.position] as char;
                    if ch == '\\' && self.position + 1 < len {
                        let esc = bytes[self.position + 1] as char;
                        let decoded = match esc {
                            'n' => Some('\n'),
                            't' => Some('\t'),
                            'r' => Some('\r'),
                            '"' => Some('"'),
                            '\\' => Some('\\'),
                            _ => None,
                        };
                        if let Some(d) = decoded {
                            s.push(d);
                            self.position += 2;
                            continue;
                        }
                    }
                    s.push(ch);
                    self.position += 1;
                }
                if self.position < len && bytes[self.position] as char == '"' {
                    self.position += 1;
                    lex_debug!("[DEBUG][lexer] Returning Token::String({})", s);
                    return Ok(Token::String(s));
                } else {
                    return Err(LexerError::UnterminatedString(self.position));
                }
            }
            // Operators and parens
            self.position += 1;
            let token = match c {
                '+' => Token::Plus,
                '-' => Token::Minus,
                '*' => Token::Star,
                '/' => Token::Slash,
                '%' => Token::Percent,
                '(' => Token::LParen,
                ')' => Token::RParen,
                ',' => Token::Comma,
                ';' => Token::Semicolon,
                '=' => {
                    // Check for ==
                    if self.position < len && bytes[self.position] as char == '=' {
                        self.position += 1;
                        Token::EqualEqual
                    } else {
                        Token::Equal
                    }
                },
                '>' => {
                    // Check for >=
                    if self.position < len && bytes[self.position] as char == '=' {
                        self.position += 1;
                        Token::GreaterEqual
                    } else {
                        Token::Greater
                    }
                },
                '<' => {
                    // Check for <=
                    if self.position < len && bytes[self.position] as char == '=' {
                        self.position += 1;
                        Token::LessEqual
                    } else {
                        Token::Less
                    }
                },
                '!' => {
                    // Check for !=; bare '!' is logical not
                    if self.position < len && bytes[self.position] as char == '=' {
                        self.position += 1;
                        Token::NotEqual
                    } else {
                        Token::Not
                    }
                },
                // A genuinely unrecognized byte (not matched by any case
                // above) used to silently become Token::EOF -- meaning the
                // lexer treated the REST OF THE FILE as if it didn't exist,
                // with no error at all, rather than reporting what actually
                // went wrong. Confirmed as a real, silent-failure bug: a
                // leading UTF-8 BOM (bytes EF BB BF, e.g. written by
                // `System.Text.Encoding.UTF8` in .NET's File.WriteAllText,
                // the exact case that surfaced this) made an entire program
                // silently execute as empty -- exit code 0, zero output, no
                // error anywhere, for a file that visibly contained real
                // code. `self.position` was already advanced past this byte
                // above, so it's reported as the position that was actually
                // consumed.
                _ => return Err(LexerError::UnexpectedCharacter(c, self.position - 1)),
            };
            lex_debug!("[DEBUG][lexer] Returning {:?}", token);
            return Ok(token);
        }
        lex_debug!("[DEBUG][lexer] Returning Token::EOF");
        Ok(Token::EOF)
    }
}