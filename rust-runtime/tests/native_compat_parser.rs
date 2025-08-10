use patlang_runtime::parser::Parser;

#[test]
fn parses_ruby_like_if_then_else_end() {
    let src = r#"
if true then
  1
else
  2
end
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should accept Ruby-like if/then/else/end, got {:?}", ast);
}

#[test]
fn tolerates_label_lines_with_colon() {
    let src = r#"
precondition:
  1
postcondition:
  2
strategy:
  3
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should skip label lines, got {:?}", ast);
}

#[test]
fn tolerates_goal_rule_fact_constructs() {
    let src = r#"
Goal EnsureParsingStability.
Rule A -> B.
fact something(true).
1
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should tolerate Goal/Rule/fact lines, got {:?}", ast);
}

#[test]
fn parses_inline_make_function_block() {
    let src = r#"
make a function called greet takes name returns result
  result = "Hello, #{name}!"
end
greet("Pat")
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should handle inline make-function, got {:?}", ast);
}

#[test]
fn parses_postfix_brace_block_as_closure() {
    let src = r#"
[1,2,3].map { |x| x }
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should accept postfix brace closure, got {:?}", ast);
}

#[test]
fn accepts_single_equals_as_equality() {
    let src = r#"
if 1 = 1 then 42 else 0 end
"#;
    let mut p = Parser::new(src).expect("init parser");
    let ast = p.parse();
    assert!(ast.is_ok(), "parser should accept '=' as equality, got {:?}", ast);
}
