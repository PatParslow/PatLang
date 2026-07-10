// Stage 38 — cross-implementation property test. The interpreter's tower
// (`ir/numeric.rs`, real `num_bigint::BigInt`) and the compiled-program
// template's hand-rolled tower (`numeric_tower` chunk in `ir/codegen.rs`,
// `BigIntT`/`RationalT`, no external crates) are two SEPARATE
// implementations that must agree. For each case here: run the same
// Const/Const/BinOp/Return IR program through (a) the interpreter directly,
// and (b) `RustCodegen::emit_rust` -> `rustc` -> execute the binary and
// capture stdout. Assert identical string output.
//
// Skips (rather than fails) if `rustc` isn't on PATH, following the
// established pattern in `tests/selfhost_targets.rs`.
use patlang_runtime::ir::*;

fn program_for(a: Value, b: Value, op: BinOpKind) -> Program {
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(a));
    f.body.push(Instr::Const(b));
    f.body.push(Instr::BinOp(op));
    f.body.push(Instr::Return);
    let mut p = Program::default();
    p.entry = "main".into();
    p.functions.insert("main".into(), f);
    p
}

fn interp_output(program: &Program) -> String {
    let interp = Interpreter::new();
    let v = interp.run(program).expect("interpreter run should succeed");
    ops::v_to_string(&v)
}

fn big(s: &str) -> Value {
    // Interpreter's real Value::BigInt wraps num_bigint::BigInt.
    Value::BigInt(s.parse().expect("valid decimal"))
}

struct Rustc {
    path: String,
}

fn find_rustc() -> Option<Rustc> {
    let rustc = std::env::var("RUSTC").unwrap_or_else(|_| "rustc".to_string());
    if std::process::Command::new(&rustc).arg("--version").output().is_ok() {
        Some(Rustc { path: rustc })
    } else {
        None
    }
}

fn compiled_output(rustc: &Rustc, program: &Program, tag: &str) -> String {
    let src = RustCodegen::new().emit_rust(program);
    let out_dir = std::env::temp_dir().join("patlang_bignum_cross_path");
    let _ = std::fs::create_dir_all(&out_dir);
    let rs_path = out_dir.join(format!("case_{}.rs", tag));
    let exe_path = out_dir.join(if cfg!(windows) { format!("case_{}.exe", tag) } else { format!("case_{}", tag) });
    std::fs::write(&rs_path, &src).expect("write generated rust source");

    let status = std::process::Command::new(&rustc.path)
        .arg(&rs_path)
        .arg("-O")
        .arg("-o")
        .arg(&exe_path)
        .status()
        .expect("invoke rustc");
    assert!(status.success(), "rustc failed to compile case '{}':\n{}", tag, src);

    let out = std::process::Command::new(&exe_path).output().expect("run compiled binary");
    assert!(out.status.success(), "compiled binary '{}' exited non-zero: stderr={}", tag, String::from_utf8_lossy(&out.stderr));
    String::from_utf8_lossy(&out.stdout).trim_end_matches(['\r', '\n']).to_string()
}

fn assert_cross_path_agrees(rustc: &Rustc, tag: &str, a: Value, b: Value, op: BinOpKind) {
    let program = program_for(a, b, op);
    let interp = interp_output(&program);
    let compiled = compiled_output(rustc, &program, tag);
    assert_eq!(interp, compiled, "case '{}': interpreter vs compiled output mismatch", tag);
}

#[test]
fn bignum_cross_path_agrees() {
    let Some(rustc) = find_rustc() else {
        eprintln!("rustc not found; skipping bignum_cross_path_agrees");
        return;
    };

    // --- overflow-triggered promotion (both operands fit i64, result doesn't) ---
    assert_cross_path_agrees(&rustc, "add_overflow_pos", Value::Int(9223372036854775800), Value::Int(1000), BinOpKind::Add);
    assert_cross_path_agrees(&rustc, "add_overflow_neg", Value::Int(-9223372036854775800), Value::Int(-1000), BinOpKind::Add);
    assert_cross_path_agrees(&rustc, "sub_overflow", Value::Int(i64::MIN + 5), Value::Int(1000), BinOpKind::Sub);
    assert_cross_path_agrees(&rustc, "mul_overflow_pos", Value::Int(i64::MAX), Value::Int(2), BinOpKind::Mul);
    assert_cross_path_agrees(&rustc, "mul_overflow_neg", Value::Int(i64::MAX), Value::Int(-3), BinOpKind::Mul);

    // --- genuinely large BigInt operands (well beyond i64 range) ---
    let huge_a = "123456789012345678901234567890123456789";
    let huge_b = "987654321098765432109876543210987654321";
    assert_cross_path_agrees(&rustc, "big_add_pos_pos", big(huge_a), big(huge_b), BinOpKind::Add);
    assert_cross_path_agrees(&rustc, "big_add_pos_neg", big(huge_a), big(&format!("-{}", huge_b)), BinOpKind::Add);
    assert_cross_path_agrees(&rustc, "big_sub_pos_pos", big(huge_b), big(huge_a), BinOpKind::Sub);
    assert_cross_path_agrees(&rustc, "big_sub_neg_result", big(huge_a), big(huge_b), BinOpKind::Sub);
    assert_cross_path_agrees(&rustc, "big_mul_pos_pos", big(huge_a), big("1000000000000"), BinOpKind::Mul);
    assert_cross_path_agrees(&rustc, "big_mul_neg_pos", big(&format!("-{}", huge_a)), big("7"), BinOpKind::Mul);
    assert_cross_path_agrees(&rustc, "big_div_exact", big("999999999999999999999999999999000"), big("1000"), BinOpKind::Div);
    assert_cross_path_agrees(&rustc, "big_div_inexact", big(huge_b), big(huge_a), BinOpKind::Div);
    assert_cross_path_agrees(&rustc, "big_mod", big(huge_b), big(huge_a), BinOpKind::Mod);

    // --- big/negative combinations ---
    assert_cross_path_agrees(&rustc, "big_neg_add_neg", big(&format!("-{}", huge_a)), big(&format!("-{}", huge_b)), BinOpKind::Add);
    assert_cross_path_agrees(&rustc, "big_neg_sub_pos", big(&format!("-{}", huge_a)), big(huge_b), BinOpKind::Sub);
    assert_cross_path_agrees(&rustc, "big_pos_sub_neg", big(huge_a), big(&format!("-{}", huge_b)), BinOpKind::Sub);
    assert_cross_path_agrees(&rustc, "big_mul_neg_neg", big(&format!("-{}", huge_a)), big(&format!("-{}", huge_b)), BinOpKind::Mul);

    // --- comparisons across the same magnitude range ---
    assert_cross_path_agrees(&rustc, "big_eq_true", big(huge_a), big(huge_a), BinOpKind::Eq);
    assert_cross_path_agrees(&rustc, "big_lt", big(huge_a), big(huge_b), BinOpKind::Lt);
    assert_cross_path_agrees(&rustc, "big_gt", big(huge_b), big(huge_a), BinOpKind::Gt);

    // --- plain int/int inexact division (exact-rational path, smaller scale) ---
    assert_cross_path_agrees(&rustc, "int_div_inexact", Value::Int(10), Value::Int(3), BinOpKind::Div);
    assert_cross_path_agrees(&rustc, "int_div_exact", Value::Int(10), Value::Int(2), BinOpKind::Div);
    assert_cross_path_agrees(&rustc, "int_div_inexact_neg", Value::Int(-10), Value::Int(3), BinOpKind::Div);
}
