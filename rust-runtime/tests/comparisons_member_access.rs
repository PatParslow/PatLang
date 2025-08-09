use patlang_runtime::parser::Parser;
use patlang_runtime::ast::{Expr, Stmt};

#[test]
fn parse_comparisons() {
    let src = "let a = 1 == 1\nlet b = 2 > 1\nlet c = 2 <= 3\n";
    let mut p = Parser::new(src).unwrap();
    let stmts = p.parse().unwrap();
    assert_eq!(stmts.len(), 3);
}

#[test]
fn parse_member_access_and_calls() {
    let src = "let x = obj.prop\nobj.method(1, 2)\n(obj.sub).call()\n";
    let mut p = Parser::new(src).unwrap();
    let stmts = p.parse().unwrap();
    assert_eq!(stmts.len(), 3);
    // Spot check the first statement shape
    match &stmts[0] { Stmt::Let { value, .. } => match value {
        Expr::Member { .. } => {},
        _ => panic!("expected member access"),
    }, _ => panic!("expected let") }
}
