//! End-to-end validation of the `syntax { ... }` DSL preprocessor using the
//! exact RouterDSL example from the design discussion: defines a small
//! grammar extension for `routes { ... }` blocks, and confirms it expands
//! into plain, parseable, runnable PatLang.
use patlang_runtime::ir::{Lowerer, Interpreter};
use patlang_runtime::parser::Parser;
use patlang_runtime::syntax_dsl::{expand_syntax_dsls, RegexEngine};

const ROUTER_DSL_SRC: &str = r#"
syntax RouterDSL {
    trigger: Keyword("routes");

    tokens {
        HttpVerb(verb) = regex("\b(GET|POST|PUT|DELETE)\b", verb);
        UrlPath(path)   = regex("\/[a-zA-Z0-9_\/:-]*", path);
        Arrow           = "->";
    }

    rule RouteLine {
        let verb = expect HttpVerb;
        let path = expect UrlPath;
        expect Arrow;
        let controller = expect Identifier;
        expect Symbol(".");
        let action = expect Identifier;

        return AST.RegisterRoute(verb, path, controller, action);
    }
}

routes {
    GET  /users          -> UserController.index
    POST /users/:id/edit -> UserController.update
    DELETE /sessions     -> AuthController.logout
}
"#;

#[test]
fn router_dsl_expands_to_plain_patlang() {
    let regex = RegexEngine::load().expect("load regex engine");
    let expanded = expand_syntax_dsls(ROUTER_DSL_SRC, &regex).expect("expand syntax dsl");

    // The `syntax {}` definition itself must be gone.
    assert!(!expanded.contains("syntax RouterDSL"));
    assert!(!expanded.contains("trigger:"));

    // Each routing line becomes a plain call statement with literal args.
    assert!(expanded.contains(r#"AST.RegisterRoute("GET", "/users", "UserController", "index");"#), "got:\n{}", expanded);
    assert!(expanded.contains(r#"AST.RegisterRoute("POST", "/users/:id/edit", "UserController", "update");"#), "got:\n{}", expanded);
    assert!(expanded.contains(r#"AST.RegisterRoute("DELETE", "/sessions", "AuthController", "logout");"#), "got:\n{}", expanded);
}

#[test]
fn router_dsl_output_parses_and_runs() {
    let regex = RegexEngine::load().expect("load regex engine");
    let expanded = expand_syntax_dsls(ROUTER_DSL_SRC, &regex).expect("expand syntax dsl");

    let mut p = Parser::new(&expanded).expect("parser init on expanded source");
    let ast = p.parse().expect("parse expanded source");
    let mut lower = Lowerer::new();
    let program = lower.lower_program_basic(&ast);
    let mut interp = Interpreter::new();
    patlang_runtime::ir::hosts::register_stage0_shims(&mut interp);
    interp.run(&program).expect("run expanded source");
}
