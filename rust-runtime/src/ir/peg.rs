//! PEG grammar-file reader + interpreter (native side). Mirrors
//! self_hosting/lib/peg.patlang exactly (same algorithm, same .peg file,
//! same reserved-word list) -- see the "PEG shared-grammar validator"
//! plan for the full design rationale. Validation-only (accept/reject a
//! token stream against a .peg grammar file), not a parser replacement
//! and not AST construction.

use crate::lexer::{Lexer, Token};

/// Grammar-rule AST node (this module's own small AST, distinct from the
/// real PatLang program AST in ast.rs). Mirrors lib/peg.patlang's
/// ["Lit",...]/["Ref",...]/etc. node shapes.
#[derive(Debug, Clone)]
pub enum GExpr {
    Lit(String),
    Ref(String),
    Seq(Vec<GExpr>),
    Choice(Vec<GExpr>),
    Star(Box<GExpr>),
    Plus(Box<GExpr>),
    Opt(Box<GExpr>),
    And(Box<GExpr>),
    Not(Box<GExpr>),
}

pub type Ruleset = Vec<(String, GExpr)>;

// ---- .peg file tokenizer: a small, standalone lexer for the grammar
// format itself, not rust-runtime's own Lexer (the grammar file's own
// syntax -- quoted literals, <-, / * + ? & ! ( ) -- is a fixed, tiny
// format that doesn't need or want PatLang's own tokenization rules). ----

#[derive(Debug, Clone, PartialEq)]
enum GTok {
    Name(String),
    Lit(String),
    Arrow,
    Sym(char),
    Eof,
}

fn peg_tokenize(source: &str) -> Vec<GTok> {
    let chars: Vec<char> = source.chars().collect();
    let n = chars.len();
    let mut i = 0usize;
    let mut toks = Vec::new();
    while i < n {
        let c = chars[i];
        if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
            i += 1;
        } else if c == '#' {
            while i < n && chars[i] != '\n' {
                i += 1;
            }
        } else if c == '"' {
            let start = i + 1;
            let mut j = start;
            while j < n && chars[j] != '"' {
                j += 1;
            }
            toks.push(GTok::Lit(chars[start..j].iter().collect()));
            i = j + 1;
        } else if c.is_alphanumeric() || c == '_' {
            let start = i;
            while i < n && (chars[i].is_alphanumeric() || chars[i] == '_') {
                i += 1;
            }
            toks.push(GTok::Name(chars[start..i].iter().collect()));
        } else if c == '<' && i + 1 < n && chars[i + 1] == '-' {
            toks.push(GTok::Arrow);
            i += 2;
        } else {
            toks.push(GTok::Sym(c));
            i += 1;
        }
    }
    toks.push(GTok::Eof);
    toks
}

// ---- .peg file parser: builds GExpr trees. Standard PEG-of-PEG
// precedence: choice is loosest, then sequence, then prefix (&/!), then
// postfix (* + ?), then atom. ----

fn at_seq_stop(toks: &[GTok], pos: usize) -> bool {
    // A NAME immediately followed by Arrow is the NEXT rule's "Name <-"
    // header, not a Ref inside the current rule's body -- must be
    // checked with 2-token lookahead (see lib/peg.patlang's own
    // peg_at_seq_stop for why: without this, a multi-rule grammar file
    // hangs forever, the sequence parser overruns into the next rule and
    // gets stuck failing to parse a stray Arrow as an atom without ever
    // advancing).
    if let GTok::Name(_) = &toks[pos] {
        if matches!(toks.get(pos + 1), Some(GTok::Arrow)) {
            return true;
        }
    }
    matches!(toks[pos], GTok::Eof) || toks[pos] == GTok::Sym('/') || toks[pos] == GTok::Sym(')')
}

fn parse_atom(toks: &[GTok], pos: usize) -> (GExpr, usize) {
    match &toks[pos] {
        GTok::Lit(s) => (GExpr::Lit(s.clone()), pos + 1),
        GTok::Name(s) => (GExpr::Ref(s.clone()), pos + 1),
        GTok::Sym('(') => {
            let (inner, p2) = parse_choice(toks, pos + 1);
            if toks[p2] == GTok::Sym(')') {
                (inner, p2 + 1)
            } else {
                (GExpr::Seq(vec![]), p2)
            }
        }
        _ => (GExpr::Seq(vec![]), pos),
    }
}

fn parse_postfix(toks: &[GTok], pos: usize) -> (GExpr, usize) {
    let (node, p) = parse_atom(toks, pos);
    match toks[p] {
        GTok::Sym('*') => (GExpr::Star(Box::new(node)), p + 1),
        GTok::Sym('+') => (GExpr::Plus(Box::new(node)), p + 1),
        GTok::Sym('?') => (GExpr::Opt(Box::new(node)), p + 1),
        _ => (node, p),
    }
}

fn parse_prefix(toks: &[GTok], pos: usize) -> (GExpr, usize) {
    match toks[pos] {
        GTok::Sym('&') => {
            let (inner, p) = parse_postfix(toks, pos + 1);
            (GExpr::And(Box::new(inner)), p)
        }
        GTok::Sym('!') => {
            let (inner, p) = parse_postfix(toks, pos + 1);
            (GExpr::Not(Box::new(inner)), p)
        }
        _ => parse_postfix(toks, pos),
    }
}

fn parse_seq(toks: &[GTok], pos: usize) -> (GExpr, usize) {
    let mut items = Vec::new();
    let mut p = pos;
    while !at_seq_stop(toks, p) {
        let (item, p2) = parse_prefix(toks, p);
        items.push(item);
        p = p2;
    }
    if items.len() == 1 {
        (items.remove(0), p)
    } else {
        (GExpr::Seq(items), p)
    }
}

fn parse_choice(toks: &[GTok], pos: usize) -> (GExpr, usize) {
    let (first, mut p) = parse_seq(toks, pos);
    let mut items = vec![first];
    while toks[p] == GTok::Sym('/') {
        let (next, p2) = parse_seq(toks, p + 1);
        items.push(next);
        p = p2;
    }
    if items.len() == 1 {
        (items.remove(0), p)
    } else {
        (GExpr::Choice(items), p)
    }
}

/// Parses a full .peg file into a ruleset.
pub fn load_grammar(source: &str) -> Ruleset {
    let toks = peg_tokenize(source);
    let mut rules = Vec::new();
    let mut pos = 0usize;
    while toks[pos] != GTok::Eof {
        let name = match &toks[pos] {
            GTok::Name(s) => s.clone(),
            _ => break,
        };
        // toks[pos+1] is the Arrow
        let (body, p2) = parse_choice(&toks, pos + 2);
        rules.push((name, body));
        pos = p2;
    }
    rules
}

fn find_rule<'a>(rules: &'a Ruleset, name: &str) -> Option<&'a GExpr> {
    rules.iter().find(|(n, _)| n == name).map(|(_, e)| e)
}

// ---- token adapter: native Token -> (category, text), matching the
// self-hosted lexer's own IDENT/OP/NUM/STR/NL/EOF vocabulary exactly, so
// the grammar file's terminals (written against that vocabulary) work
// unmodified against tokens from either lexer. ----

#[derive(Debug, Clone)]
struct PTok {
    category: &'static str,
    text: String,
}

fn adapt_token(t: &Token) -> PTok {
    let (category, text): (&'static str, String) = match t {
        Token::Number(_) | Token::Float(_) => ("NUM", String::new()),
        Token::String(s) => ("STR", s.clone()),
        Token::Identifier(s) => ("IDENT", s.clone()),
        Token::Plus => ("OP", "+".into()),
        Token::Minus => ("OP", "-".into()),
        Token::Star => ("OP", "*".into()),
        Token::Slash => ("OP", "/".into()),
        Token::Percent => ("OP", "%".into()),
        Token::LParen => ("OP", "(".into()),
        Token::RParen => ("OP", ")".into()),
        Token::Comma => ("OP", ",".into()),
        Token::Semicolon => ("OP", ";".into()),
        Token::Dot => ("OP", ".".into()),
        Token::Colon => ("OP", ":".into()),
        Token::Turnstile => ("OP", ":-".into()),
        Token::Pipe => ("OP", "|".into()),
        Token::PipeGreater => ("OP", "|>".into()),
        Token::LBracket => ("OP", "[".into()),
        Token::RBracket => ("OP", "]".into()),
        Token::Let => ("IDENT", "let".into()),
        Token::Fn => ("IDENT", "fn".into()),
        Token::Return => ("IDENT", "return".into()),
        Token::If => ("IDENT", "if".into()),
        Token::While => ("IDENT", "while".into()),
        Token::Else => ("IDENT", "else".into()),
        Token::Elif => ("IDENT", "elif".into()),
        Token::Equal => ("OP", "=".into()),
        Token::EqualEqual => ("OP", "==".into()),
        Token::NotEqual => ("OP", "!=".into()),
        Token::Greater => ("OP", ">".into()),
        Token::GreaterEqual => ("OP", ">=".into()),
        Token::Less => ("OP", "<".into()),
        Token::LessEqual => ("OP", "<=".into()),
        Token::And => ("IDENT", "and".into()),
        Token::Or => ("IDENT", "or".into()),
        Token::Not => ("IDENT", "not".into()),
        Token::BAnd => ("IDENT", "band".into()),
        Token::BOr => ("IDENT", "bor".into()),
        Token::BXor => ("IDENT", "bxor".into()),
        Token::BNot => ("IDENT", "bnot".into()),
        Token::Shl => ("IDENT", "shl".into()),
        Token::Shr => ("IDENT", "shr".into()),
        Token::Newline => ("NL", String::new()),
        Token::EOF => ("EOF", String::new()),
        Token::Goal => ("IDENT", "goal".into()),
        Token::Rule => ("IDENT", "rule".into()),
        Token::Class => ("IDENT", "class".into()),
        Token::BlockStart => ("OP", "{".into()),
        Token::BlockEnd => ("OP", "}".into()),
    };
    PTok { category, text }
}

fn tokenize_adapted(source: &str) -> Vec<PTok> {
    let mut lexer = Lexer::new(source);
    let mut out = Vec::new();
    loop {
        match lexer.next_token() {
            Ok(tok) => {
                let is_eof = matches!(tok, Token::EOF);
                out.push(adapt_token(&tok));
                if is_eof {
                    break;
                }
            }
            Err(_) => {
                // A lexer error means this input doesn't even tokenize --
                // treat as an immediate EOF-equivalent so match/accept
                // logic still terminates cleanly rather than panicking.
                out.push(PTok { category: "EOF", text: String::new() });
                break;
            }
        }
    }
    out
}

// ---- the interpreter: standard PEG match semantics, mirrors
// lib/peg.patlang's peg_match/_seq/_choice/_star exactly. Returns
// (new_pos, ok) -- ok is false and new_pos == pos on failure (never
// partially consumes on a failed match). ----

fn skip_nl(toks: &[PTok], pos: usize) -> usize {
    let mut p = pos;
    while toks[p].category == "NL" {
        p += 1;
    }
    p
}

fn is_alpha_lit(text: &str) -> bool {
    text.chars().next().map(|c| c.is_alphabetic()).unwrap_or(false)
}

fn match_lit(text: &str, toks: &[PTok], pos: usize) -> (usize, bool) {
    let pos = skip_nl(toks, pos);
    let category = if is_alpha_lit(text) { "IDENT" } else { "OP" };
    let t = &toks[pos];
    if t.category == category && t.text == text {
        (pos + 1, true)
    } else {
        (pos, false)
    }
}

fn match_class(toks: &[PTok], pos: usize, category: &str) -> (usize, bool) {
    let pos = skip_nl(toks, pos);
    if toks[pos].category == category {
        (pos + 1, true)
    } else {
        (pos, false)
    }
}

/// Deliberately narrow: only the words genuinely, globally reserved in
/// real PatLang (parser.patlang's parse_stmt only special-cases
/// let/if/while/make/return/when/rule/budgeted/require/ensure/assert --
/// confirmed by reading it directly). Must match lib/peg.patlang's
/// peg_is_keyword's list EXACTLY -- this list IS the thing being kept in
/// sync between the two engines; any drift here is exactly the class of
/// bug this whole exercise exists to catch.
const KEYWORDS: &[&str] = &[
    "let", "mut", "fn", "if", "elif", "else", "then", "do", "end", "while", "return", "or", "and",
    "not", "budgeted", "when", "require", "ensure", "assert", "function", "band", "bor", "bxor",
    "bnot", "shl", "shr",
];

fn is_keyword(text: &str) -> bool {
    KEYWORDS.contains(&text)
}

fn match_identifier(toks: &[PTok], pos: usize) -> (usize, bool) {
    let pos = skip_nl(toks, pos);
    let t = &toks[pos];
    if t.category == "IDENT" && !is_keyword(&t.text) {
        (pos + 1, true)
    } else {
        (pos, false)
    }
}

fn pmatch(rules: &Ruleset, expr: &GExpr, toks: &[PTok], pos: usize) -> (usize, bool) {
    match expr {
        GExpr::Lit(text) => match_lit(text, toks, pos),
        GExpr::Ref(name) => match name.as_str() {
            "Identifier" => match_identifier(toks, pos),
            "Number" => match_class(toks, pos, "NUM"),
            "String" => match_class(toks, pos, "STR"),
            _ => match find_rule(rules, name) {
                Some(sub) => pmatch(rules, sub, toks, pos),
                None => (pos, false),
            },
        },
        GExpr::Seq(items) => match_seq(rules, items, toks, pos),
        GExpr::Choice(items) => match_choice(rules, items, toks, pos),
        GExpr::Star(item) => match_star(rules, item, toks, pos),
        GExpr::Plus(item) => {
            let (p, ok) = pmatch(rules, item, toks, pos);
            if !ok {
                return (pos, false);
            }
            match_star(rules, item, toks, p)
        }
        GExpr::Opt(item) => {
            let (p, ok) = pmatch(rules, item, toks, pos);
            if ok { (p, true) } else { (pos, true) }
        }
        GExpr::And(item) => {
            let (_, ok) = pmatch(rules, item, toks, pos);
            (pos, ok)
        }
        GExpr::Not(item) => {
            let (_, ok) = pmatch(rules, item, toks, pos);
            (pos, !ok)
        }
    }
}

fn match_seq(rules: &Ruleset, items: &[GExpr], toks: &[PTok], pos: usize) -> (usize, bool) {
    let mut p = pos;
    for item in items {
        let (p2, ok) = pmatch(rules, item, toks, p);
        if !ok {
            return (pos, false);
        }
        p = p2;
    }
    (p, true)
}

fn match_choice(rules: &Ruleset, items: &[GExpr], toks: &[PTok], pos: usize) -> (usize, bool) {
    for item in items {
        let (p, ok) = pmatch(rules, item, toks, pos);
        if ok {
            return (p, true);
        }
    }
    (pos, false)
}

fn match_star(rules: &Ruleset, item: &GExpr, toks: &[PTok], pos: usize) -> (usize, bool) {
    let mut p = pos;
    loop {
        let (p2, ok) = pmatch(rules, item, toks, p);
        if ok && p2 > p {
            p = p2;
        } else {
            break;
        }
    }
    (p, true)
}

/// Top-level: does the whole token stream (up to EOF) conform to `start`?
pub fn accepts(rules: &Ruleset, start: &str, source: &str) -> bool {
    let toks = tokenize_adapted(source);
    let expr = match find_rule(rules, start) {
        Some(e) => e,
        None => return false,
    };
    let (p, ok) = pmatch(rules, expr, &toks, 0);
    if !ok {
        return false;
    }
    let final_pos = skip_nl(&toks, p);
    toks[final_pos].category == "EOF"
}
