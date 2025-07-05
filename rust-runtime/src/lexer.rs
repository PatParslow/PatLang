//! Patlang Lexer for Rust parser

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Number(f64),
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
    Let,
    Fn,
    Return,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Newline,
    EOF,
    // Patlang-specific tokens
    Goal,
    Rule,
    BlockStart, // e.g. '{'
    BlockEnd,   // e.g. '}'
    // Extend with more tokens as needed
}

#[derive(Debug)]
pub struct Lexer<'a> {
    input: &'a str,
    position: usize,
    // Add more fields as needed
}

#[derive(Debug)]
pub enum LexerError {
    UnexpectedCharacter(char, usize),
    UnterminatedString(usize),
    // Extend with more error types as needed
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        println!("[DEBUG] Lexer::new called with input:\n{}", input);
        Lexer { input, position: 0 }
    }

    pub fn next_token(&mut self) -> Result<Token, LexerError> {
        let bytes = self.input.as_bytes();
        let len = bytes.len();
        while self.position < len {
            let c = bytes[self.position] as char;
            println!("[DEBUG][lexer] At position {}: char {:?}", self.position, c);
            // Newline as statement separator
            if c == '\n' {
                self.position += 1;
                println!("[DEBUG][lexer] Returning Token::Newline");
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
            // Numbers (integer only for now)
            if c.is_ascii_digit() {
                let start = self.position;
                while self.position < len && (bytes[self.position] as char).is_ascii_digit() {
                    self.position += 1;
                }
                let num_str = &self.input[start..self.position];
                let num = num_str.parse::<f64>().unwrap_or(0.0);
                println!("[DEBUG][lexer] Returning Token::Number({})", num);
                return Ok(Token::Number(num));
            }
            // Identifiers and keywords
            if c.is_ascii_alphabetic() || c == '_' {
                let start = self.position;
                self.position += 1;
                while self.position < len {
                    let nc = bytes[self.position] as char;
                    if nc.is_ascii_alphanumeric() || nc == '_' {
                        self.position += 1;
                    } else {
                        break;
                    }
                }
                let ident = &self.input[start..self.position];
                println!("[DEBUG][lexer] Returning Token::Identifier({})", ident);
                return Ok(match ident {
                    "let" => Token::Let,
                    "fn" => Token::Fn,
                    "return" => Token::Return,
                    "goal" => Token::Goal,
                    "rule" => Token::Rule,
                    "true" | "false" => Token::Identifier(ident.to_string()), // treat as identifier for now
                    "not" | "and" | "or" | "print" => Token::Identifier(ident.to_string()),
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
            // String literals
            if c == '"' {
                self.position += 1;
                let start = self.position;
                while self.position < len && bytes[self.position] as char != '"' {
                    // Handle escape sequences later
                    self.position += 1;
                }
                let s = &self.input[start..self.position];
                if self.position < len && bytes[self.position] as char == '"' {
                    self.position += 1;
                    println!("[DEBUG][lexer] Returning Token::String({})", s);
                    return Ok(Token::String(s.to_string()));
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
                _ => Token::EOF,
            };
            println!("[DEBUG][lexer] Returning {:?}", token);
            return Ok(token);
        }
        println!("[DEBUG][lexer] Returning Token::EOF");
        Ok(Token::EOF)
    }
}