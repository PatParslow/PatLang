// PEG grammar-file validator (Slice 1), native side. Mirrors
// self_hosting/peg_selftest.patlang's cases exactly -- same grammar
// file, same accept/reject expectations -- since the whole point is
// that both engines agree on the same .peg file.
use patlang_runtime::ir::peg::{accepts, load_grammar};
use std::fs;

fn grammar() -> patlang_runtime::ir::peg::Ruleset {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../docs/grammar/patlang-slice1.peg");
    let source = fs::read_to_string(path).expect("read grammar file");
    load_grammar(&source)
}

#[test]
fn grammar_file_loads_with_a_plausible_rule_count() {
    let rules = grammar();
    assert!(rules.len() > 20, "expected >20 rules, got {}", rules.len());
}

#[test]
fn plain_let_and_print() {
    let rules = grammar();
    assert!(accepts(&rules, "Program", "let x = 5\nprint(x)\n"));
}

#[test]
fn word_style_if_else_end() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "if x > 0 then\n  print(1)\nelse\n  print(2)\nend\n"
    ));
}

#[test]
fn brace_style_if_elif_else() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "if x > 0 {\n  print(1)\n} elif x < 0 {\n  print(2)\n} else {\n  print(3)\n}\n"
    ));
}

#[test]
fn word_style_while_do_end() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "let i = 0\nwhile i < 3 do\n  print(i)\n  let i = i + 1\nend\n"
    ));
}

#[test]
fn brace_style_while() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "let i = 0\nwhile i < 3 {\n  print(i)\n  let i = i + 1\n}\n"
    ));
}

#[test]
fn make_a_function_called_word_body() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "make a function called add takes a, b returns r\n  let r = a + b\n  return r\nend\n\nprint(add(2, 3))\n"
    ));
}

#[test]
fn make_a_function_called_brace_body_reject_mismatched_close() {
    let rules = grammar();
    // A `make`-opened, no-brace-body function has nothing for a lone
    // trailing '}' to match -- deliberately a REJECT case, matching
    // peg_selftest.patlang's own "make a function called (brace body)"
    // case exactly (same name, same intent).
    assert!(!accepts(
        &rules,
        "Program",
        "make a function called add takes a, b returns r\n  let r = a + b\n  return r\n}\n"
    ));
}

#[test]
fn fn_with_parenthesized_params() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "fn add(a, b) {\n  return a + b\n}\n\nprint(add(2, 3))\n"
    ));
}

#[test]
fn nested_precedence_expression() {
    let rules = grammar();
    assert!(accepts(
        &rules,
        "Program",
        "let r = 1 + 2 * 3 == 7 and not (4 > 5)\nprint(r)\n"
    ));
}

#[test]
fn trailing_operator_with_nothing_after_it_is_rejected() {
    let rules = grammar();
    assert!(!accepts(&rules, "Program", "let x = 5 +\n"));
}

#[test]
fn unclosed_brace_block_is_rejected() {
    let rules = grammar();
    assert!(!accepts(&rules, "Program", "if x > 0 {\n  print(1)\n"));
}

#[test]
fn fn_without_parens_is_rejected() {
    let rules = grammar();
    assert!(!accepts(&rules, "Program", "fn add a, b {\n  return a + b\n}\n"));
}
