//! Minimal Logic Programming Engine for Patlang Rust Runtime

use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum Term {
    Atom(String),
    Var(String),
}

#[derive(Debug, Clone)]
pub struct Fact {
    pub pred: String,
    pub args: Vec<Term>,
}

#[derive(Debug, Clone)]
pub struct Rule {
    pub head: Fact,
    pub body: Vec<Fact>,
}

#[derive(Debug, Clone)]
pub struct Query {
    pub pred: String,
    pub args: Vec<Term>,
}

#[derive(Debug, Clone)]
pub struct Substitution(pub HashMap<String, Term>);

impl Substitution {
    pub fn new() -> Self {
        Substitution(HashMap::new())
    }

    pub fn apply(&self, term: &Term) -> Term {
        match term {
            Term::Var(v) => self.0.get(v).cloned().unwrap_or(Term::Var(v.clone())),
            _ => term.clone(),
        }
    }

    pub fn extend(&mut self, var: &str, value: Term) {
        self.0.insert(var.to_string(), value);
    }
}

pub struct LogicEngine {
    facts: Vec<Fact>,
    rules: Vec<Rule>,
}

impl LogicEngine {
    pub fn new() -> Self {
        LogicEngine {
            facts: Vec::new(),
            rules: Vec::new(),
        }
    }

    pub fn add_fact(&mut self, fact: Fact) {
        self.facts.push(fact);
    }

    pub fn add_rule(&mut self, rule: Rule) {
        self.rules.push(rule);
    }

    pub fn query(&self, query: &Query) -> Vec<Substitution> {
        let mut results = Vec::new();
        for fact in &self.facts {
            if fact.pred == query.pred && fact.args.len() == query.args.len() {
                if let Some(subst) = unify_args(&fact.args, &query.args) {
                    results.push(subst);
                }
            }
        }
        // Minimal: rules not yet supported in query
        results
    }
}

// Unification for lists of terms
fn unify_args(fact_args: &[Term], query_args: &[Term]) -> Option<Substitution> {
    let mut subst = Substitution::new();
    for (f, q) in fact_args.iter().zip(query_args.iter()) {
        if !unify_terms(f, q, &mut subst) {
            return None;
        }
    }
    Some(subst)
}

// Unification for two terms
fn unify_terms(f: &Term, q: &Term, subst: &mut Substitution) -> bool {
    match (f, q) {
        (Term::Atom(a), Term::Atom(b)) => a == b,
        (Term::Var(v), t) | (t, Term::Var(v)) => {
            subst.extend(v, t.clone());
            true
        }
    }
}