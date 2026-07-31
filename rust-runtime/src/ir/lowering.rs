use crate::ast::{Expr, Stmt, BinaryOperator};
use std::collections::HashSet;
use super::types::*;

#[derive(Default)]
pub struct Lowerer {
    // minimal tracking of declared locals to avoid lowering unknown identifiers
    // maps declared local name -> whether it was declared `mut` (or is a
    // function parameter, which is always reassignable). Used both to check
    // whether an identifier is safe to lower and to enforce mutability on
    // bare (non-`let`) reassignment.
    known_locals: std::collections::HashMap<String, bool>,
    // track declared function names to allow lowering calls
    known_functions: HashSet<String>,
    // name of the function currently being lowered, for contract-violation messages
    current_function: String,
    // functions synthesized from closure literals, merged into the program
    // once top-level lowering completes
    pending_closures: Vec<Function>,
    // unique naming for synthesized closure functions
    closure_counter: usize,
    // unique naming for synthesized budgeted() functions
    budgeted_counter: usize,
    // >0 while lowering the body of a budgeted(ms) { ... } block (nesting-
    // depth counter, not a bool, so a budgeted block nested inside another
    // still counts as "inside"): while-loop back-edges lowered in this state
    // get a budget_check() call injected just before the jump.
    in_budgeted_depth: usize,
    // unique naming for synthesized `activate(...)` dispatch-loop locals
    activate_counter: usize,
    // Names whose most recent non-reassignment `let` bound them to a
    // string literal -- used only to reduce false positives in the
    // string-concat-in-a-loop warning below (a bare `let x = x + 1`
    // loop counter has the identical AST shape as `let out = out + c`,
    // so without this we'd warn on every ordinary numeric accumulator
    // too). Never removed once added -- reusing a name for a number
    // after a string-literal init is rare enough that a stale flag is
    // an acceptable false-negative, and simpler than full type tracking.
    string_literal_locals: HashSet<String>,
    // Warned-once guard so a self-append inside a loop that runs a
    // million times doesn't print a million identical warnings -- the
    // interesting fact is WHICH VARIABLE, not how many times the loop
    // executed it.
    warned_string_concat: HashSet<String>,
}

impl Lowerer {
    pub fn new() -> Self { Self::default() }

    pub fn lower_program_basic(&mut self, stmts: &[Stmt]) -> Program {
    let mut main_fn = Function { name: "main".into(), ..Default::default() };
        let mut program = Program::default();
        program.entry = "main".into();
        // Pre-pass: collect all function names so forward references and mutual
        // recursion lower to Call rather than CallHost regardless of definition order
        for s in stmts {
            if let Stmt::Function { name, .. } = s {
                self.known_functions.insert(name.clone());
            }
        }
        // First pass: lower function definitions into program
        for s in stmts {
            if let Stmt::Function { name, params, body } = s.clone() {
                let mut f = Function { name: name.clone(), params: params.clone(), ..Default::default() };
                // Lower the function body
                let saved_locals = std::mem::take(&mut self.known_locals);
                let saved_fname = std::mem::replace(&mut self.current_function, name.clone());
                // params are considered known locals; always reassignable
                // (Phase 1 does not require `mut` on parameters).
                self.known_locals = params.iter().map(|p| (p.clone(), true)).collect();
                for st in body {
                    self.lower_stmt(&st, &mut f);
                }
                f.body.push(Instr::Return);
                program.functions.insert(name.clone(), f);
                self.known_locals = saved_locals; // restore
                self.current_function = saved_fname;
            }
        }
        // Second pass: lower top-level statements into main. `when`
        // blocks are handled by lower_stmt's own Stmt::When arm (see
        // lower_when below) now, in sequence with everything else here
        // -- NOT a separate pre-pass that ran before any top-level `let`
        // had been lowered, which is exactly why a handler could never
        // see an enclosing `let` before (a real, previously-known
        // gotcha, worked around by re-declaring the same name fresh
        // inside every handler body instead of fixing the root cause).
        self.current_function = "main".into();
        for s in stmts {
            if !matches!(s, Stmt::Function { .. }) {
                self.lower_stmt(s, &mut main_fn);
            }
        }
        main_fn.body.push(Instr::Return);
        program.functions.insert("main".into(), main_fn);
        for f in self.pending_closures.drain(..) {
            program.functions.insert(f.name.clone(), f);
        }
        program
    }

    // Synthesizes, as ordinary AST fed through the normal lower_stmt/
    // lower_expr path, a dispatch loop over a plan (a List<String> of
    // action-name labels from `pursue`/`plan(...)`): for each label, split
    // it into a base name + bound-arg-values list (host fns
    // action_base_name/action_label_args, pure string parsing), look up
    // the closure bound to that action name (action_lookup, hosts.rs), and
    // call it with the WHOLE bound-args list as its single argument (not
    // splatted positionally -- CallValue's argc is fixed at lowering time,
    // but a plan step's real arg count is only known at runtime, so the
    // bound closure receives one List and destructures it itself, e.g.
    // `action_bind("build", |args| { let x = args[0] ... })`).
    //
    // A bound closure's return value is a success signal, per the user's
    // explicit correction that a dependency "might be a function [that]
    // might fail for some reason" -- any `false` return stops the loop
    // immediately (remaining plan steps do NOT run) rather than assuming
    // a found plan always completes. `activate(...)`'s own value is that
    // overall success boolean.
    fn lower_activate(&mut self, plan_expr: &Expr, f: &mut Function) {
        self.activate_counter += 1;
        let n = self.activate_counter;
        let plan_var = format!("__act_plan_{}", n);
        let i_var = format!("__act_i_{}", n);
        let ok_var = format!("__act_ok_{}", n);
        let label_var = format!("__act_label_{}", n);
        let fn_var = format!("__act_fn_{}", n);
        let args_var = format!("__act_args_{}", n);
        let r_var = format!("__act_r_{}", n);

        let ident = |s: &str| Expr::Identifier(s.to_string());
        let call = |fname: &str, args: Vec<Expr>| Expr::Call { function: Box::new(ident(fname)), args };
        let let_ = |name: &str, value: Expr, mutable: bool| Stmt::Let { name: name.to_string(), value, is_reassignment: false, mutable };
        let reassign = |name: &str, value: Expr| Stmt::Let { name: name.to_string(), value, is_reassignment: true, mutable: false };

        let synth: Vec<Stmt> = vec![
            let_(&plan_var, plan_expr.clone(), false),
            let_(&i_var, Expr::Number(0.0), true),
            let_(&ok_var, ident("true"), true),
            Stmt::While {
                cond: Expr::BinaryOp {
                    left: Box::new(ident(&ok_var)),
                    op: BinaryOperator::And,
                    right: Box::new(Expr::BinaryOp {
                        left: Box::new(ident(&i_var)),
                        op: BinaryOperator::Less,
                        // list_len returns a String (an existing repo-wide
                        // convention/quirk, not specific to this loop) --
                        // must go through to_num before it's comparable.
                        right: Box::new(call("to_num", vec![call("list_len", vec![ident(&plan_var)])])),
                    }),
                },
                body: vec![
                    let_(&label_var, Expr::Index { object: Box::new(ident(&plan_var)), index: Box::new(ident(&i_var)) }, false),
                    let_(&fn_var, call("action_lookup", vec![call("action_base_name", vec![ident(&label_var)])]), false),
                    let_(&args_var, call("action_label_args", vec![ident(&label_var)]), false),
                    let_(&r_var, call(&fn_var, vec![ident(&args_var)]), false),
                    Stmt::If {
                        cond: Expr::BinaryOp { left: Box::new(ident(&r_var)), op: BinaryOperator::Equal, right: Box::new(ident("false")) },
                        then_branch: vec![reassign(&ok_var, ident("false"))],
                        else_branch: None,
                    },
                    reassign(&i_var, Expr::BinaryOp { left: Box::new(ident(&i_var)), op: BinaryOperator::Add, right: Box::new(Expr::Number(1.0)) }),
                ],
            },
        ];
        for s in &synth { self.lower_stmt(s, f); }
        self.lower_expr(&ident(&ok_var), f);
    }

    fn lower_stmt(&mut self, s: &Stmt, f: &mut Function) {
        match s {
            Stmt::ExprStmt(e) => {
                if self.expr_is_safe(e) {
                    self.lower_expr(e, f);
                    // Every function body ends with an explicit Instr::Return
                    // (pushed at every function-emission site in this file) --
                    // an ExprStmt's value is NEVER the function's real return
                    // value, so it must be discarded here. A tree-walking
                    // interpreter with a heap-allocated Vec<Value> operand
                    // stack tolerates leaving it (unbounded growth, no crash),
                    // but a native machine-stack-based backend (the x64
                    // self-hosted backend) uses the real `rsp` for this same
                    // operand stack -- capped at ~1MB by the OS -- so a bare
                    // statement call (e.g. `sb_push(sb, x)` with its result
                    // never assigned) inside a large loop leaks one stack slot
                    // per iteration and genuinely overflows the native stack.
                    // Real bug (GitHub #31): traced via WinDbg to a stack
                    // overflow in `expand_includes_at_depth`'s ~30,000-line
                    // loop; confirmed with a minimal repro (a bare `sb_push`
                    // statement in a 30,000-iteration loop segfaults with
                    // STATUS_STACK_OVERFLOW under --x64, but not when its
                    // result is assigned to a `let`). Fixed by discarding via
                    // StoreLocal into a dedicated, never-read local -- reuses
                    // the existing Store/StoreLocal instruction everywhere
                    // (interpreter, native codegen, x64 codegen) rather than
                    // adding a new IR opcode.
                    f.body.push(Instr::StoreLocal("__discard".to_string()));
                } else {
                    // skip unsafe expression statements (unknown identifiers / members)
                }
            }
            Stmt::Let { name, value, is_reassignment, mutable } => {
                self.lower_expr(value, f);
                if *is_reassignment {
                    match self.known_locals.get(name) {
                        Some(true) => { /* declared mut: reassignment is fine */ }
                        Some(false) => {
                            // Statically-known immutable reassignment: emit a
                            // contract_check that always fails at this point,
                            // rather than rejecting the whole program here --
                            // lower_program_basic is infallible today, so this
                            // is enforced as a guaranteed-fail assertion at the
                            // reassignment site instead of a hard compile error.
                            f.body.push(Instr::Const(Value::String((self.current_function.clone()).into())));
                            f.body.push(Instr::Const(Value::String("assert".to_string().into())));
                            f.body.push(Instr::Const(Value::String(format!(
                                "cannot assign twice to immutable variable `{}` (declare it `let mut {}` to allow reassignment)",
                                name, name
                            ).into())));
                            f.body.push(Instr::Const(Value::Bool(false)));
                            f.body.push(Instr::CallHost("contract_check".into(), 4));
                        }
                        None => {
                            // Not seen in this function's local scope (e.g. a
                            // captured/outer-scope name this flat tracker can't
                            // see) -- fall back to the old permissive behaviour
                            // rather than false-positive on legitimate code.
                            self.known_locals.insert(name.clone(), true);
                        }
                    }
                } else {
                    // `let` / `let mut`: always allowed to introduce or shadow.
                    self.known_locals.insert(name.clone(), *mutable);
                    if matches!(value, Expr::String(_)) {
                        self.string_literal_locals.insert(name.clone());
                    }
                }
                f.body.push(Instr::StoreLocal(name.clone()));
            }
            Stmt::Return(opt) => {
                if let Some(e) = opt { self.lower_expr(e, f); }
                f.body.push(Instr::Return);
            }
            Stmt::If { cond, then_branch, else_branch } => {
                self.lower_expr(cond, f);
                // JumpIfFalse to else
                let jif_idx = f.body.len();
                f.body.push(Instr::JumpIfFalse(usize::MAX)); // patch later
                // then
                for s in then_branch { self.lower_stmt(s, f); }
                // Jump over else
                let jmp_over_idx = f.body.len();
                f.body.push(Instr::Jump(usize::MAX)); // patch later
                // else target
                let else_pc = f.body.len();
                // patch JumpIfFalse
                if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = else_pc; }
                if let Some(else_branch) = else_branch {
                    for s in else_branch { self.lower_stmt(s, f); }
                }
                // patch jump over else to here
                let after_else = f.body.len();
                if let Instr::Jump(ref mut tgt) = f.body[jmp_over_idx] { *tgt = after_else; }
            }
            Stmt::While { cond, body } => {
                self.warn_string_concat_in_loop(body);
                // loop_start:
                let loop_start = f.body.len();
                // evaluate condition
                self.lower_expr(cond, f);
                // if false -> jump to after loop
                let jif_idx = f.body.len();
                f.body.push(Instr::JumpIfFalse(usize::MAX));
                // body
                for s in body { self.lower_stmt(s, f); }
                // Lexically inside a budgeted(ms) { ... } block: check the
                // time budget just before looping back, suspending (via
                // fiber_yield inside budget_check) once it's exhausted.
                if self.in_budgeted_depth > 0 {
                    f.body.push(Instr::CallHost("budget_check".into(), 0));
                }
                // jump back to loop_start
                f.body.push(Instr::Jump(loop_start));
                // patch JumpIfFalse to after body
                let after = f.body.len();
                if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = after; }
            }
            Stmt::Assert { kind, expr } => {
                // contract_check(func_name, kind, condition_text, ok) — pushed in
                // that order so CallHost's arg order matches; ok is evaluated last.
                f.body.push(Instr::Const(Value::String((self.current_function.clone()).into())));
                f.body.push(Instr::Const(Value::String((kind.clone()).into())));
                f.body.push(Instr::Const(Value::String((expr_to_text(expr)).into())));
                self.lower_expr(expr, f);
                f.body.push(Instr::CallHost("contract_check".into(), 4));
                f.body.push(Instr::StoreLocal("__discard".to_string()));
            }
            Stmt::RuleDecl { head_pred, head_args, body } => {
                // Sugar: lowers to exactly the Instr sequence a hand-written
                // rule_add(head_pred, [head_args...], [[pred,[args...]], ...])
                // call already produces (see hosts.rs::host_rule_add). Args
                // are compile-time string TOKENS, not ordinary expressions to
                // evaluate -- a bare rule-head `X` has no local-variable
                // binding to look up; it's a logic-variable name, not a value.
                f.body.push(Instr::Const(Value::String((head_pred.clone()).into())));
                for a in head_args {
                    f.body.push(Instr::Const(Value::String((rule_arg_text(a)).into())));
                }
                f.body.push(Instr::BuildList(head_args.len()));
                for (pred, args) in body {
                    f.body.push(Instr::Const(Value::String((pred.clone()).into())));
                    for a in args {
                        f.body.push(Instr::Const(Value::String((rule_arg_text(a)).into())));
                    }
                    f.body.push(Instr::BuildList(args.len()));
                    f.body.push(Instr::BuildList(2)); // [pred, args_list]
                }
                f.body.push(Instr::BuildList(body.len()));
                f.body.push(Instr::CallHost("rule_add".into(), 3));
                f.body.push(Instr::StoreLocal("__discard".to_string()));
            }
            Stmt::MemberAssign { object, property, value } => {
                // obj.prop = value -- lowers to the same send(obj, "set",
                // prop, value) host call the object system already uses
                // for explicit send("obj","set","prop",value) calls; mirrors
                // Expr::Member's get(obj,"prop") on the read side. Previously
                // unhandled here (fell through to the "unsupported yet:
                // ignore safely" catch-all below), even though the legacy
                // core_evaluator.rs path already supported it -- a real gap
                // in the IR pipeline that --ir-run/--patc actually use.
                self.lower_expr(object, f);
                f.body.push(Instr::Const(Value::String("set".to_string().into())));
                f.body.push(Instr::Const(Value::String((property.clone()).into())));
                self.lower_expr(value, f);
                // 4 stack args just pushed: object, "set", property, value.
                let send_arity = 4;
                f.body.push(Instr::CallHost("send".into(), send_arity));
                // Statement-level call result, never consumed -- see the
                // GitHub #31 fix in the Stmt::ExprStmt arm above for why
                // this must be discarded rather than left on the stack.
                f.body.push(Instr::StoreLocal("__discard".to_string()));
            }
            Stmt::GoalDecl { name, deps } => {
                // Sugar: lowers to exactly the Instr sequence a hand-written
                // goal_def(NAME, [[pred,[args...]], ...]) call already
                // produces (see hosts.rs::host_goal_def). Dep args are
                // compile-time string tokens, same convention as RuleDecl
                // body args just above -- a goal dependency is a fact-term,
                // not an expression to evaluate.
                f.body.push(Instr::Const(Value::String((name.clone()).into())));
                for (pred, args) in deps {
                    f.body.push(Instr::Const(Value::String((pred.clone()).into())));
                    for a in args {
                        f.body.push(Instr::Const(Value::String((rule_arg_text(a)).into())));
                    }
                    f.body.push(Instr::BuildList(args.len()));
                    f.body.push(Instr::BuildList(2)); // [pred, args_list]
                }
                f.body.push(Instr::BuildList(deps.len()));
                f.body.push(Instr::CallHost("goal_def".into(), 2));
                f.body.push(Instr::StoreLocal("__discard".to_string()));
            }
            Stmt::ClassDecl { name, parent, fields, methods, traits } => {
                // Slice 1+2+3 of the classes/traits/inheritance feature
                // (see the "synchronous-questing-metcalfe" plan): sugar
                // for a single class_def(name, parent_or_empty, [[field,
                // default_value], ...], [[method_name, closure], ...],
                // [trait_name, ...]) host call (see hosts.rs::
                // host_class_def). Field defaults are ordinary
                // expressions, evaluated once here at class-def time via
                // the normal lower_expr path. Methods (Slice 2) become
                // genuine closures built via lower_closure_literal (each
                // gets an implicit leading "self" param, bound to the
                // receiver id at `send`-dispatch time -- see
                // interpreter.rs/codegen.rs's CallHost("send", ...)
                // handling), same "declarative sugar wrapping real
                // closure values" shape as `when` blocks (lower_when).
                // Trait names (Slice 3) are compile-time string TOKENS,
                // same convention as RuleDecl/GoalDecl's own dep args --
                // a trait reference is a class-registry lookup key, not
                // an expression to evaluate.
                f.body.push(Instr::Const(Value::String((name.clone()).into())));
                f.body.push(Instr::Const(Value::String(parent.clone().unwrap_or_default().into())));
                for (fname, default_expr) in fields {
                    f.body.push(Instr::Const(Value::String((fname.clone()).into())));
                    self.lower_expr(default_expr, f);
                    f.body.push(Instr::BuildList(2)); // [field_name, default_value]
                }
                f.body.push(Instr::BuildList(fields.len()));
                for (mname, params, body) in methods {
                    f.body.push(Instr::Const(Value::String((mname.clone()).into())));
                    let mut full_params = vec!["self".to_string()];
                    full_params.extend(params.iter().cloned());
                    self.lower_closure_literal(&full_params, body, f);
                    f.body.push(Instr::BuildList(2)); // [method_name, closure]
                }
                f.body.push(Instr::BuildList(methods.len()));
                for tname in traits {
                    f.body.push(Instr::Const(Value::String((tname.clone()).into())));
                }
                f.body.push(Instr::BuildList(traits.len()));
                f.body.push(Instr::CallHost("class_def".into(), 5));
                f.body.push(Instr::StoreLocal("__discard".to_string()));
            }
            Stmt::When { event, body, .. } => {
                self.lower_when(event, body, f);
            }
            _ => {
                // unsupported yet: ignore safely
            }
        }
    }

    // Lowers `when EVENT { ... }` as a genuine closure literal (the same
    // free-variable capture lower_closure_literal does for `|x| { ... }`),
    // with fixed params ["event_name", "event_data"] (auto-bound by
    // emit(), never user-written) instead of a user-supplied param list.
    // Registers the resulting closure VALUE at runtime via
    // register_event_handler(event, closure) -- a real host call emitted
    // right here, at the point the `when` statement actually appears in
    // program order -- rather than the previous design, where every
    // `when` block was found by a separate pre-pass that ran BEFORE any
    // top-level `let` had been lowered at all, synthesizing an ISOLATED
    // standalone function with no access to anything outer-scope. That's
    // exactly why a handler could never see an enclosing `let` before (a
    // real, previously-known gotcha, worked around by re-declaring the
    // same name fresh inside every handler body instead of fixing the
    // root cause) -- this closes it: a `when` block declared after a
    // `let` now captures that `let` correctly, the same as any ordinary
    // closure would.
    fn lower_when(&mut self, event: &str, body: &[Stmt], f: &mut Function) {
        let params: Vec<String> = vec!["event_name".to_string(), "event_data".to_string()];
        let mut own: HashSet<String> = params.iter().cloned().collect();
        collect_let_bound_names(body, &mut own);

        let mut referenced: Vec<String> = Vec::new();
        let mut seen: HashSet<String> = HashSet::new();
        collect_referenced_idents(body, &mut referenced, &mut seen);

        let mut self_ref_lets: HashSet<String> = HashSet::new();
        collect_self_referential_let_names(body, &mut self_ref_lets);
        let captured_names: Vec<String> = referenced.into_iter()
            .filter(|n| (!own.contains(n) || self_ref_lets.contains(n)) && self.known_locals.contains_key(n))
            .collect();

        self.closure_counter += 1;
        let func_name = format!("__when_{}_{}", event, self.closure_counter);
        let mut hf = Function {
            name: func_name.clone(),
            params: captured_names.iter().cloned().chain(params.iter().cloned()).collect(),
            ..Default::default()
        };
        let saved_locals = std::mem::take(&mut self.known_locals);
        let saved_fname = std::mem::replace(&mut self.current_function, func_name.clone());
        self.known_locals = hf.params.iter().map(|p| (p.clone(), true)).collect();
        for st in body { self.lower_stmt(st, &mut hf); }
        hf.body.push(Instr::Return);
        self.known_locals = saved_locals;
        self.current_function = saved_fname;
        self.pending_closures.push(hf);

        // event name first, so CallHost's drained args land as
        // (event_name, closure) in that order -- MakeClosure must
        // immediately follow its own LoadLocal sequence, so the Const
        // for the event name has to come before all of that, not
        // between the loads and MakeClosure.
        f.body.push(Instr::Const(Value::String(event.to_string().into())));
        for name in &captured_names {
            f.body.push(Instr::LoadLocal(name.clone()));
        }
        f.body.push(Instr::MakeClosure(func_name, captured_names));
        f.body.push(Instr::CallHost("register_event_handler".into(), 2));
        f.body.push(Instr::StoreLocal("__discard".to_string()));
    }

    fn expr_is_safe(&self, e: &Expr) -> bool {
        match e {
            Expr::Number(_) | Expr::Float(_) | Expr::String(_) => true,
            Expr::Identifier(name) => name == "true" || name == "false" || self.known_locals.contains_key(name),
            Expr::List(items) => items.iter().all(|it| self.expr_is_safe(it)),
            // Member reads lower to len/get host calls; safe when the object expr is safe
            Expr::Member { object, .. } => self.expr_is_safe(object),
            Expr::Index { object, index } => self.expr_is_safe(object) && self.expr_is_safe(index),
            Expr::UnaryOp { expr, .. } => self.expr_is_safe(expr),
            Expr::BinaryOp { left, right, .. } => self.expr_is_safe(left) && self.expr_is_safe(right),
            Expr::Call { function, args } => {
                let callee_safe = match &**function {
                    Expr::Identifier(name) => {
                        self.is_allowed_host(name) || self.known_functions.contains(name) || self.known_locals.contains_key(name)
                    }
                    // Any other safe callee expression (e.g. an inline closure
                    // literal) dispatches through CallValue, which cannot
                    // corrupt lowering state even if the runtime value turns
                    // out not to be callable.
                    other => self.expr_is_safe(other),
                };
                callee_safe && args.iter().all(|a| self.expr_is_safe(a))
            }
            // Closure literals never fail to lower (MakeClosure is infallible)
            Expr::Closure { .. } => true,
            // budgeted(...) always lowers to a valid CallHost sequence
            // regardless of what's captured (over-capture, not precise
            // analysis -- see the lowering code), so it's infallible too.
            Expr::Budgeted { .. } => true,
            _ => false,
        }
    }

    fn is_allowed_host(&self, name: &str) -> bool {
        matches!(name,
            "print"|"add"|"multiply"|"subtract"|"max"|"min"|"calculate"|"calculate_result"|
            "get_value"|"process"|"validate"|"len"|"get"|"send"|"emit"|"sed"|
            "list_get"|"list_len"|"list_push"|"list_set"|"char_code"|"substr"|"chr"|"to_num"|"read_file"|"write_file"|"file_exists"|"hash_string"|"argv"|"compile_shape"|"compile_ir"|"run_ir"|"codegen_prelude"|"codegen_prelude_chunk"|"rustc_build"|
            "vec_new"|"vec_push"|"vec_set"|"vec_get"|"vec_len"|"vec_to_list"|"sb_new"|"sb_push"|"sb_str"|
            "str_intern"|"sc_len"|"sc_code"|"sc_char"|"now_ms"|"read_line"|"byte_length"|"read_file_b64"|"exec_capture"|
            "fact"|"query"|"goal"|"new"|"set_var"|"apply"|
            "tcp_listen"|"tcp_try_listen"|"tcp_connect"|"tcp_accept"|"tcp_accept_timeout"|"sleep_ms"|"tcp_read"|"tcp_read_or_empty"|"tcp_write"|"tcp_close"|
            "spawn"|"is_alive"|"wait"|"kill"|
            "sqrt"|"pow"|"sin"|"cos"|"tan"|"asin"|"acos"|"atan"|"atan2"|"log"|"exp"|
            "floor"|"ceil"|"round"|"trunc"|"abs"|"to_fixed"|"numeric_kind"|"type_of"|
            "parallel_map"|"fiber_new"|"fiber_resume"|"fiber_yield"|"fiber_alive"|
            "budgeted_run"|"budget_check"|
            "list_dir"|"rename_file"|
            "rule_add"|"solve"|"action_add"|"plan"|
            "goal_def"|"pursue"|"action_bind"|"action_lookup"|"action_base_name"|"action_label_args"|"activate"|
            "bit_get"|"bit_set"|"bit_slice"|"bit_set_slice"|
            "vfs_read"|"vfs_write"|"vfs_append"|"vfs_exists"|"vfs_list"|"vfs_delete"|"vfs_flush_to_disk"
        )
    }

    fn lower_expr(&mut self, e: &Expr, f: &mut Function) {
        match e {
            // Whole-number literal source syntax (no decimal point) stays on
            // the fast Int path by default (Stage 36 numeric tower).
            Expr::Number(n) => f.body.push(Instr::Const(Value::Int(*n as i64))),
            Expr::Float(n) => f.body.push(Instr::Const(Value::Float(*n))),
            Expr::String(s) => f.body.push(Instr::Const(Value::String((s.clone()).into()))),
            Expr::Identifier(name) => {
                // Treat 'true' and 'false' as boolean literals in Stage 0
                if name == "true" {
                    f.body.push(Instr::Const(Value::Bool(true)));
                } else if name == "false" {
                    f.body.push(Instr::Const(Value::Bool(false)));
                } else {
                    f.body.push(Instr::LoadLocal(name.clone()));
                }
            }
            Expr::List(items) => {
                for it in items { self.lower_expr(it, f); }
                f.body.push(Instr::BuildList(items.len()));
            }
            Expr::Member { object, property } => {
                // Map property reads to host calls: length/len -> len(obj); otherwise get(obj, "prop")
                self.lower_expr(object, f);
                if property == "length" || property == "len" {
                    f.body.push(Instr::CallHost("len".into(), 1));
                } else {
                    f.body.push(Instr::Const(Value::String((property.clone()).into())));
                    f.body.push(Instr::CallHost("get".into(), 2));
                }
            }
            Expr::Index { object, index } => {
                // xs[i] lowers to host list_get(xs, i); also yields string char at i
                self.lower_expr(object, f);
                self.lower_expr(index, f);
                f.body.push(Instr::CallHost("list_get".into(), 2));
            }
            Expr::Call { function, args } => {
                // `activate(PLAN)` (the desugared form of `activate PLAN`,
                // see parser.rs) needs to CALL each planned action's bound
                // closure -- host functions cannot call back into the
                // interpreter (see hosts.rs's ACTION_BODIES doc comment),
                // so this can't be a plain host call like `pursue` is.
                // Instead it's synthesized here as ordinary control-flow
                // AST (Let/While/If/Call), fed back through lower_stmt/
                // lower_expr exactly like any nested block would be --
                // see lower_activate. Intercepted at this level (not in
                // lower_stmt) so it works whether `activate PLAN` appears
                // as its own statement or as `let ok = activate PLAN`.
                if let Expr::Identifier(name) = &**function {
                    if name == "activate" && args.len() == 1 {
                        self.lower_activate(&args[0], f);
                        return;
                    }
                }
                // Identifier calls: static function, closure-valued local, or host call.
                // Member calls map to message send. Any other callee expression
                // (e.g. an inline closure literal called immediately) evaluates to
                // a closure value and dispatches through CallValue.
                match &**function {
                    Expr::Identifier(name) if self.known_functions.contains(name) => {
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::Call(name.clone(), args.len()));
                    }
                    Expr::Identifier(name) if self.known_locals.contains_key(name) => {
                        // Dynamic call through a local variable holding a closure
                        f.body.push(Instr::LoadLocal(name.clone()));
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallValue(args.len()));
                    }
                    Expr::Identifier(name) => {
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallHost(name.clone(), args.len()));
                    }
                    Expr::Member { object, property } => {
                        // send(object, "method", ...args)
                        self.lower_expr(object, f);
                        f.body.push(Instr::Const(Value::String((property.clone()).into())));
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallHost("send".into(), 2 + args.len()));
                    }
                    other => {
                        // Arbitrary callee expression (e.g. an inline closure
                        // literal): evaluate it to a closure value, then CallValue
                        self.lower_expr(other, f);
                        for arg in args { self.lower_expr(arg, f); }
                        f.body.push(Instr::CallValue(args.len()));
                    }
                }
            }
            Expr::Closure { params, body } => {
                self.lower_closure_literal(params, body, f);
            }
            Expr::Budgeted { ms, existing, body } => {
                self.budgeted_counter += 1;
                let func_name = format!("__budgeted_{}", self.budgeted_counter);
                // Over-capture the entire enclosing locals list (same
                // approach lower_closure_literal uses) rather than precise
                // free-variable analysis -- simpler, and still correct given
                // the flat per-call locals model. fiber_new only ever passes
                // ONE initial argument to the spawned function, so all
                // captured values are bundled into a single List and the
                // synthesized function's sole declared parameter unpacks
                // them again in its own prologue.
                let captured: Vec<(String, bool)> = self.known_locals.iter().map(|(k, v)| (k.clone(), *v)).collect();
                let mut bf = Function { name: func_name.clone(), params: vec!["__captured".into()], ..Default::default() };
                for (i, (name, _)) in captured.iter().enumerate() {
                    bf.body.push(Instr::LoadLocal("__captured".into()));
                    bf.body.push(Instr::Const(Value::Int(i as i64)));
                    bf.body.push(Instr::CallHost("list_get".into(), 2));
                    bf.body.push(Instr::StoreLocal(name.clone()));
                }
                let saved_locals = std::mem::take(&mut self.known_locals);
                let saved_fname = std::mem::replace(&mut self.current_function, func_name.clone());
                self.known_locals.insert("__captured".into(), true);
                for (name, mutable) in &captured { self.known_locals.insert(name.clone(), *mutable); }
                self.in_budgeted_depth += 1;
                for st in body { self.lower_stmt(st, &mut bf); }
                self.in_budgeted_depth -= 1;
                bf.body.push(Instr::Return);
                self.pending_closures.push(bf);
                self.known_locals = saved_locals;
                self.current_function = saved_fname;

                // budgeted_run(ms, func_name, captured_list, existing) --
                // `existing` is Unit for a first call (start a new fiber) or
                // a previous ["paused", id] result's id to resume that same
                // fiber with a freshly refreshed deadline.
                self.lower_expr(ms, f);
                f.body.push(Instr::Const(Value::String((func_name).into())));
                for (name, _) in &captured { f.body.push(Instr::LoadLocal(name.clone())); }
                f.body.push(Instr::BuildList(captured.len()));
                match existing {
                    Some(e) => self.lower_expr(e, f),
                    None => f.body.push(Instr::Const(Value::Unit)),
                }
                f.body.push(Instr::CallHost("budgeted_run".into(), 4));
            }
            Expr::UnaryOp { op, expr } => {
                self.lower_expr(expr, f);
                match op.as_str() {
                    "-" => f.body.push(Instr::UnOp(UnOpKind::Neg)),
                    "not" => f.body.push(Instr::UnOp(UnOpKind::Not)),
                    "bnot" => f.body.push(Instr::UnOp(UnOpKind::BitNot)),
                    _ => {}
                }
            }
            Expr::BinaryOp { left, op, right } => {
                use BinaryOperator::*;
                match op {
                    And => {
                        // Short-circuit: if left is falsey -> false, else result is truthiness of right
                        self.lower_expr(left, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not)); // !left
                        let jif_idx = f.body.len();
                        f.body.push(Instr::JumpIfFalse(usize::MAX)); // if !left == false => left true -> eval right
                        // left is false path
                        f.body.push(Instr::Const(Value::Bool(false)));
                        let jmp_end_idx = f.body.len();
                        f.body.push(Instr::Jump(usize::MAX));
                        // eval right
                        let eval_right_pc = f.body.len();
                        if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = eval_right_pc; }
                        self.lower_expr(right, f);
                        // coerce to bool using double-not
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        let end_pc = f.body.len();
                        if let Instr::Jump(ref mut tgt) = f.body[jmp_end_idx] { *tgt = end_pc; }
                    }
                    Or => {
                        // Short-circuit: if left is truthy -> true, else result is truthiness of right
                        self.lower_expr(left, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not)); // !left
                        let jif_idx = f.body.len();
                        f.body.push(Instr::JumpIfFalse(usize::MAX)); // when !left == false => left true
                        // left false -> eval right
                        self.lower_expr(right, f);
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        f.body.push(Instr::UnOp(UnOpKind::Not));
                        let jmp_end_idx = f.body.len();
                        f.body.push(Instr::Jump(usize::MAX));
                        // push true for left true case
                        let push_true_pc = f.body.len();
                        if let Instr::JumpIfFalse(ref mut tgt) = f.body[jif_idx] { *tgt = push_true_pc; }
                        f.body.push(Instr::Const(Value::Bool(true)));
                        let end_pc = f.body.len();
                        if let Instr::Jump(ref mut tgt) = f.body[jmp_end_idx] { *tgt = end_pc; }
                    }
                    _ => {
                        self.lower_expr(left, f);
                        self.lower_expr(right, f);
                        let instr = match op {
                            Add => Instr::BinOp(BinOpKind::Add),
                            Sub => Instr::BinOp(BinOpKind::Sub),
                            Mul => Instr::BinOp(BinOpKind::Mul),
                            Div => Instr::BinOp(BinOpKind::Div),
                            Mod => Instr::BinOp(BinOpKind::Mod),
                            Equal => Instr::BinOp(BinOpKind::Eq),
                            NotEqual => Instr::BinOp(BinOpKind::Ne),
                            Greater => Instr::BinOp(BinOpKind::Gt),
                            GreaterEqual => Instr::BinOp(BinOpKind::Ge),
                            Less => Instr::BinOp(BinOpKind::Lt),
                            LessEqual => Instr::BinOp(BinOpKind::Le),
                            BitAnd => Instr::BinOp(BinOpKind::BitAnd),
                            BitOr => Instr::BinOp(BinOpKind::BitOr),
                            BitXor => Instr::BinOp(BinOpKind::BitXor),
                            Shl => Instr::BinOp(BinOpKind::Shl),
                            Shr => Instr::BinOp(BinOpKind::Shr),
                            And | Or => unreachable!(),
                        };
                        f.body.push(instr);
                    }
                }
            }
            _ => { /* TODO: calls, lists, etc. */ }
        }
    }

    /// Lowers a closure literal: analyzes free variables, synthesizes a
    /// Function (params = captured names ++ the closure's own params, in
    /// that order) queued in `pending_closures`, and emits the
    /// LoadLocal.../MakeClosure sequence at the creation site in `f`.
    fn lower_closure_literal(&mut self, params: &[String], body: &[Stmt], f: &mut Function) {
        // This language has no block scoping (reassigning a local inside an
        // if/while branch is already visible after it, everywhere else in
        // this codebase) so a flat union of the closure's params and every
        // name it `let`-binds anywhere in its body is a consistent notion of
        // "bound within the closure" for deciding what must be captured.
        let mut own: HashSet<String> = params.iter().cloned().collect();
        collect_let_bound_names(body, &mut own);

        let mut referenced: Vec<String> = Vec::new();
        let mut seen: HashSet<String> = HashSet::new();
        collect_referenced_idents(body, &mut referenced, &mut seen);

        // Capture only names that are (a) free in the closure and (b) actually
        // present in the enclosing scope right now (anything else is presumably
        // a host/global function name, not a variable to snapshot).
        let mut self_ref_lets: HashSet<String> = HashSet::new();
        collect_self_referential_let_names(body, &mut self_ref_lets);
        let captured_names: Vec<String> = referenced.into_iter()
            .filter(|n| (!own.contains(n) || self_ref_lets.contains(n)) && self.known_locals.contains_key(n))
            .collect();

        self.closure_counter += 1;
        let func_name = format!("__closure_{}", self.closure_counter);
        let mut cf = Function {
            name: func_name.clone(),
            params: captured_names.iter().cloned().chain(params.iter().cloned()).collect(),
            ..Default::default()
        };
        let saved_locals = std::mem::take(&mut self.known_locals);
        let saved_fname = std::mem::replace(&mut self.current_function, func_name.clone());
        self.known_locals = cf.params.iter().map(|p| (p.clone(), true)).collect();
        for st in body { self.lower_stmt(st, &mut cf); }
        cf.body.push(Instr::Return);
        self.known_locals = saved_locals;
        self.current_function = saved_fname;
        self.pending_closures.push(cf);

        // At the creation site, push captured values in the same order used
        // for the synthesized function's leading params, then bundle them.
        for name in &captured_names {
            f.body.push(Instr::LoadLocal(name.clone()));
        }
        f.body.push(Instr::MakeClosure(func_name, captured_names));
    }

    // Warns (to stderr, non-fatal) on `let x = x + <expr>` reassignments
    // found anywhere inside a while-loop's body (recursing into nested
    // if/while blocks, since the append is often guarded by a condition)
    // when `x` was last bound to a string literal -- the exact pattern
    // that made an O(n) char-by-char scan silently O(n^2) in
    // self_hosting/lib/syntax_dsl.patlang (30+ minutes on a ~700K-char
    // file that should have taken seconds), found only because the user
    // asked "didn't recent changes make this slower?" rather than
    // treating the slowdown as expected. String values here are
    // immutable (Arc<String>) -- every `x = x + ...` copies the WHOLE
    // accumulated string again, turning an n-iteration loop into O(n^2)
    // total work. Restricted to string-literal-initialized names (not
    // every self-referential `+`) specifically so this doesn't fire on
    // an ordinary `let i = i + 1` counter or `let total = total + n`
    // numeric accumulator, which share the identical AST shape.
    fn warn_string_concat_in_loop(&mut self, stmts: &[Stmt]) {
        for s in stmts {
            match s {
                Stmt::Let { name, value, .. } => {
                    // Note: this codebase's own idiom writes `let x = x +
                    // ...` (WITH the `let` keyword) for what is really a
                    // reassignment inside a loop, not the bare `x = x +
                    // ...` form -- parse_let always sets is_reassignment:
                    // false regardless of whether `x` already exists, so
                    // this check can't restrict to is_reassignment: true
                    // (confirmed by testing: that version never fired on
                    // this repo's own real code, only on the bare form).
                    if self.string_literal_locals.contains(name) {
                        if let Expr::BinaryOp { left, op: BinaryOperator::Add, .. } = value {
                            if matches!(&**left, Expr::Identifier(n) if n == name) {
                                if self.warned_string_concat.insert(name.clone()) {
                                    eprintln!(
                                        "warning: `{name} = {name} + ...` inside a loop copies the whole string on every iteration (O(n^2) total, not O(n)) -- use sb_new()/sb_push({name}, ...)/sb_str({name}) instead",
                                        name = name
                                    );
                                }
                            }
                        }
                    }
                }
                Stmt::If { then_branch, else_branch, .. } => {
                    self.warn_string_concat_in_loop(then_branch);
                    if let Some(else_branch) = else_branch {
                        self.warn_string_concat_in_loop(else_branch);
                    }
                }
                Stmt::While { body, .. } => self.warn_string_concat_in_loop(body),
                _ => {}
            }
        }
    }
}

fn collect_let_bound_names(stmts: &[Stmt], out: &mut HashSet<String>) {
    for s in stmts {
        match s {
            Stmt::Let { name, .. } => { out.insert(name.clone()); }
            Stmt::If { then_branch, else_branch, .. } => {
                collect_let_bound_names(then_branch, out);
                if let Some(eb) = else_branch { collect_let_bound_names(eb, out); }
            }
            Stmt::While { body, .. } => collect_let_bound_names(body, out),
            Stmt::When { body, .. } => collect_let_bound_names(body, out),
            _ => {}
        }
    }
}

/// Real bug found while testing the x64 backend's numeric-tower `%` support
/// (unrelated to x64 itself -- reproduces identically under plain
/// `--ir-run`): `collect_let_bound_names`/`captured_names` treat every name
/// EVER `let`-bound anywhere in a closure's body as "owned" by the closure,
/// unconditionally excluding it from capture -- including the very
/// declaration statement that reads the OUTER value on its own right-hand
/// side, e.g. `let n = n + 1` as a closure's first (and only) mention of
/// `n`. That RHS `n` needs the captured outer value; the flat "own" set
/// wrongly hides it, so the closure silently reads an uninitialized/default
/// local instead (e.g. a captured `n = 100` reads back as 0, giving `1`
/// instead of `101`) -- no crash, no diagnostic, just a silently wrong
/// closure.
///
/// This finds every name whose OWN `let name = <expr>` has `name` appearing
/// inside `<expr>` itself, anywhere in the body (same flat, no-block-scoping
/// traversal `collect_let_bound_names` already uses) -- such a name must
/// still be considered for capture despite also being let-bound, since its
/// very first mention needs the enclosing scope's value. A closure that
/// instead establishes its own value first (`let n = 5` with no self-
/// reference) and only later does `let n = n + 1` also gets flagged here,
/// but harmlessly: the wrongly-captured value is simply overwritten by the
/// unrelated first `let` before ever being read, since this language has no
/// block scoping (a captured leading param and a same-named later `let` are
/// the same flat local slot) -- extra safety, not a correctness bug.
fn collect_self_referential_let_names(stmts: &[Stmt], out: &mut HashSet<String>) {
    for s in stmts {
        match s {
            Stmt::Let { name, value, .. } => {
                let mut ids = Vec::new();
                let mut seen = HashSet::new();
                collect_ident_expr(value, &mut ids, &mut seen);
                if ids.iter().any(|n| n == name) {
                    out.insert(name.clone());
                }
            }
            Stmt::If { then_branch, else_branch, .. } => {
                collect_self_referential_let_names(then_branch, out);
                if let Some(eb) = else_branch { collect_self_referential_let_names(eb, out); }
            }
            Stmt::While { body, .. } => collect_self_referential_let_names(body, out),
            Stmt::When { body, .. } => collect_self_referential_let_names(body, out),
            _ => {}
        }
    }
}

fn collect_referenced_idents(stmts: &[Stmt], out: &mut Vec<String>, seen: &mut HashSet<String>) {
    for s in stmts {
        match s {
            Stmt::ExprStmt(e) => collect_ident_expr(e, out, seen),
            Stmt::Let { value, .. } => collect_ident_expr(value, out, seen),
            Stmt::MemberAssign { object, value, .. } => { collect_ident_expr(object, out, seen); collect_ident_expr(value, out, seen); }
            Stmt::Function { body, .. } => collect_referenced_idents(body, out, seen),
            Stmt::Return(opt) => { if let Some(e) = opt { collect_ident_expr(e, out, seen); } }
            Stmt::If { cond, then_branch, else_branch } => {
                collect_ident_expr(cond, out, seen);
                collect_referenced_idents(then_branch, out, seen);
                if let Some(eb) = else_branch { collect_referenced_idents(eb, out, seen); }
            }
            Stmt::While { cond, body } => { collect_ident_expr(cond, out, seen); collect_referenced_idents(body, out, seen); }
            Stmt::Fact { args, .. } | Stmt::Query { args, .. } => { for a in args { collect_ident_expr(a, out, seen); } }
            Stmt::When { body, .. } => collect_referenced_idents(body, out, seen),
            Stmt::Assert { expr, .. } => collect_ident_expr(expr, out, seen),
            Stmt::RuleDecl { head_args, body, .. } => {
                for a in head_args { collect_ident_expr(a, out, seen); }
                for (_, args) in body { for a in args { collect_ident_expr(a, out, seen); } }
            }
            Stmt::GoalDecl { deps, .. } => {
                for (_, args) in deps { for a in args { collect_ident_expr(a, out, seen); } }
            }
            Stmt::ClassDecl { fields, .. } => {
                for (_, default_expr) in fields { collect_ident_expr(default_expr, out, seen); }
            }
        }
    }
}

fn collect_ident_expr(e: &Expr, out: &mut Vec<String>, seen: &mut HashSet<String>) {
    match e {
        Expr::Identifier(name) => {
            if name != "true" && name != "false" && seen.insert(name.clone()) {
                out.push(name.clone());
            }
        }
        Expr::List(items) => for it in items { collect_ident_expr(it, out, seen); },
        Expr::Member { object, .. } => collect_ident_expr(object, out, seen),
        Expr::Index { object, index } => { collect_ident_expr(object, out, seen); collect_ident_expr(index, out, seen); }
        Expr::UnaryOp { expr, .. } => collect_ident_expr(expr, out, seen),
        Expr::BinaryOp { left, right, .. } => { collect_ident_expr(left, out, seen); collect_ident_expr(right, out, seen); }
        Expr::Call { function, args } => {
            collect_ident_expr(function, out, seen);
            for a in args { collect_ident_expr(a, out, seen); }
        }
        Expr::Closure { params, body } => {
            // A nested closure's free variables (excluding its own params) are
            // also free variables of the enclosing closure, so they propagate
            // outward and get captured at whichever scope actually has them.
            let mut inner_out = Vec::new();
            let mut inner_seen: HashSet<String> = params.iter().cloned().collect();
            collect_referenced_idents(body, &mut inner_out, &mut inner_seen);
            for n in inner_out {
                if seen.insert(n.clone()) { out.push(n); }
            }
        }
        Expr::Number(_) | Expr::Float(_) | Expr::String(_) => {}
        Expr::Budgeted { ms, existing, body } => {
            collect_ident_expr(ms, out, seen);
            if let Some(e) = existing { collect_ident_expr(e, out, seen); }
            let mut inner_out = Vec::new();
            let mut inner_seen: HashSet<String> = HashSet::new();
            collect_referenced_idents(body, &mut inner_out, &mut inner_seen);
            for n in inner_out {
                if seen.insert(n.clone()) { out.push(n); }
            }
        }
    }
}

/// Render a rule head/body arg as the compile-time string token rule_add
/// expects: a bare identifier/number renders the same as expr_to_text, but
/// a string literal renders as its raw content, not source-quoted (unlike
/// expr_to_text, which is for human-readable messages).
pub fn rule_arg_text(e: &Expr) -> String {
    match e {
        Expr::String(s) => s.clone(),
        other => expr_to_text(other),
    }
}

/// Render an expression back to readable source text, for contract-violation
/// messages ("require b != 0" should report "b != 0", not a debug dump).
pub fn expr_to_text(e: &Expr) -> String {
    match e {
        Expr::Number(n) => format!("{}", *n as i64),
        Expr::Float(n) => n.to_string(),
        Expr::String(s) => format!("\"{}\"", s),
        Expr::Identifier(name) => name.clone(),
        Expr::List(items) => format!("[{}]", items.iter().map(expr_to_text).collect::<Vec<_>>().join(", ")),
        Expr::Member { object, property } => format!("{}.{}", expr_to_text(object), property),
        Expr::Index { object, index } => format!("{}[{}]", expr_to_text(object), expr_to_text(index)),
        Expr::Closure { .. } => "<closure>".into(),
        Expr::UnaryOp { op, expr } => format!("{}{}", op, expr_to_text(expr)),
        Expr::BinaryOp { left, op, right } => {
            let sym = match op {
                BinaryOperator::Add => "+", BinaryOperator::Sub => "-",
                BinaryOperator::Mul => "*", BinaryOperator::Div => "/", BinaryOperator::Mod => "%",
                BinaryOperator::And => "and", BinaryOperator::Or => "or",
                BinaryOperator::Equal => "==", BinaryOperator::NotEqual => "!=",
                BinaryOperator::Greater => ">", BinaryOperator::GreaterEqual => ">=",
                BinaryOperator::Less => "<", BinaryOperator::LessEqual => "<=",
                BinaryOperator::BitAnd => "band", BinaryOperator::BitOr => "bor", BinaryOperator::BitXor => "bxor",
                BinaryOperator::Shl => "shl", BinaryOperator::Shr => "shr",
            };
            format!("{} {} {}", expr_to_text(left), sym, expr_to_text(right))
        }
        Expr::Call { function, args } => format!("{}({})", expr_to_text(function), args.iter().map(expr_to_text).collect::<Vec<_>>().join(", ")),
        Expr::Budgeted { .. } => "<budgeted>".into(),
    }
}
