// Stage 36 — interpreter-only numeric tower tests. No rustc invocation: these
// drive Instr sequences straight through Interpreter::run, following the
// idiom in tests/ir_smoke.rs.
use patlang_runtime::ir::*;

fn run_binop(a: Value, b: Value, op: BinOpKind) -> Value {
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(a));
    f.body.push(Instr::Const(b));
    f.body.push(Instr::BinOp(op));
    f.body.push(Instr::Return);
    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);
    let interp = Interpreter::new();
    interp.run(&program).expect("run ok")
}

#[test]
fn overflow_triggers_bigint() {
    // i64::MAX is 9223372036854775807; adding 1000 overflows i64::checked_add,
    // so the tower must promote to BigInt and return the correct big value
    // rather than wrapping around or panicking.
    let a = Value::Int(9223372036854775800);
    let b = Value::Int(1000);
    let v = run_binop(a, b, BinOpKind::Add);
    match v {
        Value::BigInt(n) => assert_eq!(n.to_string(), "9223372036854776800"),
        other => panic!("expected BigInt, got {:?}", other),
    }
}

#[test]
fn overflow_multiplication_triggers_bigint() {
    let a = Value::Int(i64::MAX);
    let b = Value::Int(2);
    let v = run_binop(a, b, BinOpKind::Mul);
    match v {
        Value::BigInt(n) => assert_eq!(n.to_string(), (i64::MAX as i128 * 2).to_string()),
        other => panic!("expected BigInt, got {:?}", other),
    }
}

#[test]
fn inexact_int_division_triggers_rational() {
    // 10 / 3 does not divide evenly -> exact Rational(10, 3), not a lossy float.
    let v = run_binop(Value::Int(10), Value::Int(3), BinOpKind::Div);
    match v {
        Value::Rational(n, d) => {
            assert_eq!(n.to_string(), "10");
            assert_eq!(d.to_string(), "3");
        }
        other => panic!("expected Rational(10, 3), got {:?}", other),
    }
}

#[test]
fn exact_int_division_stays_int() {
    let v = run_binop(Value::Int(10), Value::Int(2), BinOpKind::Div);
    assert_eq!(v, Value::Int(5));
}

#[test]
fn demotion_after_bigint_op_that_fits_back_in_i64() {
    // A BigInt sum whose result fits back in i64 should demote to Int, so the
    // fast path resumes for subsequent operations.
    let big = num_bigint::BigInt::parse_bytes(b"9223372036854775807", 10).unwrap(); // i64::MAX
    let v = run_binop(Value::BigInt(big), Value::Int(800), BinOpKind::Sub);
    assert_eq!(v, Value::Int(i64::MAX - 800));
}

#[test]
fn demotion_rational_landing_on_integer() {
    // (10/3) - (1/3) = 9/3 = 3, an exact integer, so it must demote to Int
    // rather than staying as a Rational with denominator 1.
    let a = Value::Rational(num_bigint::BigInt::from(10), num_bigint::BigInt::from(3));
    let b = Value::Rational(num_bigint::BigInt::from(1), num_bigint::BigInt::from(3));
    let v = run_binop(a, b, BinOpKind::Sub);
    assert_eq!(v, Value::Int(3));
}

#[test]
fn cross_kind_comparison_int_equals_rational() {
    // Int(3) == Rational(3,1) must be true: both sides are promoted through
    // the same tower rules before comparing.
    let a = Value::Int(3);
    let b = Value::Rational(num_bigint::BigInt::from(3), num_bigint::BigInt::from(1));
    let v = run_binop(a, b, BinOpKind::Eq);
    assert_eq!(v, Value::Bool(true));
}

#[test]
fn cross_kind_comparison_bigint_vs_int() {
    let a = Value::BigInt(num_bigint::BigInt::from(42));
    let b = Value::Int(42);
    let v = run_binop(a, b, BinOpKind::Eq);
    assert_eq!(v, Value::Bool(true));
}

#[test]
fn float_contagion_on_mixed_add() {
    // Any Float operand pulls both sides to Float, even against an Int.
    let v = run_binop(Value::Int(2), Value::Float(1.5), BinOpKind::Add);
    assert_eq!(v, Value::Float(3.5));
}

#[test]
fn negation_across_kinds() {
    let mut f = Function { name: "main".into(), ..Default::default() };
    f.body.push(Instr::Const(Value::Int(5)));
    f.body.push(Instr::UnOp(UnOpKind::Neg));
    f.body.push(Instr::Return);
    let mut program = Program::default();
    program.entry = "main".into();
    program.functions.insert("main".into(), f);
    let interp = Interpreter::new();
    let v = interp.run(&program).expect("run ok");
    assert_eq!(v, Value::Int(-5));
}

#[test]
fn as_index_rejects_negative() {
    assert!(ops::as_index(&Value::Int(-1)).is_err());
    assert_eq!(ops::as_index(&Value::Int(5)).unwrap(), 5usize);
}
