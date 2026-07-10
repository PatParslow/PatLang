//! Source-to-source preprocessor for user-defined `syntax NAME { ... }` DSL
//! blocks, in the same spirit as `preprocess::expand_includes`: it runs on
//! the raw source text *before* the normal Lexer/Parser pipeline, so no
//! change to the core Lexer/Parser is required to support it.
//!
//! A PatLang program may declare a small grammar extension inline:
//!
//! ```text
//! syntax RouterDSL {
//!     trigger: Keyword("routes");
//!     tokens {
//!         HttpVerb(verb) = regex("\b(GET|POST|PUT|DELETE)\b", verb);
//!         UrlPath(path)   = regex("\/[a-zA-Z0-9_\/:-]*", path);
//!         Arrow           = "->";
//!     }
//!     rule RouteLine {
//!         let verb = expect HttpVerb;
//!         let path = expect UrlPath;
//!         expect Arrow;
//!         let controller = expect Identifier;
//!         expect Symbol(".");
//!         let action = expect Identifier;
//!         return AST.RegisterRoute(verb, path, controller, action);
//!     }
//! }
//! ```
//!
//! ...and then use it:
//!
//! ```text
//! routes {
//!     GET  /users          -> UserController.index
//! }
//! ```
//!
//! The `syntax { ... }` block itself is stripped from the source. Every
//! `routes { ... }` block (its trigger keyword) is expanded line-by-line into
//! plain PatLang statements built from the rule's `return` template, with
//! `expect`-bound captures substituted in as string literals, before the
//! normal Lexer/Parser ever sees the file.
//!
//! Per-token pattern matching (the `regex(...)` token definitions) is
//! performed by the actual general-purpose regex engine written in PatLang
//! itself (`self_hosting/lib/regex.patlang`), run through the ordinary
//! Parser/Lowerer/Interpreter pipeline via `Interpreter::call_function` —
//! not by any Rust-native string-matching logic. This keeps the matching
//! *logic* itself part of the self-hosting language, consistent with
//! PatLang's goal of not depending on Rust-only pattern-matching features.

use crate::ir::{Interpreter, Lowerer, Value};
use crate::ir::hosts::register_stage0_shims;
use crate::parser::Parser;
use std::collections::HashMap;

/// The PatLang regex engine, loaded once and reused for every token match
/// across every DSL block in a source file.
pub struct RegexEngine {
    program: crate::ir::Program,
    interp: Interpreter,
}

impl RegexEngine {
    pub fn load() -> Result<Self, String> {
        const SRC: &str = include_str!("../../self_hosting/lib/regex.patlang");
        let mut p = Parser::new(SRC).map_err(|e| format!("regex engine parse init error: {:?}", e))?;
        let ast = p.parse().map_err(|e| format!("regex engine parse error: {:?}", e))?;
        let mut lower = Lowerer::new();
        let program = lower.lower_program_basic(&ast);
        let mut interp = Interpreter::new();
        register_stage0_shims(&mut interp);
        Ok(RegexEngine { program, interp })
    }

    /// Returns the end position of a match anchored exactly at `start`, or
    /// `None` if the pattern does not match there.
    pub fn match_at(&self, pattern: &str, text: &str, start: usize) -> Result<Option<usize>, String> {
        let args = [
            Value::String(pattern.to_string()),
            Value::String(text.to_string()),
            Value::Number(start as f64),
        ];
        match self.interp.call_function(&self.program, "regex_match_string_at", &args)? {
            Value::Number(n) if n >= 0.0 => Ok(Some(n as usize)),
            _ => Ok(None),
        }
    }
}

#[derive(Debug, Clone)]
enum TokenPattern {
    Regex(String),
    Literal(String),
}

#[derive(Debug, Clone)]
struct TokenDef {
    name: String,
    binding_hint: Option<String>,
    pattern: TokenPattern,
}

#[derive(Debug, Clone)]
enum ExpectToken {
    /// One of the DSL's own declared `tokens { ... }` names.
    Named(String),
    /// Built-in identifier matcher: `[A-Za-z_][A-Za-z0-9_]*`.
    Identifier,
    /// A literal symbol, e.g. `Symbol(".")`.
    Symbol(String),
}

#[derive(Debug, Clone)]
struct RuleStep {
    token: ExpectToken,
    bind: Option<String>,
}

#[derive(Debug, Clone)]
struct RuleDef {
    steps: Vec<RuleStep>,
    return_template: String,
}

#[derive(Debug, Clone)]
struct SyntaxDef {
    trigger_keyword: String,
    tokens: Vec<TokenDef>,
    rules: Vec<RuleDef>,
}

/// Expand every `syntax NAME { ... }` definition and every triggered block in
/// `src`, using `regex` to evaluate any `regex(...)`-declared token pattern.
pub fn expand_syntax_dsls(src: &str, regex: &RegexEngine) -> Result<String, String> {
    let (stripped, defs) = extract_syntax_defs(src)?;
    if defs.is_empty() {
        return Ok(stripped);
    }
    expand_trigger_blocks(&stripped, &defs, regex)
}

// ---------------------------------------------------------------------
// Pass 1: find and remove `syntax NAME { ... }` blocks, building a registry
// keyed by each definition's trigger keyword.
// ---------------------------------------------------------------------

fn extract_syntax_defs(src: &str) -> Result<(String, HashMap<String, SyntaxDef>), String> {
    let chars: Vec<char> = src.chars().collect();
    let mut out = String::with_capacity(src.len());
    let mut defs: HashMap<String, SyntaxDef> = HashMap::new();
    let mut i = 0usize;
    let mut in_string = false;
    while i < chars.len() {
        if in_string {
            out.push(chars[i]);
            if chars[i] == '\\' && i + 1 < chars.len() {
                out.push(chars[i + 1]);
                i += 2;
                continue;
            }
            if chars[i] == '"' { in_string = false; }
            i += 1;
            continue;
        }
        if chars[i] == '"' {
            in_string = true;
            out.push(chars[i]);
            i += 1;
            continue;
        }
        // Skip whole-line comments verbatim so a stray "syntax" mentioned in
        // prose (e.g. "block syntax") never gets misread as a definition.
        if chars[i] == '#' {
            while i < chars.len() && chars[i] != '\n' {
                out.push(chars[i]);
                i += 1;
            }
            continue;
        }
        if starts_keyword_at(&chars, i, "syntax") {
            let j = skip_ws(&chars, i + "syntax".len());
            // Only treat this as a real `syntax NAME { ... }` definition if
            // it's actually followed by a name and a '{' — otherwise it's
            // just the English word appearing in code/comments/strings, and
            // should pass through unchanged rather than hard-erroring.
            if let Some((_name, after_name)) = take_identifier(&chars, j) {
                let after_name = skip_ws(&chars, after_name);
                if after_name < chars.len() && chars[after_name] == '{' {
                    let (body, after_block) = take_balanced_block(&chars, after_name)?;
                    let def = parse_syntax_def(&body)?;
                    defs.insert(def.trigger_keyword.clone(), def);
                    i = after_block;
                    continue;
                }
            }
        }
        out.push(chars[i]);
        i += 1;
    }
    Ok((out, defs))
}

fn parse_syntax_def(body: &str) -> Result<SyntaxDef, String> {
    let mut trigger_keyword: Option<String> = None;
    let mut tokens: Vec<TokenDef> = Vec::new();
    let mut rules: Vec<RuleDef> = Vec::new();

    let chars: Vec<char> = body.chars().collect();
    let mut i = 0usize;
    while i < chars.len() {
        i = skip_ws_and_comments(&chars, i);
        if i >= chars.len() { break; }
        if starts_keyword_at(&chars, i, "trigger") {
            let semi = find_char(&chars, i, ';').ok_or_else(|| "syntax_dsl: unterminated trigger:".to_string())?;
            let stmt: String = chars[i..semi].iter().collect();
            trigger_keyword = Some(parse_trigger_stmt(&stmt)?);
            i = semi + 1;
        } else if starts_keyword_at(&chars, i, "tokens") {
            let mut j = i + "tokens".len();
            j = skip_ws(&chars, j);
            if j >= chars.len() || chars[j] != '{' {
                return Err("syntax_dsl: expected '{' after 'tokens'".to_string());
            }
            let (tbody, after) = take_balanced_block(&chars, j)?;
            tokens = parse_token_defs(&tbody)?;
            i = after;
        } else if starts_keyword_at(&chars, i, "rule") {
            let mut j = i + "rule".len();
            j = skip_ws(&chars, j);
            let (_rname, after_name) = take_identifier(&chars, j)
                .ok_or_else(|| "syntax_dsl: expected a name after 'rule'".to_string())?;
            j = skip_ws(&chars, after_name);
            if j >= chars.len() || chars[j] != '{' {
                return Err("syntax_dsl: expected '{' after rule name".to_string());
            }
            let (rbody, after) = take_balanced_block(&chars, j)?;
            rules.push(parse_rule_def(&rbody)?);
            i = after;
        } else {
            // Unknown top-level content inside `syntax {}`: skip one char at a
            // time rather than failing hard, so stray whitespace/comments
            // between recognized sections don't need special-casing here.
            i += 1;
        }
    }

    let trigger_keyword = trigger_keyword.ok_or_else(|| "syntax_dsl: missing 'trigger: Keyword(\"...\")' declaration".to_string())?;
    if rules.is_empty() {
        return Err("syntax_dsl: a syntax definition needs at least one 'rule { ... }' block".to_string());
    }
    Ok(SyntaxDef { trigger_keyword, tokens, rules })
}

fn parse_trigger_stmt(stmt: &str) -> Result<String, String> {
    // trigger: Keyword("routes")
    let rest = stmt.trim().strip_prefix("trigger").unwrap_or(stmt).trim();
    let rest = rest.strip_prefix(':').ok_or_else(|| "syntax_dsl: expected ':' after 'trigger'".to_string())?.trim();
    let rest = rest.strip_prefix("Keyword").ok_or_else(|| "syntax_dsl: expected 'Keyword(\"...\")' in trigger".to_string())?.trim();
    let inner = rest.strip_prefix('(').and_then(|s| s.strip_suffix(')')).ok_or_else(|| "syntax_dsl: malformed 'Keyword(...)' in trigger".to_string())?;
    Ok(unquote(inner.trim())?)
}

fn parse_token_defs(body: &str) -> Result<Vec<TokenDef>, String> {
    let mut out = Vec::new();
    for stmt in split_top_level_statements(body) {
        let stmt = stmt.trim();
        if stmt.is_empty() { continue; }
        // Name(binding) = regex("pattern", binding);   OR   Name = "literal";
        let eq = stmt.find('=').ok_or_else(|| format!("syntax_dsl: malformed token definition: {}", stmt))?;
        let lhs = stmt[..eq].trim();
        let rhs = stmt[eq + 1..].trim();
        let (name, binding_hint) = if let Some(op) = lhs.find('(') {
            let name = lhs[..op].trim().to_string();
            let binding = lhs[op + 1..].trim_end_matches(')').trim().to_string();
            (name, if binding.is_empty() { None } else { Some(binding) })
        } else {
            (lhs.to_string(), None)
        };
        let pattern = if let Some(inner) = rhs.strip_prefix("regex").map(|s| s.trim()) {
            let inner = inner.strip_prefix('(').and_then(|s| s.strip_suffix(')'))
                .ok_or_else(|| format!("syntax_dsl: malformed regex(...) in token '{}': {}", name, rhs))?;
            // regex("pattern", binding) — we only need the pattern string;
            // the second argument is just documentation of the capture name.
            let pat_str = inner.splitn(2, ',').next().unwrap_or("").trim();
            TokenPattern::Regex(unquote(pat_str)?)
        } else {
            TokenPattern::Literal(unquote(rhs)?)
        };
        out.push(TokenDef { name, binding_hint, pattern });
    }
    Ok(out)
}

fn parse_rule_def(body: &str) -> Result<RuleDef, String> {
    let mut steps = Vec::new();
    let mut return_template = String::new();
    for stmt in split_top_level_statements(body) {
        let stmt = stmt.trim();
        if stmt.is_empty() { continue; }
        if let Some(rest) = stmt.strip_prefix("return") {
            return_template = rest.trim().to_string();
            continue;
        }
        // let NAME = expect TOKEN;   OR   expect TOKEN;
        let (bind, expect_part) = if let Some(rest) = stmt.strip_prefix("let") {
            let rest = rest.trim();
            let eq = rest.find('=').ok_or_else(|| format!("syntax_dsl: malformed 'let' step: {}", stmt))?;
            let name = rest[..eq].trim().to_string();
            (Some(name), rest[eq + 1..].trim().to_string())
        } else {
            (None, stmt.to_string())
        };
        let expect_part = expect_part.strip_prefix("expect")
            .ok_or_else(|| format!("syntax_dsl: expected 'expect' in rule step: {}", stmt))?
            .trim();
        let token = if let Some(inner) = expect_part.strip_prefix("Symbol").map(|s| s.trim()) {
            let inner = inner.strip_prefix('(').and_then(|s| s.strip_suffix(')'))
                .ok_or_else(|| format!("syntax_dsl: malformed Symbol(...) in: {}", stmt))?;
            ExpectToken::Symbol(unquote(inner.trim())?)
        } else if expect_part == "Identifier" {
            ExpectToken::Identifier
        } else {
            ExpectToken::Named(expect_part.to_string())
        };
        steps.push(RuleStep { token, bind });
    }
    if return_template.is_empty() {
        return Err("syntax_dsl: rule is missing a 'return <template>;' statement".to_string());
    }
    Ok(RuleDef { steps, return_template })
}

// ---------------------------------------------------------------------
// Pass 2: expand every `<trigger keyword> { ... }` block found in the
// (already syntax-def-stripped) source.
// ---------------------------------------------------------------------

fn expand_trigger_blocks(src: &str, defs: &HashMap<String, SyntaxDef>, regex: &RegexEngine) -> Result<String, String> {
    let chars: Vec<char> = src.chars().collect();
    let mut out = String::with_capacity(src.len());
    let mut i = 0usize;
    while i < chars.len() {
        let mut matched_keyword: Option<&str> = None;
        for kw in defs.keys() {
            if starts_keyword_at(&chars, i, kw) {
                matched_keyword = Some(kw.as_str());
                break;
            }
        }
        if let Some(kw) = matched_keyword {
            let def = &defs[kw];
            let mut j = i + kw.len();
            j = skip_ws(&chars, j);
            if j < chars.len() && chars[j] == '{' {
                let (body, after_block) = take_balanced_block(&chars, j)?;
                for line in body.lines() {
                    let line = line.trim();
                    if line.is_empty() { continue; }
                    let expanded = expand_rule_line(def, line, regex)?;
                    out.push_str(&expanded);
                    out.push('\n');
                }
                i = after_block;
                continue;
            }
        }
        out.push(chars[i]);
        i += 1;
    }
    Ok(out)
}

/// Runs each of the DSL's rules (in declaration order) against `line`,
/// returning the first one whose full `expect` sequence matches, with its
/// return template's captures substituted in as PatLang string literals.
fn expand_rule_line(def: &SyntaxDef, line: &str, regex: &RegexEngine) -> Result<String, String> {
    for rule in &def.rules {
        if let Some(bindings) = try_match_rule(def, rule, line, regex)? {
            return Ok(substitute_template(&rule.return_template, &bindings) + ";");
        }
    }
    Err(format!("syntax_dsl: no rule for trigger '{}' matched line: {}", def.trigger_keyword, line))
}

fn try_match_rule(def: &SyntaxDef, rule: &RuleDef, line: &str, regex: &RegexEngine) -> Result<Option<HashMap<String, String>>, String> {
    let chars: Vec<char> = line.chars().collect();
    let mut pos = 0usize;
    let mut bindings: HashMap<String, String> = HashMap::new();
    for step in &rule.steps {
        pos = skip_ws(&chars, pos);
        let matched = match &step.token {
            ExpectToken::Identifier => match_builtin_identifier(&chars, pos),
            ExpectToken::Symbol(sym) => match_literal(&chars, pos, sym),
            ExpectToken::Named(name) => {
                let tdef = def.tokens.iter().find(|t| &t.name == name)
                    .ok_or_else(|| format!("syntax_dsl: rule references undeclared token '{}'", name))?;
                match &tdef.pattern {
                    TokenPattern::Literal(lit) => match_literal(&chars, pos, lit),
                    TokenPattern::Regex(pat) => {
                        let text: String = chars[pos..].iter().collect();
                        match regex.match_at(pat, &text, 0)? {
                            Some(end) if end > 0 => Some(pos + end),
                            _ => None,
                        }
                    }
                }
            }
        };
        let Some(end) = matched else { return Ok(None) };
        if let Some(name) = &step.bind {
            let text: String = chars[pos..end].iter().collect();
            bindings.insert(name.clone(), text);
        }
        pos = end;
    }
    Ok(Some(bindings))
}

fn match_literal(chars: &[char], pos: usize, lit: &str) -> Option<usize> {
    let lit_chars: Vec<char> = lit.chars().collect();
    if pos + lit_chars.len() > chars.len() { return None; }
    if chars[pos..pos + lit_chars.len()] == lit_chars[..] { Some(pos + lit_chars.len()) } else { None }
}

fn match_builtin_identifier(chars: &[char], pos: usize) -> Option<usize> {
    if pos >= chars.len() { return None; }
    let c0 = chars[pos];
    if !(c0.is_ascii_alphabetic() || c0 == '_') { return None; }
    let mut end = pos + 1;
    while end < chars.len() && (chars[end].is_ascii_alphanumeric() || chars[end] == '_') { end += 1; }
    Some(end)
}

/// Replaces every whole-word occurrence of a bound capture name in
/// `template` with its matched text as a PatLang string literal. This is
/// plain text substitution over the definition's own `return` template (part
/// of the preprocessor's own bookkeeping, like `expand_includes`'s path
/// splicing) — not the pattern-matching step the regex engine is for.
fn substitute_template(template: &str, bindings: &HashMap<String, String>) -> String {
    let chars: Vec<char> = template.chars().collect();
    let mut out = String::with_capacity(template.len());
    let mut i = 0usize;
    while i < chars.len() {
        if chars[i].is_ascii_alphabetic() || chars[i] == '_' {
            let start = i;
            let mut end = i + 1;
            while end < chars.len() && (chars[end].is_ascii_alphanumeric() || chars[end] == '_') { end += 1; }
            let word: String = chars[start..end].iter().collect();
            if let Some(val) = bindings.get(&word) {
                out.push('"');
                out.push_str(&val.replace('\\', "\\\\").replace('"', "\\\""));
                out.push('"');
            } else {
                out.push_str(&word);
            }
            i = end;
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

fn unquote(s: &str) -> Result<String, String> {
    let s = s.trim();
    let s = s.strip_prefix('"').and_then(|s| s.strip_suffix('"'))
        .ok_or_else(|| format!("syntax_dsl: expected a quoted string, got: {}", s))?;
    Ok(s.to_string())
}

fn skip_ws(chars: &[char], mut i: usize) -> usize {
    while i < chars.len() && chars[i].is_whitespace() { i += 1; }
    i
}

fn skip_ws_and_comments(chars: &[char], mut i: usize) -> usize {
    loop {
        i = skip_ws(chars, i);
        if i < chars.len() && chars[i] == '#' {
            while i < chars.len() && chars[i] != '\n' { i += 1; }
            continue;
        }
        break;
    }
    i
}

fn find_char(chars: &[char], from: usize, target: char) -> Option<usize> {
    (from..chars.len()).find(|&k| chars[k] == target)
}

fn starts_keyword_at(chars: &[char], i: usize, keyword: &str) -> bool {
    let kw: Vec<char> = keyword.chars().collect();
    if i + kw.len() > chars.len() { return false; }
    if chars[i..i + kw.len()] != kw[..] { return false; }
    // must be a whole-word match: not preceded/followed by an identifier char
    if i > 0 {
        let p = chars[i - 1];
        if p.is_ascii_alphanumeric() || p == '_' { return false; }
    }
    let after = i + kw.len();
    if after < chars.len() {
        let n = chars[after];
        if n.is_ascii_alphanumeric() || n == '_' { return false; }
    }
    true
}

fn take_identifier(chars: &[char], i: usize) -> Option<(String, usize)> {
    if i >= chars.len() { return None; }
    if !(chars[i].is_ascii_alphabetic() || chars[i] == '_') { return None; }
    let start = i;
    let mut end = i + 1;
    while end < chars.len() && (chars[end].is_ascii_alphanumeric() || chars[end] == '_') { end += 1; }
    Some((chars[start..end].iter().collect(), end))
}

/// `chars[open_brace_pos]` must be `'{'`. Returns the block's inner text
/// (excluding the outer braces) and the index just past the matching `'}'`,
/// tracking string literals so braces inside `"..."` don't confuse the
/// balance count.
fn take_balanced_block(chars: &[char], open_brace_pos: usize) -> Result<(String, usize), String> {
    let mut depth = 0i32;
    let mut i = open_brace_pos;
    let mut in_string = false;
    let start_inner = open_brace_pos + 1;
    while i < chars.len() {
        let c = chars[i];
        if in_string {
            if c == '\\' { i += 2; continue; }
            if c == '"' { in_string = false; }
            i += 1;
            continue;
        }
        match c {
            '"' => { in_string = true; }
            '{' => { depth += 1; }
            '}' => {
                depth -= 1;
                if depth == 0 {
                    let body: String = chars[start_inner..i].iter().collect();
                    return Ok((body, i + 1));
                }
            }
            _ => {}
        }
        i += 1;
    }
    Err("syntax_dsl: unbalanced '{' — missing closing '}'".to_string())
}

/// Splits a `syntax`/`rule`/`tokens` body into `;`-terminated statements,
/// respecting string literals and nested parens (so `regex("a;b", x)` isn't
/// split in the middle).
fn split_top_level_statements(body: &str) -> Vec<String> {
    let chars: Vec<char> = body.chars().collect();
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut depth = 0i32;
    let mut in_string = false;
    let mut i = 0usize;
    while i < chars.len() {
        let c = chars[i];
        if in_string {
            cur.push(c);
            if c == '\\' && i + 1 < chars.len() { cur.push(chars[i + 1]); i += 2; continue; }
            if c == '"' { in_string = false; }
            i += 1;
            continue;
        }
        match c {
            '"' => { in_string = true; cur.push(c); }
            '(' => { depth += 1; cur.push(c); }
            ')' => { depth -= 1; cur.push(c); }
            ';' if depth == 0 => { out.push(std::mem::take(&mut cur)); }
            _ => cur.push(c),
        }
        i += 1;
    }
    if !cur.trim().is_empty() { out.push(cur); }
    out
}
