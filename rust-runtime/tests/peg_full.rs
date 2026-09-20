// Full-language PEG grammar (Slice 2), native side. Mirrors
// self_hosting/peg_full_selftest.patlang's cases exactly -- same
// grammar file, same accept/reject expectations.
use patlang_runtime::ir::peg::{accepts, load_grammar};
use std::fs;

fn grammar() -> patlang_runtime::ir::peg::Ruleset {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../docs/grammar/patlang-full.peg");
    let source = fs::read_to_string(path).expect("read grammar file");
    load_grammar(&source)
}

fn ok(source: &str) {
    let rules = grammar();
    assert!(accepts(&rules, "Program", source), "expected ACCEPT: {source}");
}

fn reject(source: &str) {
    let rules = grammar();
    assert!(!accepts(&rules, "Program", source), "expected REJECT: {source}");
}

#[test]
fn grammar_file_loads_with_a_plausible_rule_count() {
    let rules = grammar();
    assert!(rules.len() > 40, "expected >40 rules, got {}", rules.len());
}

#[test]
fn let_with_mut() {
    ok("let mut x = 5\nx = 6\nprint(x)\n");
}

#[test]
fn bare_assignment() {
    ok("let x = 1\nx = 2\n");
}

#[test]
fn member_assignment() {
    ok("let obj = foo\nobj.prop = 5\n");
}

#[test]
fn fn_brace_form() {
    ok("fn add(a, b) {\n  return a + b\n}\n");
}

#[test]
fn function_keyword_form() {
    ok("function add(a, b) {\n  return a + b\n}\n");
}

#[test]
fn make_a_function_called_word_body_with_takes_returns() {
    ok("make a function called add takes a, b returns r\n  let r = a + b\n  return r\nend\n");
}

#[test]
fn if_brace_with_elif_chain() {
    ok("if x > 0 {\n  print(1)\n} elif x == 0 {\n  print(2)\n} else {\n  print(3)\n}\n");
}

#[test]
fn if_word_style_with_elif_chain_shared_end() {
    ok("if x > 0 then\n  print(1)\nelif x == 0 then\n  print(2)\nelse\n  print(3)\nend\n");
}

#[test]
fn while_brace_and_word_style() {
    ok("let i = 0\nwhile i < 3 {\n  let i = i + 1\n}\nwhile i < 6 do\n  let i = i + 1\nend\n");
}

#[test]
fn budgeted_block() {
    ok("budgeted(100) {\n  print(1)\n}\n");
}

#[test]
fn budgeted_with_existing_fiber_arg_word_body() {
    ok("budgeted(100, fib) do\n  print(1)\nend\n");
}

#[test]
fn when_handler() {
    ok("when tick {\n  print(1)\n}\n");
}

#[test]
fn contracts_require_ensure_assert() {
    ok("require x > 0\nensure y > 0\nassert z > 0\n");
}

#[test]
fn rule_declaration_single_clause_body() {
    ok("rule parent(a, b) :- father(a, b).\n");
}

#[test]
fn rule_declaration_multi_call_body() {
    ok("rule parent(a, b) :- father(a, b), mother(a, b).\n");
}

#[test]
fn rule_declaration_fact_no_body() {
    ok("rule fact(a).\n");
}

#[test]
fn rule_as_an_ordinary_call_not_a_declaration() {
    ok("print(rule(1, 2))\n");
}

#[test]
fn bare_print_sugar() {
    ok("print 1 + 2\n");
}

#[test]
fn list_literal_and_indexing() {
    ok("let l = [1, 2, 3]\nprint(l[0])\n");
}

#[test]
fn closure_literal_brace_body() {
    ok("let f = |a, b| { return a + b }\nprint(f(1, 2))\n");
}

#[test]
fn closure_literal_word_body() {
    ok("let f = |a, b| do\n  return a + b\nend\nprint(f(1, 2))\n");
}

#[test]
fn bitwise_and_shift_operators() {
    ok("let r = 1 band 2 bor 3 bxor 4\nlet s = 1 shl 2\nlet t = 8 shr 1\n");
}

#[test]
fn pipeline_operator() {
    ok("let r = 5 |> add1 |> double\n");
}

#[test]
fn member_access_chain() {
    ok("let r = obj.a.b.c\n");
}

#[test]
fn trailing_block_attaches_as_closure_arg_in_general_expr_position() {
    ok("let x = f(1) { print(2) }\n");
}

#[test]
fn trailing_block_does_not_get_swallowed_into_an_if_condition() {
    ok("if f(1) {\n  print(1)\n}\n");
}

#[test]
fn bare_assignment_vs_mid_expression_equality_both_parse_in_their_own_positions() {
    ok("let x = 1\nx = 2\nlet y = (x == 2)\n");
}

#[test]
fn trailing_operator_with_nothing_after_it_is_rejected() {
    reject("let x = 5 +\n");
}

#[test]
fn unclosed_brace_block_is_rejected() {
    reject("if x > 0 {\n  print(1)\n");
}

#[test]
fn malformed_rule_decl_missing_closing_dot_is_rejected() {
    reject("rule parent(a, b) :- father(a, b)\n");
}

// ---- goal/pursue/activate (added when the real syntax landed) ----

#[test]
fn goal_declaration_with_dependencies() {
    ok("goal need_house {\n  built(house), foo(bar)\n}\n");
}

#[test]
fn goal_declaration_with_no_dependencies() {
    ok("goal empty_goal {\n}\n");
}

#[test]
fn pursue_as_an_expression() {
    ok("let p = pursue need_house\n");
}

#[test]
fn pursue_as_a_bare_statement() {
    ok("pursue need_house\n");
}

#[test]
fn pursue_goal_rule_as_ordinary_parenthesized_calls_not_declarations() {
    ok("print(rule(1, 2))\nprint(goal(1, 2))\nprint(pursue(1))\n");
}

#[test]
fn activate_as_an_expression() {
    ok("let ok = activate p\n");
}

#[test]
fn activate_as_a_bare_statement_both_call_forms() {
    ok("activate p\nactivate(p)\n");
}

#[test]
fn activate_call_inside_an_if_condition_does_not_swallow_the_body_block() {
    ok("if activate(p) {\n  print(1)\n}\n");
}

#[test]
fn malformed_goal_decl_missing_closing_brace_is_rejected() {
    reject("goal need_house {\n  built(house)\n");
}

#[test]
fn class_with_fields_brace_form() {
    ok("class Animal {\n  field name = 1\n  field legs = 4\n}\nprint(1)\n");
}

#[test]
fn class_with_inherits_and_a_traits_line() {
    ok("class Animal {\n  field name = 1\n}\nclass Dog inherits Animal {\n  field sound = 2\n  traits Loud, Friendly\n}\nprint(1)\n");
}

#[test]
fn class_in_do_end_form_with_a_method() {
    ok("class Counter do\n  field n = 0\n  make a function called bump takes self returns r\n    return 1\n  end\nend\nprint(1)\n");
}

#[test]
fn class_in_begin_end_form() {
    ok("class Box begin\n  field w = 1\nend\nprint(1)\n");
}

#[test]
fn brace_class_with_a_word_form_method() {
    ok("class Pt {\n  field x = 0\n  make a function called getx takes self returns r\n    return 1\n  end\n}\nprint(1)\n");
}

#[test]
fn match_with_literal_comparison_guarded_binding_and_wildcard_arms() {
    ok("let n = 3\nmatch n do\n  case 3 then print(3)\n  case > 10 then print(10)\n  case x when x == 5 then print(5)\n  case _ then print(0)\nend\n");
}

#[test]
fn match_with_list_and_glob_patterns() {
    ok("let name = 1\nmatch name do\n  case [1, _, x] then print(x)\n  case *.patlang then print(1)\n  case fred* then print(2)\nend\n");
}

#[test]
fn match_nested_in_an_if_with_an_if_inside_an_arm_body() {
    ok("let n = 2\nif n > 1 {\n  match n do\n    case 2 then\n      if n == 2 {\n        print(2)\n      }\n      print(3)\n    case _ then print(0)\n  end\n}\n");
}

#[test]
fn match_followed_by_more_statements() {
    ok("let n = 1\nmatch n do\n  case 1 then print(1)\nend\nprint(2)\n");
}

#[test]
fn class_body_with_a_method_line_the_real_parsers_reject_is_rejected() {
    reject("class Animal {\n  field name = 1\n  method speak() {\n    return 1\n  }\n}\nprint(1)\n");
}

#[test]
fn class_with_an_unclosed_brace_is_rejected() {
    reject("class Animal {\n  field name = 1\nprint(1)\n");
}

#[test]
fn class_opened_with_a_brace_and_closed_with_end_is_rejected() {
    reject("class A {\n  field x = 1\nend\nprint(1)\n");
}

#[test]
fn class_with_no_name_is_rejected() {
    reject("class {\n  field x = 1\n}\n");
}

#[test]
fn match_without_do_is_rejected() {
    reject("let n = 1\nmatch n\n  case 1 then print(1)\nend\n");
}

#[test]
fn case_arm_without_then_is_rejected() {
    reject("let n = 1\nmatch n do\n  case 1 print(1)\nend\n");
}

#[test]
fn match_without_a_closing_end_is_rejected() {
    reject("let n = 1\nmatch n do\n  case 1 then print(1)\n");
}

#[test]
fn rule_facts_and_heads_take_numeric_arguments() {
    ok("rule dob(alice, 1996).\nrule dob(bob, 2015).\nrule older(X, Y) :- dob(X, D1), dob(Y, D2).\nprint(1)\n");
}

#[test]
fn goal_dependencies_take_numeric_arguments() {
    ok("rule built(1).\ngoal g { built(1), built(2) }\nprint(1)\n");
}

#[test]
fn semicolon_as_an_optional_statement_separator() {
    ok("let x = 1; let y = 2\nprint(x); print(y)\n");
}

#[test]
fn semicolon_separator_inside_a_closure_body() {
    ok("let f = |p| { print(1); print(2) }\nf(1)\n");
}
